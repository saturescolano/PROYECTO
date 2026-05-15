-- models/staging/stg_users.sql
--
-- Origen : DEV_BRONZE_DB.RAW.users
-- Destino: DEV_SILVER_DB.staging.stg_users
-- Grano  : 1 fila por usuario (400 registros)
--
-- Cambios respecto a Bronze:
--   · Renombrado completo a inglés
--   · IDs a UPPER() para consistencia con resto de Silver
--   · Strings descriptivos a UPPER()
--   · registration_date: cast explícito a DATE
--   · customer_age: cast explícito a INTEGER
--   · numero_tarjeta → card_last4: enmascarado por PII,
--     se conservan solo los últimos 4 dígitos

WITH source_users AS (

    SELECT * FROM {{ source('raw', 'users') }}

),

renamed AS (

    SELECT
        
        UPPER(user_id)                                          AS user_id,         -- PK
        UPPER(membership_id)                                    AS membership_id,   -- FK viene de "stg_memberships"

        -- Datos personales
        customer_name                                           AS customer_name,
        LOWER(email_cliente)                                    AS customer_email,  -- Ponemso en minúscula para una mejor interpretación
        edad_cliente::INTEGER                                   AS customer_age,
        UPPER(segmento_edad)                                    AS age_segment,
        UPPER(genero_cliente)                                   AS customer_gender,

        -- Datos de registro
        UPPER(ciudad_registro)                                  AS registration_city,
        UPPER(pais_cliente)                                     AS customer_country,
        fecha_registro::DATE                                    AS registration_date,
        UPPER(member_type)                                      AS member_type,

        -- Tarjeta: enmascarada por PII → solo últimos 4 dígitos
        RIGHT(REPLACE(numero_tarjeta, '-', ''), 4)              AS card_last4,
        UPPER(tipo_tarjeta)                                     AS card_type

    FROM source_users

)

SELECT * FROM renamed