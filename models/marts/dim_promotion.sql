-- models/marts/dim_promotion.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_promotions
-- Destino: DEV_GOLD_DB.marts.dim_promotion
-- Grano  : 1 fila por código promocional
--
-- Notas:
--   · Catálogo estático, no necesita incremental ni SCD2
--   · Se materializa como table (hereda de dbt_project.yml)

WITH stg_promotions AS (

    SELECT * FROM {{ ref('stg_promotions') }}

),

dim_promotion AS (

    SELECT

        promo_code,          -- PK
        promo_discount_pct

    FROM stg_promotions

)

SELECT * FROM dim_promotion