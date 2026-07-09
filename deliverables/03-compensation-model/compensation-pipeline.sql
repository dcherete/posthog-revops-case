-- ============================================================
-- COMPENSATION PIPELINE — Brasil Paralelo (anonymized)
-- Built in DBT Cloud + BigQuery
-- Owner: Davi Cherete
-- Context: monthly commission apuration for a sales team
--          that grew from 22 to 40 reps during the period.
--          Pipeline ran hourly in production.
-- ============================================================


-- ============================================================
-- MODEL 1: stg_daily_sales_goals
-- Purpose: staging layer for daily sales targets.
--          Two tiers per day: standard goal and super goal,
--          both in revenue (vl) and unit count (qt).
-- ============================================================

-- Name: stg_daily_sales_goals
-- Owner: Davi
-- Created at: 2022-11-29

WITH stg_daily_sales_goals AS (
    SELECT * FROM {{ source('sales', 'tb_daily_sales_goals') }}
),

final AS (
    SELECT
        dt_goal_at,
        vl_daily_goal,
        qt_daily_goal,
        vl_daily_super_goal,
        qt_daily_super_goal
    FROM stg_daily_sales_goals
)

SELECT * FROM final;


-- ============================================================
-- MODEL 2: dtm_sales_transactions_refined
-- Purpose: resolves four attribution cases for every
--          transaction, determining which rep gets credit:
--
--   1. tracked — rep was captured at point of sale
--   2. untracked — no rep captured, assigned via lookup rules
--   3. canceled assignment — original rep was removed,
--      reassigned to correct rep
--   4. transferred — deal moved from one rep to another
--
-- This is the attribution layer. Every downstream model
-- depends on this being correct.
-- ============================================================

-- Name: dtm_sales_transactions_refined
-- Owner: Davi
-- Created at: 2022-11-29

WITH int_assignment_for_untracked_transactions AS (
    SELECT * FROM {{ ref('int_assignment_for_untracked_transactions') }}
),

int_canceled_seller_assignment AS (
    SELECT * FROM {{ ref('int_canceled_seller_assignment') }}
),

int_transactions_transferred_to_another_seller AS (
    SELECT * FROM {{ ref('int_transactions_transferred_to_another_seller') }}
),

int_sales_transactions AS (
    SELECT * FROM {{ ref('int_sales_transactions') }}
),

-- Apply attribution priority via COALESCE:
-- transferred > canceled/reassigned > untracked assignment > original
union_all_transactions AS (
    SELECT
        ict.* EXCEPT (nm_salesman_email, nm_seller),
        COALESCE(
            ctt.nm_email_seller_to_give,
            cct.nm_email_seller,
            uct.nm_email_seller,
            ict.nm_salesman_email
        ) AS nm_salesman_email,
        COALESCE(
            ctt.nm_seller_name,
            cct.nm_seller_name,
            uct.nm_seller_name,
            ict.nm_seller
        ) AS nm_seller_name,
        COALESCE(
            ctt.nm_sales_type,
            cct.nm_sales_type,
            uct.nm_sales_type,
            'tracked'
        ) AS nm_sales_type
    FROM int_sales_transactions AS ict
    FULL OUTER JOIN int_transactions_transferred_to_another_seller AS ctt
        ON ctt.id_transaction = ict.id_transaction
    FULL OUTER JOIN int_canceled_seller_assignment AS cct
        ON cct.id_transaction = ict.id_transaction
    FULL OUTER JOIN int_assignment_for_untracked_transactions AS uct
        ON uct.id_transaction = ict.id_transaction
    WHERE uct.id_transaction IS NULL
        OR cct.id_transaction IS NULL
        OR ctt.id_transaction IS NULL
        OR ict.id_transaction IS NULL
),

final AS (
    SELECT
        t.*,
        CASE
            WHEN LOWER(t.nm_product_offer) LIKE '%lifetime%'   THEN 'lifetime'
            WHEN t.nm_product_plan = 'high_ticket_a'           THEN 'high ticket'
            WHEN t.nm_product_plan LIKE 'high_ticket_%'        THEN 'high ticket'
            WHEN t.nm_product_plan IN (
                'membership',
                'membership_high_ticket_a',
                'membership_high_ticket_b'
            )                                                   THEN 'membership'
            ELSE 'standard'
        END AS nm_transaction_classification
    FROM union_all_transactions AS t
)

SELECT * FROM final;


-- ============================================================
-- MODEL 3: cbo_sales_goals_and_commission
-- Purpose: final commission apuration model.
--          Calculates daily attainment per rep, applies
--          ramp adjustments for new hires, and outputs
--          commission per rep per day with tier logic.
--
-- Commission tiers (applied to net revenue after fees):
--   < 50% attainment  → 0% commission
--   50–100%           → 2.5%
--   ≥ 100%            → 5.0%
--   ≥ 150%            → 7.5%
--
-- Attainment is the higher of:
--   - revenue achievement alone, OR
--   - weighted blend (revenue × 0.7 + units × 0.3)
--
-- Ramp logic: new hires receive scaled-down targets
--   during onboarding to reflect lower expected output.
--   Targets scale from 50% → 80% → 100% across
--   three ramp milestones (dt_first_goal, dt_second_goal,
--   dt_third_goal) stored in the sellers dimension.
-- ============================================================

-- Name: cbo_sales_goals_and_commission
-- Owner: Davi
-- Created at: 2022-11-29
-- Materialization: table, refreshed every hour

{{ config(
    tags=['every_hour'],
    materialized='table',
    schema='datamart',
    labels={'every_hour': ''}
) }}

WITH dtm_sales_transactions_refined AS (
    SELECT * FROM {{ ref('dtm_sales_transactions_refined') }}
),

stg_daily_sales_goals AS (
    SELECT * FROM {{ ref('stg_daily_sales_goals') }}
),

dim_time AS (
    SELECT * FROM {{ ref('dim_time') }}
),

int_sellers AS (
    SELECT * FROM {{ ref('int_sellers') }}
),

{% set START_DATE = 'DATE("2022-01-01")' %}
{% set END_DATE   = 'DATE("2025-12-31")' %}

-- Cross join dates × sellers to ensure every rep appears
-- on every day, even days with zero sales.
generate_dates_and_sellers AS (
    SELECT DISTINCT
        dates AS dt_dates,
        nm_agent_email
    FROM UNNEST(GENERATE_DATE_ARRAY({{ START_DATE }}, {{ END_DATE }})) AS dates
    LEFT JOIN int_sellers AS v ON 1 = 1
    WHERE nm_agent_email IS NOT NULL
),

-- Aggregate daily transactions per rep.
-- COALESCE ensures zero-revenue days appear as 0, not NULL.
int_transactions AS (
    SELECT
        d.dt_dates,
        d.nm_agent_email,
        COALESCE(SUM(f.vl_payment_gross), 0)          AS vl_daily_revenue,
        COALESCE(COUNT(DISTINCT f.id_transaction), 0) AS qt_daily_sales
    FROM generate_dates_and_sellers AS d
    LEFT JOIN dtm_sales_transactions_refined AS f
        ON DATE(f.dt_ordered_at) = d.dt_dates
        AND f.nm_salesman_email  = d.nm_agent_email
    GROUP BY 1, 2
),

-- Apply ramp scaling to goals.
-- New hires have goals scaled down during the onboarding
-- period defined by three milestone dates per rep.
-- This prevents penalizing reps for low output while learning.
goals_and_revenue AS (
    SELECT
        d.dt_dates,

        -- Revenue goal scaled by ramp stage
        CASE
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_first_goal) AND DATE(v.dt_second_goal) THEN g.vl_daily_goal * 0.5
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_second_goal) AND DATE(v.dt_third_goal) THEN g.vl_daily_goal * 0.8
            ELSE g.vl_daily_goal * 1.0
        END AS vl_daily_goal,

        -- Unit goal scaled by ramp stage
        CASE
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_first_goal) AND DATE(v.dt_second_goal) THEN g.qt_daily_goal * 0.5
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_second_goal) AND DATE(v.dt_third_goal) THEN g.qt_daily_goal * 0.8
            ELSE g.qt_daily_goal * 1.0
        END AS qt_daily_goal,

        -- Super goal (150% tier) scaled by ramp stage
        CASE
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_first_goal) AND DATE(v.dt_second_goal) THEN g.vl_daily_super_goal * 0.5
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_second_goal) AND DATE(v.dt_third_goal) THEN g.vl_daily_super_goal * 0.8
            ELSE g.vl_daily_super_goal * 1.0
        END AS vl_daily_super_goal,

        CASE
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_first_goal) AND DATE(v.dt_second_goal) THEN g.qt_daily_super_goal * 0.5
            WHEN DATE(d.dt_dates) BETWEEN DATE(v.dt_second_goal) AND DATE(v.dt_third_goal) THEN g.qt_daily_super_goal * 0.8
            ELSE g.qt_daily_super_goal * 1.0
        END AS qt_daily_super_goal,

        -- Time dimensions for weekly and monthly aggregation
        CONCAT(EXTRACT(YEAR FROM d.dt_dates), EXTRACT(ISOWEEK FROM d.dt_dates)) AS id_isoweek,
        CONCAT(EXTRACT(YEAR FROM d.dt_dates), EXTRACT(MONTH  FROM d.dt_dates))  AS id_month,

        d.nm_agent_email,
        CONCAT(
            REGEXP_EXTRACT(d.nm_agent_email, r'^[a-z]+'), ' ',
            REGEXP_EXTRACT(d.nm_agent_email, r'\.([a-z]+)')
        ) AS nm_name_owner,
        v.nm_sales_team,
        d.qt_daily_sales,
        d.vl_daily_revenue
    FROM int_transactions AS d
    LEFT JOIN stg_daily_sales_goals AS g ON g.dt_goal_at = d.dt_dates
    LEFT JOIN int_sellers            AS v ON v.nm_agent_email = d.nm_agent_email
    WHERE d.dt_dates >= v.dt_admission_at
),

-- Running attainment within each ISO week per rep.
-- Two variants:
--   pc_*_achievement  = running (cumulative within week, ordered by day)
--   pc_*_achievement2 = full-week projection (denominator is total week goal)
sales_and_revenue_achievement AS (
    SELECT
        *,
        SUM(vl_daily_revenue) OVER w_running / NULLIF(SUM(vl_daily_goal) OVER w_running, 0) AS pc_revenue_achievement,
        SUM(qt_daily_sales)   OVER w_running / NULLIF(SUM(qt_daily_goal) OVER w_running, 0) AS pc_sales_achievement,
        SUM(vl_daily_revenue) OVER w_running AS vl_aggregated_revenue,
        SUM(qt_daily_sales)   OVER w_running AS qt_aggregated_sales,
        SUM(vl_daily_goal)    OVER w_running AS vl_aggregated_goal,
        ROW_NUMBER()          OVER w_running AS cd_day_of_week,
        SUM(vl_daily_revenue) OVER w_running / NULLIF(SUM(vl_daily_goal) OVER w_full, 0) AS pc_revenue_achievement2,
        SUM(qt_daily_sales)   OVER w_running / NULLIF(SUM(qt_daily_goal) OVER w_full, 0) AS pc_sales_achievement2
    FROM goals_and_revenue
    WINDOW
        w_running AS (PARTITION BY nm_agent_email, id_isoweek ORDER BY dt_dates),
        w_full    AS (PARTITION BY nm_agent_email, id_isoweek)
),

-- Total attainment = max of pure revenue achievement
-- or weighted blend (revenue 70% + units 30%).
-- This prevents gaming by volume without revenue quality.
total_achievement AS (
    SELECT
        *,
        ROUND(
            IF(pc_revenue_achievement > pc_sales_achievement,
                pc_revenue_achievement,
                (pc_revenue_achievement * 0.7) + (pc_sales_achievement * 0.3)
            ), 3
        ) AS pc_total_achievement,
        ROUND(
            IF(pc_revenue_achievement2 > pc_sales_achievement2,
                pc_revenue_achievement2,
                (pc_revenue_achievement2 * 0.7) + (pc_sales_achievement2 * 0.3)
            ), 3
        ) AS pc_total_achievement2
    FROM sales_and_revenue_achievement
),

-- Commission calculation.
-- Net revenue = gross × (1 - payment_gateway_fee)
-- Commission rate applied to net revenue based on attainment tier.
--
-- Tier logic:
--   < 50%    → 0%    (below floor, no commission)
--   50–100%  → 2.5%  (sub-goal tier)
--   ≥ 100%   → 5.0%  (goal tier)
--   ≥ 150%   → 7.5%  (super goal tier)
--
-- cd_goal_achievement_day: first day of the week the rep
-- crossed 100% attainment, used for performance tracking.
final AS (
    SELECT
        *,
        MIN(IF(pc_total_achievement >= 1, cd_day_of_week, NULL))
            OVER (PARTITION BY nm_agent_email, id_isoweek) AS cd_goal_achievement_day,

        CASE
            WHEN pc_total_achievement >= 1.5                      THEN (vl_daily_revenue * (1 - 0.1041)) * 0.075
            WHEN pc_total_achievement < 0.5                       THEN 0
            WHEN pc_total_achievement BETWEEN 0.5 AND 1           THEN (vl_daily_revenue * (1 - 0.1041)) * 0.025
            WHEN pc_total_achievement >= 1                        THEN (vl_daily_revenue * (1 - 0.1041)) * 0.050
        END AS vl_commission,

        CASE
            WHEN pc_total_achievement >= 1.5            THEN '3. super goal'
            WHEN pc_total_achievement < 0.5             THEN '0. no goal'
            WHEN pc_total_achievement BETWEEN 0.5 AND 1 THEN '1. sub goal'
            WHEN pc_total_achievement >= 1              THEN '2. goal'
        END AS goal_classification
    FROM total_achievement
)

SELECT * FROM final;
