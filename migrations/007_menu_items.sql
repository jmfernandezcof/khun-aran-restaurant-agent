-- 007_menu_items.sql
-- Carta de Flames en BD: fase 1 de docs/idea-contenidos-dinamicos.md.
-- La lee la tool find_dishes (Khun Aran-Tool-FindDishes), que filtra por alérgenos, dieta
-- y servicio con SQL. Así el filtrado de alérgenos es exacto y no depende del modelo.
-- Motivo: en las pruebas de la v2/v2b el agente recomendó dos veces platos con frutos
-- secos (Caprese con pesto, ceviche con piñones) filtrando a mano sobre la carta del prompt.
--
-- Sin PII. La fuente es data/menu/{food,drinks}.csv; la carga es
-- data/menu/seed_menu_items.sql, que genera scripts/build_menu.py y es idempotente
-- (reemplaza la carta completa en una transacción). Más adelante la cargará la
-- sincronización desde el Google Sheet.
--
-- Se ejecuta como n8n, pero la tabla debe pertenecer a flames_kohsamui: es el usuario de la
-- credencial Postgres de n8n y dueño del resto de tablas. Si no, falla con "permission denied".
--
-- ROLLBACK:
--   DROP TABLE IF EXISTS menu_items;

CREATE TABLE IF NOT EXISTS menu_items (
    id             TEXT        PRIMARY KEY CHECK (id ~ '^[FB][0-9]{3}$'),  -- F = comida, B = bebida
    kind           TEXT        NOT NULL CHECK (kind IN ('food', 'drink')),
    section        TEXT        NOT NULL,
    name           TEXT        NOT NULL,
    description    TEXT        NOT NULL DEFAULT '',
    price_thb      INTEGER     NOT NULL CHECK (price_thb >= 0),           -- 0 = incluido (salsas del Prime Cut)
    unit           TEXT,                                                  -- bebidas: glass, bottle, cup
    service        TEXT[]      NOT NULL                                    -- todo el día = los tres
                       CHECK (cardinality(service) > 0
                              AND service <@ ARRAY['lunch', 'afternoon', 'dinner']::TEXT[]),
    allergens      TEXT[]      NOT NULL DEFAULT '{}'
                       CHECK (allergens <@ ARRAY['gluten', 'crustaceans', 'eggs', 'fish', 'peanuts', 'soy',
                              'milk', 'tree_nuts', 'celery', 'mustard', 'sesame', 'sulphites', 'lupin',
                              'molluscs']::TEXT[]),
    diet           TEXT[]      NOT NULL DEFAULT '{}'
                       CHECK (diet <@ ARRAY['vegan', 'vegetarian', 'gluten_free', 'gluten_free_on_request']::TEXT[]),
    spicy          SMALLINT    NOT NULL DEFAULT 0 CHECK (spicy BETWEEN 0 AND 3),
    contains       TEXT[]      NOT NULL DEFAULT '{}'
                       CHECK (contains <@ ARRAY['pork', 'beef', 'lamb', 'alcohol']::TEXT[]),
    available      BOOLEAN     NOT NULL DEFAULT true,
    available_from DATE,
    available_to   DATE,
    notes          TEXT        NOT NULL DEFAULT '',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (available_to IS NULL OR available_from IS NULL OR available_from <= available_to)
);

-- Mismo propietario que el resto de tablas (usuario de la credencial de n8n).
ALTER TABLE menu_items OWNER TO flames_kohsamui;
