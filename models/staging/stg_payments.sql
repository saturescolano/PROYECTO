-- models/staging/stg_payments.sql
--
-- Origen : BRONZE_DB.RAW.payments (principal)
--          BRONZE_DB.RAW.rides    (métricas económicas + user_id)
-- Destino: SILVER_DB.staging.stg_payments
-- Grano  : 1 fila por pago (5000 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · IDs a UPPER() para consistencia con resto de Silver
--   · payment_method y payment_status a UPPER()
--   · fecha_pago → payment_date: cast explícito a DATE
--   · Métricas económicas absorbidas desde RAW.rides
--   · user_id añadido desde RAW.rides (FK → stg_users)
--   · Precios: cast a NUMBER exacto + 2 decimales

-- MATERIALIZACIÓN INCREMENTAL CON APPEND
-- Cada pago es un evento nuevo e inmutable. Nunca se modifica, solo crece.

{{ config(
    materialized='incremental',
    incremental_strategy='append'
) }}

WITH source_payments AS (

    SELECT * FROM {{ source('raw', 'payments') }}

),

incremental_filter AS (

    SELECT * FROM source_payments

    {% if is_incremental() %}
        WHERE fecha_pago::DATE > (SELECT MAX(payment_date) FROM {{ this }})
    {% endif %}

),

source_rides AS (

    SELECT * FROM {{ source('raw', 'rides') }}

),

renamed AS (

    SELECT

        UPPER(p.payment_id)                                     AS payment_id, -- PK
        UPPER(p.ride_id)                                        AS ride_id,    -- FK
        UPPER(r.user_id)                                        AS user_id,    -- FK

        -- Atributos del pago
        UPPER(p.payment_method)                                 AS payment_method,
        UPPER(p.payment_status)                                 AS payment_status,
        p.fecha_pago::DATE                                      AS payment_date,

        -- Métricas económicas (vienen de rides)
        ROUND(r.precio_bruto_usd::NUMBER, 2)                    AS gross_price_usd,
        ROUND(r.descuento_promo_usd::NUMBER, 2)                 AS promo_discount_usd,
        ROUND(r.descuento_plan_usd::NUMBER, 2)                  AS plan_discount_usd,
        ROUND(r.descuento_total_usd::NUMBER, 2)                 AS total_discount_usd,
        ROUND(r.precio_neto_usd::NUMBER, 2)                     AS net_price_usd

    FROM incremental_filter p
    INNER JOIN source_rides r
        ON UPPER(p.ride_id) = UPPER(r.ride_id)

)

SELECT * FROM renamed