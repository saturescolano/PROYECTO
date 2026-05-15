-- models/staging/stg_stations.sql
--
-- Origen : DEV_BRONZE_DB.RAW.stations
-- Destino: DEV_SILVER_DB.staging.stg_stations
-- Grano  : 1 fila por estación (50 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · zone_id obtenido por JOIN con stg_zones (FK)
--   · barrio eliminado — redundante con zone_name en stg_zones
--   · lat / lng: ROUND a 6 decimales (precisión GPS estándar)
--   · station_name a UPPER()

WITH source_stations AS (

    SELECT * FROM {{ source('raw', 'stations') }}

),

zones AS (

    SELECT * FROM {{ ref('stg_zones') }}

),

renamed AS (

    SELECT
       
        s.station_id::INTEGER                                   AS station_id,    -- PK

        -- Descriptivos
        UPPER(s.station_name)                                   AS station_name,

        -- Coordenadas
        ROUND(s.lat::NUMBER, 6)                                 AS latitude,
        ROUND(s.lng::NUMBER, 6)                                 AS longitude,

        
        z.zone_id                                               AS zone_id        -- FK procede de "stg_zones"

    FROM source_stations s
    INNER JOIN zones z
        ON UPPER(s.zona) = z.zone_name

)

SELECT * FROM renamed