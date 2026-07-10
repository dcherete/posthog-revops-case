-- Name: dtm_seller_conversion_rate
-- Business Goal: Avaliar conversão de agentes comerciais por tipo de lead, lista e fonte
-- Owner: Davi Cherete
-- Created at: 2022-12-16

{{
    config(
        tags = ['every_30_minutes'],
        materialized = 'table',
        partition_by={
            'field': 'dt_created_at',
            'data_type': 'datetime',
            'granularity': 'month'
        },
        schema = 'datamart',
        cluster_by=['nm_salesman_email'],
        labels = {'every_30_minutes': ''}
    )
}}

WITH int_pipedrive_analytics AS (
    SELECT * FROM {{ ref('int_pipedrive_analytics') }}
),

fct_transactions AS (
    SELECT * FROM {{ ref('fct_transactions') }}
),

int_pipedrive_deal_category AS (
    SELECT * FROM {{ ref('int_pipedrive_deal_category') }}
),

int_commercial_transactions AS (
    SELECT * FROM {{ ref('int_commercial_transactions') }}
),

int_marketing_transactions AS (
    SELECT * FROM {{ ref('int_marketing_transactions') }}
),

int_rppc_vendedores AS (
    SELECT * FROM {{ ref('int_rppc_vendedores') }}
),

int_zenvia_analytics AS (
    SELECT * FROM {{ ref('int_zenvia_analytics') }}
),

int_subscription_billing_cycle AS (
    SELECT * FROM {{ ref('int_subscription_billing_cycle') }}
),

-- Because of Zenvia -> Zapier -> Pipedrive integration,
-- there is a delay in creating cards in pipedrive.
-- The prospect arrives in the chat and after a while this is
-- processed by Zapier and reaches Pipedrive.
-- That's why it's necessary to remove the 2 hours,
-- as there are times when the automation gets stuck due to having to process
-- a lot and ends up delaying the creation of cards.
{% set dt_created_minus_2_hours_at = 'dt_created_at - INTERVAL 2 HOUR' %}

-- We want to assign the transaction only to one pipedrive card, i. e., if there are two cards for
-- the same potential customer, just one of them will be assigned to a transaction
nodup_approved_commercial_transactions AS (
    SELECT *
    FROM
        (
            SELECT
                t.*,
                p.id_pipedrive_deal,
                p.nm_salesman_email AS nm_salesman_email_pipedrive,
                p.dt_created_at AS dt_created_at_pipedrive
            FROM int_pipedrive_analytics AS p
            INNER JOIN
                int_commercial_transactions AS t
                -- when pipedrive's cards do not come from zenvia (chat)
                ON
                    t.nm_email = p.nm_person_email
                    -- there will be no upper limit on time, as some deals take 4-5 months
                    -- (and usually they have a high value and this influences the measurements a lot)
                    AND t.dt_ordered_at >= {{ dt_created_minus_2_hours_at }}

            UNION ALL

            SELECT
                t.*,
                p.id_pipedrive_deal,
                p.nm_salesman_email AS nm_salesman_email_pipedrive,
                p.dt_created_at AS dt_created_at_pipedrive
            FROM int_pipedrive_analytics AS p
            INNER JOIN
                int_commercial_transactions AS t
                -- when pipedrive's cards do come from zenvia (chat)
                ON
                    t.cd_cleaned_phone_number = p.cd_person_cleaned_phone_number
                    -- there will be no upper limit on time, as some deaks take 4-5 months
                    -- (and usually they have a high value and this influences the measurements a lot)
                    AND t.dt_ordered_at >= {{ dt_created_minus_2_hours_at }}
        )

    -- To prioritize the transactions we are consider first the transactions which have the same
    -- salesman of the card, and after the transactions which were ordered close to the card creation date
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY id_transaction ORDER BY
                nm_salesman_email = nm_salesman_email_pipedrive DESC, dt_ordered_at - dt_created_at_pipedrive
        ) = 1
),

nodup_approved_mkt_transactions AS (
    SELECT *
    FROM
        (
            SELECT
                t.*,
                p.id_pipedrive_deal,
                p.nm_salesman_email AS nm_salesman_email_pipedrive,
                p.dt_created_at AS dt_created_at_pipedrive
            FROM int_pipedrive_analytics AS p
            INNER JOIN
                int_marketing_transactions AS t
                ON
                    t.nm_email = p.nm_person_email
                    -- we set a upper limit on time, since marketing transactions usually
                    -- takes only a few days to occur
                    AND t.dt_ordered_at >= {{ dt_created_minus_2_hours_at }}
                    AND t.dt_ordered_at < {{ dt_created_minus_2_hours_at }} + INTERVAL 7 DAY

            UNION ALL

            SELECT
                t.*,
                p.id_pipedrive_deal,
                p.nm_salesman_email AS nm_salesman_email_pipedrive,
                p.dt_created_at AS dt_created_at_pipedrive
            FROM int_pipedrive_analytics AS p
            INNER JOIN
                int_marketing_transactions AS t
                ON
                    t.cd_cleaned_phone_number = p.cd_person_cleaned_phone_number
                    -- we set a upper limit on time, since marketing transactions usually
                    -- takes only a few days to occur
                    AND t.dt_ordered_at >= {{ dt_created_minus_2_hours_at }}
                    AND t.dt_ordered_at < {{ dt_created_minus_2_hours_at }} + INTERVAL 7 DAY
        )

    -- To prioritize the transactions we consider the first transaction that was ordered
    -- close to the card creation date
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY id_transaction ORDER BY dt_ordered_at - dt_created_at_pipedrive
        ) = 1
),


-- Unifying a pipedrive informations
-- to calculate the conversion rate
pidedrive_info AS (
    SELECT  -- noqa: ST06
        p.id_pipedrive_deal,
        p.id_person,
        p.nm_person_name,
        p.nm_person_email,
        p.cd_person_cleaned_phone_number,
        p.nm_title,
        p.nm_pipeline,
        p.nm_label,
        p.id_transaction,
        p.id_transaction_first,
        p.vl_payment_gross,
        p.nm_gateway_plan,
        p.vl_score_tech,
        p.vl_real_score_tech,
        p.nm_model_name,
        p.nm_stage,
        p.nm_status,
        p.nm_sale_status,
        p.nm_sirena_link,
        p.nm_salesman_email,
        p.dt_created_at,
        p.dt_closed_at,
        p.nm_commercial_channel,
        p.nm_name_owner,
        p.nm_lead_type,
        p.bl_is_bot_hotlead,
        p.bl_has_fake_score,
        p.nm_transaction_trigger,
        COALESCE(p.nm_label, p.nm_lead_type) AS nm_deal_source,
        REGEXP_EXTRACT(p.nm_sirena_link, r'user\/\S*\/prospect\/(\S+)') AS id_prospect,
        p.nm_lost_reason,

        -- deal category information
        dc.vl_payment_gross_current_cycle,
        dc.vl_payment_gross_last_cycle,
        dc.nm_lead_category,
        dc.nm_churn_reason,
        dc.nm_previous_plan,
        dc.dt_subscription_canceled_at,
        dc.qt_days_to_cancel_after_commercial_interaction
    FROM int_pipedrive_analytics AS p
    LEFT JOIN int_pipedrive_deal_category AS dc
        ON
            p.id_pipedrive_deal = dc.id_pipedrive_deal
            AND p.dt_created_at <= dc.dt_subscription_canceled_at
),

join_pipedrive_zenvia AS (
    SELECT
        h.*,
        z.* EXCEPT (id_prospect),
        ROW_NUMBER() OVER (PARTITION BY h.id_pipedrive_deal ORDER BY z.dt_created_interaction_at) AS qt_interaction_order, --noqa: LT05
        DATETIME_DIFF(
            z.dt_created_interaction_at,
            LAG(z.dt_created_interaction_at) OVER (PARTITION BY h.id_pipedrive_deal ORDER BY z.dt_created_interaction_at), --noqa: LT05
            MINUTE
        ) AS qt_last_interaction_interval_in_minutes
    FROM pidedrive_info AS h
    INNER JOIN int_zenvia_analytics AS z
        ON h.id_prospect = z.id_prospect
        -- the messages should related to the creation of the lead
        -- the 2 hours difference is used to handle a delay between the creation of
        -- the lead and the first message due to zapier
        AND z.dt_created_interaction_at
        BETWEEN h.dt_created_at - INTERVAL 2 HOUR AND COALESCE(h.dt_closed_at, CURRENT_DATETIME())
),

deal_conversations AS (
    SELECT  -- noqa: ST06
        id_pipedrive_deal,
        COUNT(*) AS qt_interactions,
        SUM(bl_prospect_interaction) AS qt_user_interactions,
        STRING_AGG(
            CONCAT(
                IF(bl_prospect_interaction = 1, '### USER: ', '### SELLER: '),
                FORMAT_DATETIME('%Y-%m-%dT%H:%M:%SZ', dt_created_interaction_at),
                '\n',
                COALESCE(nm_body_message, CONCAT('{', nm_interaction_type, '}'))
            ), '\n\n'
            ORDER BY dt_created_interaction_at
        ) AS nm_conversation,
        MIN(dt_created_interaction_at) AS dt_first_message,
        MAX(dt_created_interaction_at) AS dt_last_message,
        CASE
            WHEN MAX(dt_created_at) < MIN(dt_created_interaction_at) THEN
                CASE
                    WHEN SUM(bl_seller_interaction) > 0 AND SUM(bl_prospect_interaction) > 0 THEN 'respondido'
                    WHEN SUM(bl_seller_interaction) = 0 AND SUM(bl_prospect_interaction) > 0 THEN 'aguardando-atendimento' --noqa: LT05
                    WHEN SUM(bl_seller_interaction) > 0 AND SUM(bl_prospect_interaction) = 0 THEN 'abordado'
                END
        END AS nm_approach_stage,
        MIN_BY(
            IF(bl_prospect_interaction = 1, qt_interaction_order, NULL) - 1,
            IF(bl_prospect_interaction = 1, dt_created_interaction_at, CURRENT_DATETIME())
        ) AS qt_interactions_until_first_prospect_message,
        MIN_BY(
            IF(bl_prospect_interaction = 1, qt_last_interaction_interval_in_minutes, NULL),
            IF(bl_prospect_interaction = 1, dt_created_interaction_at, CURRENT_DATETIME())
        ) AS qt_interval_since_first_interaction_in_minutes
    FROM join_pipedrive_zenvia
    GROUP BY 1  -- noqa: AM06
),

commercial_transactions_grouped_by_deal AS (
    SELECT
        id_pipedrive_deal,
        COUNT(*) AS qt_commercial_transactions,
        ARRAY_AGG(
            STRUCT(
                id_transaction,
                nm_salesman_email,
                dt_ordered_at,
                nm_gateway_plan,
                vl_payment_gross
            )
        ) AS arr_st_commercial_transactions
    FROM nodup_approved_commercial_transactions
    GROUP BY 1
),

join_tables AS (
    SELECT
        -- leads' informations
        p.id_pipedrive_deal,
        p.id_person,
        p.nm_person_name,
        p.nm_person_email,
        p.cd_person_cleaned_phone_number,
        p.nm_title,
        p.nm_label,
        p.id_transaction AS id_last_transaction,
        p.id_transaction_first AS id_source_transaction,
        p.vl_payment_gross AS vl_source_payment_gross,
        p.nm_gateway_plan AS nm_source_gateway_plan,
        p.vl_score_tech,
        p.vl_real_score_tech,
        p.nm_model_name,
        p.nm_status,
        p.nm_sale_status,
        p.nm_commercial_channel,
        p.nm_stage,
        p.dt_created_at,
        p.dt_closed_at,
        v.nm_sales_team,
        p.nm_sirena_link,
        p.nm_salesman_email,
        p.bl_is_bot_hotlead,
        p.bl_has_fake_score,
        p.nm_transaction_trigger,
        p.nm_lost_reason,
        -- deal category information
        p.vl_payment_gross_current_cycle,
        p.vl_payment_gross_last_cycle,
        p.nm_lead_category,
        p.nm_churn_reason,
        p.nm_previous_plan,
        p.dt_subscription_canceled_at,
        p.qt_days_to_cancel_after_commercial_interaction,
        -- transactions' informations
        t.id_transaction,
        t.id_gateway_customer,
        t.nm_gateway_plan,
        t.id_subscription,
        t.dt_ordered_at,
        t.nm_payment_method,
        t.vl_payment_gross,
        DATE_DIFF(t.dt_ordered_at, p.dt_created_at, DAY) AS qt_days_deal_won,
        DATE_DIFF(COALESCE(t.dt_ordered_at, p.dt_closed_at), c.dt_first_message, DAY) AS qt_lead_time_days,
        DATETIME_DIFF(t.dt_ordered_at, {{ dt_created_minus_2_hours_at }}, DAY) AS qt_negotiation_days,
        COALESCE(t.nm_seller, p.nm_name_owner) AS nm_name_owner,
        p.nm_deal_source,
        UPPER(CONCAT(p.nm_deal_source, ' - ', p.nm_transaction_trigger)) AS nm_hotlead_type,
        -- mkt informations
        mkt.id_transaction AS id_mkt_transaction,
        mkt.nm_gateway_plan AS nm_mkt_gateway_plan,
        mkt.id_subscription AS id_mkt_subscription,
        mkt.dt_ordered_at AS dt_mkt_ordered_at,
        mkt.nm_payment_method AS nm_mkt_payment_method,
        mkt.vl_payment_gross AS vl_mkt_payment_gross,
        -- conversation
        c.nm_conversation,
        c.dt_first_message,
        c.dt_last_message,
        c.qt_interactions,
        c.qt_user_interactions,
        c.nm_approach_stage,
        -- conversation first prospect message informations
        c.qt_interactions_until_first_prospect_message,
        c.qt_interval_since_first_interaction_in_minutes,
        -- commercial transactions
        g.arr_st_commercial_transactions,
        g.qt_commercial_transactions

    FROM pidedrive_info AS p
    LEFT JOIN nodup_approved_commercial_transactions AS t
        ON p.id_pipedrive_deal = t.id_pipedrive_deal
    LEFT JOIN nodup_approved_mkt_transactions AS mkt
        ON p.id_pipedrive_deal = mkt.id_pipedrive_deal
    LEFT JOIN int_rppc_vendedores AS v
        ON v.nm_agent_email = COALESCE(t.nm_salesman_email, p.nm_salesman_email)
    LEFT JOIN deal_conversations AS c
        ON p.id_pipedrive_deal = c.id_pipedrive_deal
    LEFT JOIN commercial_transactions_grouped_by_deal AS g
        ON p.id_pipedrive_deal = g.id_pipedrive_deal

    -- we are only catching occurrences of non-null id_person
    -- because of a problem derived from not assigning a fired salesperson.
    WHERE p.id_person IS NOT NULL

    -- if the deal appears on multiple deals, choose one of the deals
    -- (the one with the shortest time gap between deal creation and transaction)
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY p.id_pipedrive_deal
            ORDER BY t.nm_salesman_email = p.nm_salesman_email DESC, t.dt_ordered_at - {{ dt_created_minus_2_hours_at }}
        ) = 1
),

-- Selects the payment gross in the last cycle of a deal
final AS (
    SELECT
        jt.* EXCEPT (id_subscription),
        ft.cd_cycle,
        -- We can have several retry charges in the same subscription cycle, so let's list
        -- the charges in order to select just one deal per subscription cycle in the future
        ROW_NUMBER() OVER (
            PARTITION BY ft.id_subscription, ft.cd_cycle ORDER BY ft.dt_created_at
        ) AS cd_deal_of_cycle,
        COALESCE(jt.id_subscription, ft.id_subscription, bc.id_subscription) AS id_subscription,
        -- We may have situations where the id_source_transaction is not found in the billing_cycle,
        -- because the billing_cycle has updated the id_transaction with the last retry
        COALESCE(bc.vl_payment_gross_last_cycle, jt.vl_source_payment_gross) AS vl_payment_gross_previous_cycle
    FROM join_tables AS jt
    LEFT JOIN fct_transactions AS ft
        ON jt.id_source_transaction = ft.id_transaction
    LEFT JOIN int_subscription_billing_cycle AS bc
        ON
            ft.id_subscription = bc.id_subscription
            AND ft.cd_cycle = bc.cd_cycle
            AND bc.cd_cycle > 1
)

SELECT * FROM final
