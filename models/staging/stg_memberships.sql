-- models/staging/stg_memberships.sql
--
-- Origen : DEV_BRONZE_DB.RAW.memberships
-- Destino: DEV_SILVER_DB.staging.stg_memberships
-- Grano  : 1 fila por membresía (280 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · IDs a UPPER() para consistencia con stg_users (FK)
--   · plan_type a UPPER()
--   · monthly_price_usd: cast a NUMBER exacto + 2 decimales
--   · discount_pct: cast explícito a INTEGER

WITH source_memberships AS (

    SELECT * FROM {{ source('raw', 'memberships') }}

),

renamed AS (

    SELECT
       
        UPPER(membership_id)                                    AS membership_id,  -- PK
        UPPER(user_id)                                          AS user_id, -- FK → stg_users (debe coincidir exactamente)
        UPPER(tipo_plan)                                        AS plan_type, -- Atributos del plan
        ROUND(precio_mensual_usd::NUMBER, 2)                    AS monthly_price_usd,
        descuento_pct::INTEGER                                  AS discount_pct

    FROM source_memberships

)

SELECT * FROM renamed