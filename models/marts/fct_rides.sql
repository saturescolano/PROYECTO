-- models/marts/fct_rides.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_rides (principal)
-- Destino: DEV_GOLD_DB.marts.fct_rides
-- Grano  : 1 fila por viaje (5000 registros)
--
-- Notas:
--   · Incremental append — cada viaje es un evento inmutable que solo crece
--   · Las claves foráneas apuntan a las dims de Gold
--   · No contiene métricas económicas — absorbidas por fct_payments


--AQUI TAMBIÉN TENEMOS UNA INCREMENTAL (APPEND)
{{  config(
        materialized='incremental',
        incremental_strategy='append'
) }}

WITH stg_rides AS (

    SELECT * FROM {{ ref('stg_rides') }}

    {% if is_incremental() %}
        WHERE started_at > (SELECT MAX(started_at) FROM {{ this }})
    {% endif %}

),

fct_rides AS (

    SELECT

        ride_id,                -- PK
        user_id,                -- FK → dim_user
        bike_type_id,           -- FK → dim_bike
        start_station_id,       -- FK → dim_station
        end_station_id,         -- FK → dim_station
        start_date,             -- FK → dim_date
        weather_id,             -- FK → dim_weather
        payment_id,             -- FK → fct_payments
        promo_code,             -- FK → dim_promotion (opcional)

        -- Timestamps
        started_at,    --ESTE ES EL CAMPO POR EL QUE HEMOS FILTRADO LA INCREMENTAL
        ended_at,

        -- Horas
        start_hour,
        end_hour,

        -- Métricas operacionales
        ride_length_mins,
        distance_km,
        speed_kmh,

        -- Segmentación
        trip_segment,
        duration_category,
        is_round_trip,
        is_profitable

    FROM stg_rides

)

SELECT * FROM fct_rides