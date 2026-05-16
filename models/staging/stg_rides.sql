-- models/staging/stg_rides.sql
--
-- Origen : DEV_BRONZE_DB.RAW.rides
-- Destino: DEV_SILVER_DB.staging.stg_rides
-- Grano  : 1 fila por viaje (5000 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · Eliminadas métricas económicas → absorbidas por stg_payments
--   · Eliminados: ruta_id, fecha_fin, descuento_promo_pct (redundantes)
--   · es_ida_vuelta / is_trayecto_rentable: 'sí'/'no' → BOOLEAN
--   · started_at / ended_at: cast explícito a TIMESTAMP
--   · fecha_inicio → start_date: cast explícito a DATE
--   · codigo_promo: 'NINGUNA' → NULL (no es una promo real)
--   · rideable_type → bike_type_id: UPPER() para FK con stg_bikes
--   · IDs a UPPER() para consistencia con resto de Silver
--   · Strings descriptivos a UPPER()
--   · velocidad_kmh y distancia_km: ROUND a 2 decimales


--HE DECIDIDO CREAR ESTA MATERIALIZACIÓN COMO INCREMENTAL POR 
-- Cada viaje es un evento nuevo e inmutable. Nunca se modifica, solo crece.
{{ config(
    materialized='incremental',
    incremental_strategy='append'
) }}

WITH source_rides AS (

    SELECT * FROM {{ source('raw', 'rides') }}

    --AÑADIMOS ESTA CONDICIÓN DE COMPROBACIÓN SI ES INCREMENTAL O AUN NO ESTÁ CREADA
    {% if is_incremental() %}
        WHERE started_at::TIMESTAMP > (SELECT MAX(started_at) FROM {{ this }})
    {% endif %}

),

renamed AS (

    SELECT
       
        UPPER(ride_id)                                          AS ride_id,          -- PK
        UPPER(user_id)                                          AS user_id,          -- FK
        UPPER(rideable_type)                                    AS bike_type_id,     -- FK
        start_station_id::INTEGER                               AS start_station_id, -- FK
        end_station_id::INTEGER                                 AS end_station_id,   -- FK
        fecha_inicio::DATE                                      AS start_date,       -- FK
        weather_id::INTEGER                                     AS weather_id,       -- FK
        UPPER(payment_id)                                       AS payment_id,       -- FK

        -- Código promo: NINGUNA → NULL (FK opcional a stg_promotions)
        CASE WHEN UPPER(codigo_promo) = 'NINGUNA'
             THEN NULL
             ELSE UPPER(codigo_promo)
        END                                                     AS promo_code,

        -- Timestamps
        started_at::TIMESTAMP                                   AS started_at,
        ended_at::TIMESTAMP                                     AS ended_at,

        -- Horas
        hora_inicio::INTEGER                                    AS start_hour,
        hora_fin::INTEGER                                       AS end_hour,

        -- Métricas 
        ride_length_mins::INTEGER                               AS ride_length_mins,
        ROUND(distancia_km::NUMBER, 2)                          AS distance_km,
        ROUND(velocidad_kmh::NUMBER, 2)                         AS speed_kmh,

        -- Segmentación
        UPPER(segmento_viaje)                                   AS trip_segment,
        UPPER(categoria_duracion)                               AS duration_category,

        -- CAMBIO LOS VALORES DE AMBOS CAMPOS POR TRUE O FALSE
        CASE WHEN LOWER(es_ida_vuelta) = 'sí'
             THEN TRUE ELSE FALSE END                           AS is_round_trip,
        CASE WHEN LOWER(is_trayecto_rentable) = 'sí'
             THEN TRUE ELSE FALSE END                           AS is_profitable

    FROM source_rides

)

SELECT * FROM renamed