-- models/staging/stg_weather.sql
--
-- Origen : DEV_BRONZE_DB.RAW.weather
-- Destino: DEV_SILVER_DB.staging.stg_weather
-- Grano  : 1 fila por condición meteorológica (11 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · Strings descriptivos a UPPER()
--   · Cast explícito de tipos numéricos

WITH source_weather AS (

    SELECT * FROM {{ source('raw', 'weather') }}

),

renamed AS (

    SELECT
        
        weather_id::INTEGER                                     AS weather_id,    -- PK

        -- Descriptivos
        UPPER(estacion_anio)                                    AS season_year,
        UPPER(categoria_temp)                                   AS temp_category,

        -- Temperatura
        temp_media_c::INTEGER                                   AS avg_temp_c

    FROM source_weather

)

SELECT * FROM renamed