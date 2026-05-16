-- macros/generate_database_name.sql
-- Macro OPCIONAL pero recomendada. Controla a qué base de datos
-- se materializa cada modelo. Sin ella +database funciona igual,
-- pero tenerla hace el routing explícito y fácil de debuggear.

 
-- macros/generate_database_name.sql

{% macro generate_database_name(custom_database_name, node) -%}

    {%- if custom_database_name is not none -%}
        {{ custom_database_name | trim | upper }}
    {%- else -%}
        {{ target.database | trim | upper }}
    {%- endif -%}

{%- endmacro %}