-- macros/generate_schema_name.sql
-- Macro OBLIGATORIA. Sin ella dbt concatena tu usuario al schema:
-- DEV_SILVER_DB.dbt_usuario_staging en vez de DEV_SILVER_DB.staging
-- macros/generate_schema_name.sql

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim | upper }}
    {%- else -%}
        {{ default_schema | upper }}
    {%- endif -%}

{%- endmacro %}