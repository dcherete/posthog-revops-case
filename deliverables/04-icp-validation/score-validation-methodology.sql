-- Name: score_validation_methodology
-- Business Goal: Validate whether a propensity score predicts real revenue outcomes
--   and calibrate the economically optimal score threshold (breakeven)
-- Owner: Davi Cherete
-- Context: Applied to ex-member resubscription model (EXM v6.6) at Brasil Paralelo.
--   Methodology transfers directly to validating PostHog's ICP score against Salesforce ARR data.

-- ─────────────────────────────────────────────────────────────────────
-- STEP 1: Scored population at apply date
-- The model runs as a Python/LightGBM pipeline and outputs a score per person.
-- This CTE represents the scored list written back to BigQuery after apply.
-- ─────────────────────────────────────────────────────────────────────
WITH scored_population AS (
    SELECT
        id_person,
        nm_phone,
        nm_email,
        score_raw,
        dt_apply,
        -- Calibrate raw score to real-world conversion prevalence.
        -- Model is trained on a downsampled dataset (~3% non-converters),
        -- so raw score overestimates true conversion rate.
        -- Calibration factor derived empirically from prior campaign results.
        score_raw * 0.039 AS score_calibrated
    FROM {{ ref('stg_model_apply_exmb_v6_6') }}
    WHERE dt_apply = '2026-06-10'
),

-- ─────────────────────────────────────────────────────────────────────
-- STEP 2: Revenue outcomes within the attribution window
-- For resubscription: 7-day window from first contact.
-- For PostHog ICP validation: use ARR invoiced at 6 and 12 months from first rep touch.
-- ─────────────────────────────────────────────────────────────────────
revenue_outcomes AS (
    SELECT
        c.id_person,
        s.id_subscription,
        s.dt_started_at,
        s.vl_ticket,
        DATE_DIFF(s.dt_started_at, c.dt_first_contact, DAY) AS qt_days_to_convert,
        -- Flag conversion within the attribution window
        CASE
            WHEN DATE_DIFF(s.dt_started_at, c.dt_first_contact, DAY) BETWEEN 0 AND 7
                THEN 1
            ELSE 0
        END AS bl_converted_d7
    FROM {{ ref('int_campaign_contacts') }} AS c
    LEFT JOIN {{ ref('dim_subscriptions') }} AS s
        ON c.id_person = s.id_person
        AND s.nm_type = 'paid'
        AND s.dt_started_at >= c.dt_first_contact
),

-- ─────────────────────────────────────────────────────────────────────
-- STEP 3: Join score to outcomes and assign score bands
-- Bands are defined empirically around the expected breakeven point.
-- For PostHog: replace score_raw with ICP score (0-70 scale) and
-- revenue outcome with ARR realized at 6 months.
-- ─────────────────────────────────────────────────────────────────────
score_with_outcomes AS (
    SELECT
        sp.id_person,
        sp.score_raw,
        sp.score_calibrated,
        sp.dt_apply,
        COALESCE(ro.bl_converted_d7, 0) AS bl_converted,
        COALESCE(ro.vl_ticket, 0) AS vl_revenue,

        -- Score bands bracketing the theoretical breakeven (~0.05 raw)
        CASE
            WHEN sp.score_raw >= 0.053 THEN 'A: Topscore'
            WHEN sp.score_raw >= 0.035 THEN 'B: Alto'
            WHEN sp.score_raw >= 0.024 THEN 'C: Médio'
            WHEN sp.score_raw >= 0.017 THEN 'D: Baixo'
            ELSE 'E: Abaixo do breakeven'
        END AS nm_score_band,

        -- Sort key for ordering bands in reports
        CASE
            WHEN sp.score_raw >= 0.053 THEN 1
            WHEN sp.score_raw >= 0.035 THEN 2
            WHEN sp.score_raw >= 0.024 THEN 3
            WHEN sp.score_raw >= 0.017 THEN 4
            ELSE 5
        END AS nr_band_order

    FROM scored_population AS sp
    LEFT JOIN revenue_outcomes AS ro
        ON sp.id_person = ro.id_person
        AND ro.bl_converted_d7 = 1
    -- One row per scored person (deduplicate if multiple subscriptions in window)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY sp.id_person ORDER BY ro.dt_started_at) = 1
),

-- ─────────────────────────────────────────────────────────────────────
-- STEP 4: Aggregate by score band
-- The key output: conversion rate, revenue per person, and ROI per band.
-- This is the table that answers "does the score predict revenue?"
-- A well-calibrated score should show monotonically increasing conversion
-- and revenue per person as score band increases.
-- ─────────────────────────────────────────────────────────────────────
band_performance AS (
    SELECT
        nm_score_band,
        nr_band_order,
        COUNT(*) AS qt_people,
        SUM(bl_converted) AS qt_converted,
        SAFE_DIVIDE(SUM(bl_converted), COUNT(*)) AS pct_conversion_rate,
        SUM(vl_revenue) AS vl_revenue_total,
        SAFE_DIVIDE(SUM(vl_revenue), COUNT(*)) AS vl_revenue_per_person,

        -- Cost model: implicit cost per person reached via WhatsApp campaign
        -- Derived from platform cost + ops allocation, calibrated on prior campaigns.
        -- Replace with your cost model (CPC, CPM, rep time cost, etc.).
        COUNT(*) * 10.22 AS vl_cost_total,
        10.22 AS vl_cost_per_person,

        -- ROI = (revenue - cost) / cost
        SAFE_DIVIDE(
            SUM(vl_revenue) - COUNT(*) * 10.22,
            COUNT(*) * 10.22
        ) AS vl_roi,

        -- Revenue per thousand reached (RPM) — comparable across band sizes
        SAFE_DIVIDE(SUM(vl_revenue), COUNT(*)) * 1000 AS vl_rpm

    FROM score_with_outcomes
    GROUP BY nm_score_band, nr_band_order
),

-- ─────────────────────────────────────────────────────────────────────
-- STEP 5: Breakeven calibration
-- Find the minimum score threshold where expected revenue covers cost.
-- This becomes the deployment cutoff: only reach people above this score.
-- Formula: breakeven_score = cost_per_person / (ticket * delivery_rate)
-- ─────────────────────────────────────────────────────────────────────
breakeven_analysis AS (
    SELECT
        vl_cost_per_person,
        -- At each band, what is the conversion rate needed to break even?
        SAFE_DIVIDE(vl_cost_per_person, vl_revenue_per_person) AS pct_conversion_needed_to_break_even,
        -- Actual conversion rate vs what's needed
        pct_conversion_rate,
        pct_conversion_rate - SAFE_DIVIDE(vl_cost_per_person, vl_revenue_per_person) AS pct_margin_above_breakeven,
        nm_score_band,
        nr_band_order
    FROM band_performance
)

-- ─────────────────────────────────────────────────────────────────────
-- FINAL OUTPUT: Band performance + breakeven annotation
-- The score is validated if:
--   (1) Conversion rate increases monotonically with score band
--   (2) ROI is positive in the bands you deploy to
--   (3) Breakeven threshold is economically sensible
--
-- If the score is NOT validated (flat or inverted conversion rates across bands),
-- the score does not predict revenue and the deployment threshold has no economic basis.
-- ─────────────────────────────────────────────────────────────────────
SELECT
    bp.nm_score_band,
    bp.nr_band_order,
    bp.qt_people,
    bp.qt_converted,
    ROUND(bp.pct_conversion_rate * 100, 2) AS pct_conversion_rate,
    ROUND(bp.vl_revenue_total, 0) AS vl_revenue_total,
    ROUND(bp.vl_cost_total, 0) AS vl_cost_total,
    ROUND(bp.vl_roi * 100, 1) AS pct_roi,
    ROUND(bp.vl_rpm, 0) AS vl_rpm,
    ROUND(ba.pct_margin_above_breakeven * 100, 2) AS pct_margin_above_breakeven,
    CASE
        WHEN bp.vl_roi > 0 THEN 'deploy'
        WHEN bp.vl_roi > -0.05 THEN 'marginal'
        ELSE 'do not deploy'
    END AS nm_deployment_decision
FROM band_performance AS bp
LEFT JOIN breakeven_analysis AS ba
    ON bp.nm_score_band = ba.nm_score_band
ORDER BY bp.nr_band_order
