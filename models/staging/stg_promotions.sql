-- models/staging/stg_promotions.sql
--
-- Origen : DEV_BRONZE_DB.RAW.rides (columnas codigo_promo + descuento_promo_pct)
-- Destino: DEV_SILVER_DB.staging.stg_promotions
-- Grano  : 1 fila por código promocional único (4 registros reales)
--
-- Cambios respecto a Bronze:
--   · Construido con SELECT DISTINCT desde rides — no existe tabla propia en Bronze
--   · Renombrado completo a inglés
--   · Se excluye 'NINGUNA' — no es una promoción real, es valor por defecto
--   · promo_code a UPPER() para consistencia con FK en stg_rides
--   · promo_discount_pct: cast explícito a INTEGER

WITH source AS (

    SELECT * FROM {{ source('raw', 'rides') }}

),

promotions AS (

    SELECT DISTINCT
        
        UPPER(codigo_promo)                                     AS promo_code,          -- PK
        descuento_promo_pct::INTEGER                            AS promo_discount_pct   -- Atributos

    FROM source

    
    WHERE UPPER(codigo_promo) != 'NINGUNA' -- Excluimos el valor NINGUNA

)

SELECT * FROM promotions