-- models/marts/fct_payments.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_payments (principal)
-- Destino: DEV_GOLD_DB.marts.fct_payments
-- Grano  : 1 fila por pago (5000 registros)
--
-- Notas:
--   · Incremental append — cada pago es un evento inmutable que solo crece
--   · Contiene todas las métricas económicas del negocio
--   · Las claves foráneas apuntan a las dims de Gold

{{ config(
        materialized='incremental',
        incremental_strategy='append'
) }}

WITH stg_payments AS (

    SELECT * FROM {{ ref('stg_payments') }}

    {% if is_incremental() %}
        WHERE payment_date > (SELECT MAX(payment_date) FROM {{ this }})
    {% endif %}

),

fct_payments AS (

    SELECT

        payment_id,             -- PK
        ride_id,                -- FK → fct_rides
        user_id,                -- FK → dim_user

        -- Atributos del pago
        payment_method,
        payment_status,
        payment_date,

        -- Métricas económicas
        gross_price_usd,
        promo_discount_usd,
        plan_discount_usd,
        total_discount_usd,
        net_price_usd

    FROM stg_payments

)

SELECT * FROM fct_payments