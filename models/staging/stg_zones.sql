-- models/staging/stg_zones.sql
--
-- Origen : DEV_BRONZE_DB.RAW.stations (columnas cuadrante + zona)
-- Destino: DEV_SILVER_DB.staging.stg_zones
-- Grano  : 1 fila por zona geográfica única (11 registros)
--
-- Cambios respecto a Bronze:
--   · No existe tabla propia en Bronze — construido con SELECT DISTINCT
--   · zone_id generado sintéticamente con ROW_NUMBER()
--   · Renombrado completo a inglés
--   · Strings a UPPER()

WITH source_zones AS (

    SELECT * FROM {{ source('raw', 'stations') }}

),

zones AS (

    SELECT DISTINCT --sacamos las diferentes que hay sin repetir
        UPPER(cuadrante)                                        AS quadrant,
        UPPER(zona)                                             AS zone_name

    FROM source_zones

),

with_id AS (

    SELECT
        
        ROW_NUMBER() OVER (ORDER BY zone_name)::INTEGER         AS zone_id, --PK (la generamos de forma secuencial)
        zone_name,
        quadrant

    FROM zones

)

SELECT * FROM with_id