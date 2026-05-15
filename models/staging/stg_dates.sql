-- models/staging/stg_dates.sql
--
-- Origen : DEV_BRONZE_DB.RAW.dates
-- Destino: DEV_SILVER_DB.staging.stg_dates 
-- Grano  : 1 fila por fecha+hora (365 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · fecha → date_id (PK), cast explícito a DATE
--   · es_fin_semana / es_hora_pico: 'sí'/'no' → BOOLEAN
--   · Strings descriptivos a UPPER()

WITH source_dates AS (

    SELECT * FROM {{ source('raw', 'dates') }} -- Así es como se hace referencia al origen, concretamente a dates

),

renamed AS (

    SELECT
        
        fecha::DATE                                             AS date_id, -- PK
        anio                                                    AS year, -- Atributos de año/mes/trimestre
        mes_numero                                              AS month_number,
        UPPER(nombre_mes)                                       AS month_name,
        trimestre                                               AS quarter,

        
        dia_semana_numero                                       AS weekday_number, -- Atributos de día
        UPPER(nombre_dia)                                       AS weekday_name,

        CASE WHEN LOWER(es_fin_semana) = 'sí' --Se vuelve a cambiar los valores por TRUE O FALSE PARA REUTILIZARLO EN COMPARACIONES EN GOLD
             THEN TRUE ELSE FALSE END   AS is_weekend,

        -- Atributos de hora
        hora                                                    AS hour,
        UPPER(franja_horaria)                                   AS time_slot,
        UPPER(turno)                                            AS shift,
        CASE WHEN LOWER(es_hora_pico) = 'sí'
             THEN TRUE ELSE FALSE END                           AS is_peak_hour

    FROM source_dates

)

SELECT * FROM renamed