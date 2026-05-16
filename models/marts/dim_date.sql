-- models/marts/dim_date.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_dates
-- Destino: DEV_GOLD_DB.marts.dim_date
-- Grano  : 1 fila por fecha/hora (365 registros)
--
-- Notas:
--   · Dimensión tiempo inmutable, no necesita incremental ni SCD2
--   · Se materializa como table (hereda de dbt_project.yml)

WITH stg_dates AS (

    SELECT * FROM {{ ref('stg_dates') }}

),

dim_date AS (

    SELECT

        date_id,            -- PK
        year,
        month_number,
        month_name,
        quarter,
        weekday_number,
        weekday_name,
        is_weekend,
        hour,
        time_slot,
        shift,
        is_peak_hour

    FROM stg_dates

)

SELECT * FROM dim_date