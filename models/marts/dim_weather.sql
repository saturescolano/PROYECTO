
-- models/marts/dim_weather.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_weather
-- Destino: DEV_GOLD_DB.marts.dim_weather
-- Grano  : 1 fila por condición meteorológica (11 registros)
--
-- Notas:
--   · Catálogo estático, no necesita incremental ni SCD2
--   · Se materializa como table (hereda de dbt_project.yml)

WITH stg_weather AS (

    SELECT * FROM {{ ref('stg_weather') }}

),

dim_weather AS (

    SELECT

        weather_id,        -- PK
        season_year,
        temp_category,
        avg_temp_c

    FROM stg_weather

)

SELECT * FROM dim_weather