-- models/staging/stg_bikes.sql
--
-- Origen : DEV_BRONZE_DB.RAW.bikes 
-- Destino: DEV_SILVER_DB.staging.stg_bikes (DONDE VAMOS A MATERIALIZAR LA VISTA)
-- Grano  : 1 fila por tipo de bicicleta (SOLAMENTE TENEMOS 3 TIPOS DE BICICLETA)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · rideable_type → bike_type_id (deja claro que es PK)
--   · is_electric / has_dock: 'sí'/'no' → BOOLEAN
--   · Strings a UPPER() para consistencia con el resto de Silver
 
WITH source_bike AS (
 
    SELECT * FROM {{ source('raw', 'bikes') }}
 
),
 
renamed AS ( 
    SELECT
        UPPER(rideable_type)    AS bike_type_id,     -- PK
        UPPER(nombre_tipo_bici) AS bike_type_name,  -- Descriptivos
 
        -- CAMBIAR EL VALOR (sí → TRUE, no → FALSE) de esta forma será más reutilizable para hacer comparaciones a posteriori
        CASE WHEN LOWER(bici_es_electrica) = 'sí'
             THEN TRUE ELSE FALSE END                           AS is_electric,
 
        CASE WHEN LOWER(bici_tiene_muelle) = 'sí'
             THEN TRUE ELSE FALSE END                           AS has_dock,
 
        -- Precios: cast a NUMBER exacto + máximo 2 decimales
        ROUND(precio_desbloqueo_usd::NUMBER, 2)    AS unlock_price_usd,
        ROUND(precio_por_minuto_usd::NUMBER, 2)    AS price_per_min_usd
 
    FROM source_bike
 
)

SELECT * FROM renamed