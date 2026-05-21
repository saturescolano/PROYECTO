# PROYECTO
Repositorio del proyecto en el curso Data Engineering del alumno Saturnino Escolano López

# PROYECTO_DE58 — Sistema de bicicletas compartidas

Proyecto dbt sobre Snowflake del curso de Data Engineering — alumno **Saturnino Escolano López (DE58)**.

Implementa el pipeline completo **Bronze → Silver → Gold** (arquitectura Medallion) para un dataset operacional de un sistema de bicicletas compartidas: viajes, pagos, usuarios, estaciones, tarifas, meteorología y promociones.

---

## Tabla de contenidos

1. [Visión general](#1-visión-general)
2. [Arquitectura del pipeline](#2-arquitectura-del-pipeline)
3. [Stack y versiones](#3-stack-y-versiones)
4. [Estructura del repositorio](#4-estructura-del-repositorio)
5. [Configuración del proyecto (`dbt_project.yml`)](#5-configuración-del-proyecto-dbt_projectyml)
6. [Macros de routing](#6-macros-de-routing)
7. [Bronze — Sources](#7-bronze--sources)
8. [Silver — Staging](#8-silver--staging)
9. [Gold — Marts y snapshot](#9-gold--marts-y-snapshot)
10. [Tests y calidad de datos](#10-tests-y-calidad-de-datos)
11. [Prueba de ingesta incremental](#11-prueba-de-ingesta-incremental)
12. [Comandos habituales](#12-comandos-habituales)

---

## 1. Visión general

El proyecto modela un sistema operacional de bicicletas compartidas y lo transforma en un **modelo dimensional en estrella** listo para consumo BI (Power BI). Las decisiones de diseño siguen el patrón estándar del curso:

- **Bronze (`*_BRONZE_DB.RAW`)**: datos crudos cargados desde CSVs, sin transformar. Fuente de verdad auditable.
- **Silver (`*_SILVER_DB.STAGING`)**: limpieza, casting, renombrado a inglés, normalización en 3FN. Una versión de la verdad.
- **Gold (`*_GOLD_DB.MARTS`)**: modelo dimensional desnormalizado en estrella, optimizado para consumo analítico.

Cada capa vive en **su propia base de datos en Snowflake** y se replica por entorno (`DEV_*` y `PRO_*`).

## 2. Arquitectura del pipeline

```
   CSVs ───►  *_BRONZE_DB.RAW  ───►  *_SILVER_DB.STAGING  ───►  *_GOLD_DB.MARTS  ───►  Power BI
              (sources)              (10 modelos stg_*)        (6 dims + 2 fcts
                                                                + snapshot SCD2)
```

**Modelo dimensional (Gold):**

- **Hechos**: `fct_rides` (5 000 viajes) y `fct_payments` (5 000 pagos) — ambos incrementales append.
- **Dimensiones**: `dim_bike`, `dim_date`, `dim_station`, `dim_weather`, `dim_promotion` (todas tabla) + **`dim_user` como snapshot SCD2** que vive directamente en `GOLD_DB.marts`.

**Decisión clave**: las métricas económicas (`gross_price_usd`, descuentos, `net_price_usd`) viven en `fct_payments`, no en `fct_rides`. Esto permite analizar el negocio por dos ejes independientes (operacional y financiero) sin duplicar columnas.

## 3. Stack y versiones

| Componente   | Versión / Detalle                                                            |
| ------------ | ---------------------------------------------------------------------------- |
| dbt          | **Fusion 2.0** (sintaxis Fusion: `arguments:` en tests, sin `dbt deps`, etc.) |
| Adapter      | Snowflake                                                                    |
| Orquestación | dbt Platform (Snowsight)                                                     |
| Versionado   | Git + GitHub (este repo)                                                     |
| BI           | Power BI (dashboard en `PROYECTO_DE58_POWER_BI.pbix`)                        |

## 4. Estructura del repositorio

```
PROYECTO/
├── dbt_project.yml                  # configuración global del proyecto
├── macros/
│   ├── generate_schema_name.sql     # routing de schemas
│   └── generate_database_name.sql   # routing de databases
├── models/
│   ├── staging/
│   │   ├── raw/
│   │   │   └── __sources.yml        # declaración de sources Bronze
│   │   ├── __models.yml             # docs + tests de los stg_*
│   │   ├── stg_bikes.sql
│   │   ├── stg_dates.sql
│   │   ├── stg_memberships.sql      # materialized=table (lo lee el snapshot)
│   │   ├── stg_payments.sql         # incremental append
│   │   ├── stg_promotions.sql       # construido con DISTINCT desde rides
│   │   ├── stg_rides.sql            # incremental append
│   │   ├── stg_stations.sql
│   │   ├── stg_users.sql            # materialized=table (lo lee el snapshot)
│   │   ├── stg_weather.sql
│   │   └── stg_zones.sql            # construido con DISTINCT desde stations
│   └── marts/
│       ├── __model.yml              # docs + tests de dims y fcts
│       ├── dim_bike.sql
│       ├── dim_date.sql
│       ├── dim_promotion.sql
│       ├── dim_station.sql          # JOIN con stg_zones (desnormalización)
│       ├── dim_weather.sql
│       ├── fct_payments.sql         # incremental append
│       └── fct_rides.sql            # incremental append
├── snapshots/
│   └── dim_user.sql                 # SCD2 strategy=check, ES la dim_user de Gold
├── seeds/        (vacío, .gitkeep)
├── tests/        (vacío, .gitkeep)
└── analyses/     (vacío, .gitkeep)
```

## 5. Configuración del proyecto (`dbt_project.yml`)

El `dbt_project.yml` controla el **routing por carpeta** y los **hooks de warehouse**:

```yaml
on-run-start:
  - "ALTER WAREHOUSE {{ target.warehouse }} RESUME IF SUSPENDED"
  - "ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 300"

on-run-end:
  - "ALTER WAREHOUSE {{ target.warehouse }} SUSPEND"

models:
  PROYECTO_DE58:
    staging:
      +materialized: view
      +schema: STAGING
      +database: "{{ env_var('DBT_ENVIRONMENT') }}_SILVER_DB"

    marts:
      +materialized: table
      +schema: MARTS
      +database: "{{ env_var('DBT_ENVIRONMENT') }}_GOLD_DB"
```

**Por qué cada cosa:**

- **`on-run-start` / `on-run-end`**: el warehouse se enciende solo al ejecutar y se suspende al terminar → ahorro de créditos en Snowflake. El `STATEMENT_TIMEOUT` evita queries colgadas que dispararían el coste.
- **`env_var('DBT_ENVIRONMENT')`**: misma definición de modelos sirve para DEV y PRO. El entorno determina la database (`DEV_SILVER_DB` vs `PRO_SILVER_DB`, etc.) sin tocar código.
- **`+materialized` por carpeta**: staging como vistas (barato, siempre fresco), marts como tablas (rápido en lectura para BI).
- **`+schema` y `+database` por carpeta**: cada capa aterriza donde le corresponde. Sin esto, todo cae en la database de la conexión.

## 6. Macros de routing

Son **obligatorias** para que `+database` y `+schema` funcionen como se espera. Sin ellas, dbt concatena el nombre del usuario al schema (`dbt_de58_staging` en vez de `STAGING`).

### `macros/generate_schema_name.sql`

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim | upper }}
    {%- else -%}
        {{ default_schema | upper }}
    {%- endif -%}
{%- endmacro %}
```

Si el modelo declara `+schema: STAGING`, lo respeta tal cual (en mayúsculas) sin prefijar nada. Si no lo declara, usa el del target.

### `macros/generate_database_name.sql`

Mismo patrón para `+database`. Hace el routing explícito y fácil de debuggear.

## 7. Bronze — Sources

Declarados en `models/staging/raw/__sources.yml`. Una sola fuente lógica (`raw`) apuntando al schema `RAW` de la database `{{ env_var('DBT_ENVIRONMENT') }}_BRONZE_DB`.

**8 tablas** con todos sus tests `unique` / `not_null` / `accepted_values` / `relationships` declarados a nivel de source:

- `bikes` — 3 tipos de bicicleta (catálogo).
- `dates` — 365 fechas con atributos temporales (solo 2022).
- `memberships` — 280 membresías.
- `payments` — 5 000 pagos.
- `rides` — 5 000 viajes (tabla principal).
- `stations` — 50 estaciones.
- `users` — 400 usuarios.
- `weather` — 11 condiciones meteorológicas.

**Decisión sobre `members.user_id`**: el test `not_null` está **eliminado a propósito**, porque los usuarios `casual` no tienen membresía contratada y por tanto `membership_id` es NULL para ellos.

## 8. Silver — Staging

10 modelos `stg_*` en `*_SILVER_DB.STAGING`. Cada uno hace un trabajo concreto y está documentado en `__models.yml` con su descripción y tests.

### Transformaciones comunes

- **Renombrado completo a inglés** (`fecha_inicio` → `start_date`, `precio_neto_usd` → `net_price_usd`, etc.).
- **Casting explícito** a `DATE`, `TIMESTAMP`, `INTEGER`, `NUMBER`, `FLOAT`.
- **Strings descriptivos a UPPER()** para consistencia y joins fiables entre capas.
- **Booleanos reales**: campos `'sí'/'no'` se convierten con `CASE WHEN ... THEN TRUE ELSE FALSE END` para que sean reutilizables en comparaciones lógicas.
- **PII enmascarado**: en `stg_users` el `numero_tarjeta` se reduce a `card_last4` (últimos 4 dígitos).
- **`NINGUNA` → `NULL`** en `stg_rides.promo_code` (no es una promo real).
- **Precios** con `ROUND(... ::NUMBER, 2)` para evitar problemas de precisión.

### Materializaciones especiales

| Modelo            | Materialización          | Por qué                                                                                                                                                                            |
| ----------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `stg_users`       | **`table`**              | El snapshot `dim_user` (SCD2 strategy `check`) necesita una tabla estable de la que leer. Una view se recalcularía y rompería el chequeo de cambios.                              |
| `stg_memberships` | **`table`**              | Igual que `stg_users` — el snapshot también lee de aquí (JOIN para absorber `plan_type`, `monthly_price_usd`, `discount_pct` dentro de la dim de usuario).                          |
| `stg_rides`       | **`incremental` append** | Cada viaje es un evento nuevo e inmutable. Filtro `started_at > MAX(started_at)` en `is_incremental()`. En primera ejecución carga todo, en sucesivas solo lo nuevo.               |
| `stg_payments`    | **`incremental` append** | Mismo razonamiento. Filtro por `fecha_pago::DATE > MAX(payment_date)`. Hace `INNER JOIN` con `RAW.rides` para absorber las métricas económicas (`gross/promo/plan/total/net`).   |

### Modelos derivados (no existen en Bronze)

- **`stg_zones`**: catálogo de zonas geográficas construido con `SELECT DISTINCT` sobre `stations.zona + stations.cuadrante`. `zone_id` se genera con `ROW_NUMBER() OVER (ORDER BY zone_name)`.
- **`stg_promotions`**: catálogo de promociones construido con `SELECT DISTINCT` sobre `rides.codigo_promo + rides.descuento_promo_pct`. Se excluye `'NINGUNA'`.

### Decisión: separar métricas operacionales y económicas

`stg_rides` **no contiene métricas económicas** — todas (`precio_bruto_usd`, descuentos, `precio_neto_usd`) viven en `stg_payments`. Razón: cada hecho tiene un propósito analítico distinto y duplicarlas crearía riesgo de inconsistencia.

## 9. Gold — Marts y snapshot

### Dimensiones

| Dimensión       | Origen                       | Materialización | Notas                                                                |
| --------------- | ---------------------------- | --------------- | -------------------------------------------------------------------- |
| `dim_bike`      | `stg_bikes`                  | table           | Catálogo estático (3 filas).                                         |
| `dim_date`      | `stg_dates`                  | table           | 365 filas. **Solo cubre 2022** → ver nota en tests.                  |
| `dim_promotion` | `stg_promotions`             | table           | Catálogo de códigos promocionales.                                   |
| `dim_station`   | `stg_stations` + `stg_zones` | table           | JOIN para **desnormalizar** `zone_name` y `quadrant` (estrella pura). |
| `dim_weather`   | `stg_weather`                | table           | 11 filas.                                                            |
| **`dim_user`**  | snapshot                     | **SCD2 check**  | Ver detalle abajo.                                                   |

### Snapshot `dim_user` — SCD2

Vive en `snapshots/dim_user.sql` y **es la dimensión de Gold directamente**. No hay un `dim_user.sql` separado en `models/marts/` — el snapshot escribe en `*_GOLD_DB.marts.dim_user` y eso es lo que consumen `fct_rides` y `fct_payments`.

```sql
{% snapshot dim_user %}
{{ config(
    target_database = env_var('DBT_ENVIRONMENT') ~ '_GOLD_DB',
    target_schema   = 'marts',
    unique_key      = 'user_id',
    strategy        = 'check',
    check_cols      = [
        'membership_id', 'customer_email', 'customer_gender',
        'registration_city', 'customer_country', 'member_type',
        'card_last4', 'card_type',
        'plan_type', 'monthly_price_usd', 'discount_pct'
    ]
) }}

SELECT u.*, m.plan_type, m.monthly_price_usd, m.discount_pct
FROM {{ ref('stg_users') }} u
INNER JOIN {{ ref('stg_memberships') }} m ON u.membership_id = m.membership_id
{% endsnapshot %}
```

**Por qué `strategy='check'` y no `timestamp`**: las fuentes (`users`, `memberships`) no tienen una columna `updated_at` fiable que indique cuándo cambió cada fila. Con `check`, dbt compara las columnas listadas en `check_cols` contra la fila vigente y, si detecta cambios, cierra la fila anterior (`dbt_valid_to`) y abre una nueva.

**Qué columnas se chequean**: las susceptibles de cambiar en el tiempo (plan, email, ciudad, tarjeta, etc.). NO se chequean `customer_name`, `customer_age`, `age_segment`, `registration_date` — son fijas o derivadas.

### Hechos

| Hecho          | Materialización          | Filtro incremental                                       |
| -------------- | ------------------------ | -------------------------------------------------------- |
| `fct_rides`    | `incremental` + `append` | `started_at > (SELECT MAX(started_at) FROM {{ this }})`  |
| `fct_payments` | `incremental` + `append` | `payment_date > (SELECT MAX(payment_date) FROM {{ this }})` |

Ambos son **eventos inmutables**: una vez ocurridos, nunca se modifican, solo crecen. Por eso `append` (no `merge`) — es la estrategia más barata en créditos de Snowflake.

## 10. Tests y calidad de datos

Tests genéricos declarados tanto en `__sources.yml` (Bronze) como en `__models.yml` (Silver y Gold):

- **`unique` + `not_null`** en todas las PKs.
- **`relationships`** en todas las FKs.
- **`accepted_values`** en categóricas (`payment_method`, `payment_status`, `member_type`, `plan_type`, `quarter`, `trip_segment`, etc.).

### Tests con `severity: warn`

Dos tests están deliberadamente bajados a `warn` para que **no rompan el job** cuando se carguen datos de otros años:

- `stg_rides.start_date → stg_dates.date_id`
- `fct_rides.start_date → dim_date.date_id`

**Motivo**: el seed `dates.csv` solo cubre 2022 (365 filas). Cuando se prueba la ingesta incremental con datos de 2023+ (ver siguiente sección), esos viajes no tendrían fila correspondiente en `dim_date` y el test fallaría como `error`, parando el job de marts. Con `severity: warn` queda registrado en los logs pero el pipeline sigue.

### Truco de `relationships` cuando el destino es un snapshot

En `fct_rides.user_id` y `fct_payments.user_id` el test `relationships` apunta a `ref('stg_users')`, NO a `ref('dim_user')`:

```yaml
- name: user_id
  tests:
    - relationships:
        arguments:
          to: ref('stg_users')   # ← apunta a Silver, no a la dim
          field: user_id
```

**Por qué**: `dim_user` es un snapshot y vive en `snapshots/`, no en `models/`. Desde `models/marts/__model.yml`, `ref('dim_user')` no resuelve correctamente para `relationships` y el test peta. Apuntar a `stg_users` es funcionalmente equivalente (mismo dominio de `user_id`) y deja el test verde.

## 11. Prueba de ingesta incremental

Para validar end-to-end que el flujo Bronze → Silver → Gold funciona y que la lógica incremental hace lo suyo:

1. **`INSERT`** directo en `PRO_BRONZE_DB.RAW.rides` y `PRO_BRONZE_DB.RAW.payments` con `fecha_inicio` / `fecha_pago` **> 2022-12-31** (fuera del rango de `dates.csv`).
2. **`dbt build`** sobre staging y marts.

Lo que demuestra:

- ✅ El filtro `is_incremental()` en `stg_rides` y `stg_payments` solo trae lo nuevo.
- ✅ El `append` en Gold (`fct_rides`, `fct_payments`) hace crecer las tablas sin reconstruirlas.
- ✅ Los tests `relationships` contra `dim_date` saltan como **warn** (no error) — correcto, porque `dim_date` no cubre 2023+.
- ✅ El snapshot `dim_user` **NO se dispara** porque no hay cambios en `users` ni en `memberships`. Esto valida que `strategy='check'` solo escribe nuevas versiones cuando algo realmente cambia.

## 12. Comandos habituales

```bash
# Compilar y verificar el proyecto sin tocar la BD
dbt parse
dbt compile

# Reconstruir todo el grafo (modelos + tests + snapshots)
dbt build

# Solo capas
dbt run --select staging        # → SILVER_DB.STAGING
dbt run --select marts          # → GOLD_DB.MARTS

# Snapshot SCD2 (única forma de actualizar dim_user)
dbt snapshot

# Sources Bronze
dbt source freshness

# Tests
dbt test
dbt test --select stg_rides
dbt test --select fct_rides+    # fct_rides y todo lo aguas abajo

# Documentación
dbt docs generate
dbt docs serve
```

**Variable de entorno requerida:**

```bash
# Apunta a la database raíz del entorno (DEV o PRO)
export DBT_ENVIRONMENT=DEV     # → DEV_BRONZE_DB / DEV_SILVER_DB / DEV_GOLD_DB
export DBT_ENVIRONMENT=PRO     # → PRO_BRONZE_DB / PRO_SILVER_DB / PRO_GOLD_DB
