-- snapshots/dim_user.sql


-- COMIENZO DE INCREMENTAL TIPO SCD2
{% snapshot dim_user %}

{{
    config(
        target_database=env_var('DBT_ENVIRONMENT') ~ '_GOLD_DB',
        target_schema='marts',
        unique_key='user_id',
        strategy='check',               
        check_cols=[
            'membership_id',
            'customer_email',
            'customer_gender',
            'registration_city',
            'customer_country',
            'member_type',
            'card_last4',
            'card_type',
            'plan_type',
            'monthly_price_usd',
            'discount_pct'
        ]
    )
}}
WITH stg_users AS (

    SELECT * FROM {{ ref('stg_users') }}

),

stg_memberships AS (

    SELECT * FROM {{ ref('stg_memberships') }}

),

dim_user AS (

    SELECT
        u.user_id,              -- PK
        u.membership_id,        -- FK
        u.customer_name,
        u.customer_email,
        u.customer_age,
        u.age_segment,
        u.customer_gender,
        u.registration_city,
        u.customer_country,
        u.registration_date,
        u.member_type,
        u.card_last4,
        u.card_type,

        -- Campos absorbidos desde stg_memberships (susceptibles de cambio)
        m.plan_type,
        m.monthly_price_usd,
        m.discount_pct

    FROM stg_users u
    INNER JOIN stg_memberships m
        ON u.membership_id = m.membership_id

)

SELECT * FROM dim_user

{% endsnapshot %}