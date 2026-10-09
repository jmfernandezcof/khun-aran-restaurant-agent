-- Used by Khun Aran-Tool-FindDishes (node "Find Dishes").
-- $1 kind ('' | food | drink), $2 exclude_allergens (csv), $3 diet ('' | vegan | vegetarian | gluten_free),
-- $4 service ('' | lunch | afternoon | dinner), $5 date (YYYY-MM-DD, '' = today Bangkok), $6 exclude_contains (csv),
-- $7 dish ('' = search mode; otherwise lookup mode: the named item(s), unfiltered, with the conflicts computed here)
-- $8 text ('' = any; search mode only: words matched against name, description and section, all must match)
WITH p AS (
  SELECT NULLIF($1::text, '') AS kind,
         array_remove(string_to_array(regexp_replace(lower($2::text), '\s', '', 'g'), ','), '') AS no_alg,
         NULLIF(lower($3::text), '') AS diet,
         NULLIF(lower($4::text), '') AS service,
         COALESCE(NULLIF($5::text, '')::date, (now() AT TIME ZONE 'Asia/Bangkok')::date) AS d,
         array_remove(string_to_array(regexp_replace(lower($6::text), '\s', '', 'g'), ','), '') AS no_contains,
         NULLIF(trim($7::text), '') AS dish,
         array_remove(string_to_array(lower(trim($8::text)), ' '), '') AS words
)
SELECT m.kind, m.section, m.name, m.description, m.unit, m.service,
       m.allergens, m.diet, m.spicy, m.contains, m.notes, m.available_from, m.available_to,
       ARRAY(SELECT unnest(m.allergens) INTERSECT SELECT unnest(p.no_alg)) AS allergen_conflicts,
       ARRAY(SELECT unnest(m.contains) INTERSECT SELECT unnest(p.no_contains)) AS contains_conflicts,
       (p.diet IS NULL
        OR (p.diet = 'vegan' AND m.diet @> '{vegan}')
        OR (p.diet = 'vegetarian' AND m.diet && '{vegetarian,vegan}')
        OR (p.diet = 'gluten_free' AND m.diet && '{gluten_free,gluten_free_on_request}')) AS diet_ok,
       p.dish IS NOT NULL AS lookup
FROM menu_items m, p
WHERE m.available
  AND (p.kind IS NULL OR m.kind = p.kind)
  AND CASE WHEN p.dish IS NOT NULL THEN
        m.name ILIKE '%' || p.dish || '%'
      ELSE
        NOT (m.allergens && p.no_alg)
        AND NOT (m.contains && p.no_contains)
        AND (p.diet IS NULL
             OR (p.diet = 'vegan' AND m.diet @> '{vegan}')
             OR (p.diet = 'vegetarian' AND m.diet && '{vegetarian,vegan}')
             OR (p.diet = 'gluten_free' AND m.diet && '{gluten_free,gluten_free_on_request}'))
        AND (p.service IS NULL OR m.service @> ARRAY[p.service])
        AND (m.available_from IS NULL OR m.available_from <= p.d)
        AND (m.available_to IS NULL OR m.available_to >= p.d)
        AND NOT EXISTS (SELECT 1 FROM unnest(p.words) w
                        WHERE lower(m.name || ' ' || m.description || ' ' || m.section) NOT LIKE '%' || w || '%')
      END
ORDER BY m.id;
