-- models/marts/dim_station.sql
--
-- Origen : DEV_SILVER_DB.staging.stg_stations
--          DEV_SILVER_DB.staging.stg_zones
-- Destino: DEV_GOLD_DB.marts.dim_station
-- Grano  : 1 fila por estación (50 registros)
--
-- Notas:
--   · Catálogo estático, no necesita incremental ni SCD2
--   · Se materializa como table (hereda de dbt_project.yml)
--   · Se hace JOIN con stg_zones para desnormalizar zona y cuadrante
--     en la dimensión — patrón habitual en modelado dimensional

WITH stg_stations AS (

    SELECT * FROM {{ ref('stg_stations') }}

),

stg_zones AS (

    SELECT * FROM {{ ref('stg_zones') }}

),

dim_station AS (

    SELECT

        s.station_id,       -- PK
        s.station_name,
        s.latitude,
        s.longitude,
        z.zone_id,          -- FK → stg_zones (desnormalizada)
        z.zone_name,
        z.quadrant

    FROM stg_stations s
    INNER JOIN stg_zones z
        ON s.zone_id = z.zone_id

)

SELECT * FROM dim_station