-- models/marts/dim_bike.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_bikes
-- Destino: DEV_GOLD_DB.marts.dim_bike
-- Grano  : 1 fila por tipo de bicicleta (3 registros)
--
-- Notas:
--   · Catálogo estático, no necesita incremental ni SCD2
--   · Se materializa como table (hereda de dbt_project.yml)

--SE MATERIALIZA EN TABLA
WITH stg_bikes AS (

    SELECT * FROM {{ ref('stg_bikes') }}

),

dim_bike AS (

    SELECT

        bike_type_id,        -- PK
        bike_type_name,
        is_electric,
        has_dock,
        unlock_price_usd,
        price_per_min_usd

    FROM stg_bikes

)

SELECT * FROM dim_bike