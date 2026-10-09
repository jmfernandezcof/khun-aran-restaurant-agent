-- Used by node "Load Menu" in TNMHHaKWEoO0rLhf: one row, column menu_text, injected into the agent prompt.
-- Live from menu_items; only what the agent should always know. Details come from find_dishes.
WITH t AS (SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date AS d),
live AS (
  SELECT m.* FROM menu_items m, t
  WHERE m.available AND (m.available_to IS NULL OR m.available_to >= t.d)
),
secs AS (
  SELECT section, min(id) AS o FROM live WHERE kind = 'food' GROUP BY section
),
drinks AS (
  SELECT section,
         CASE WHEN section IN ('Luxury Sparkling', 'Wine by the Glass') THEN string_agg(name, '; ' ORDER BY id)
              ELSE count(*) || ' items' END AS names,
         min(id) AS o
  FROM live WHERE kind = 'drink' GROUP BY section
)
SELECT concat_ws(E'\n',
  '# Menu summary (live from the kitchen''s menu; prices in THB plus 10% service and applicable taxes)',
  'Full menu for guests: https://demo-talay.nomadprompters.es/carta.html',
  'Food sections: ' || (SELECT string_agg(section, ' · ' ORDER BY o) FROM secs) || '.',
  'Signature dishes: ' || (SELECT string_agg(name, '; ' ORDER BY id) FROM live
                           WHERE kind = 'food' AND notes LIKE 'Signature%') || '.',
  'Time-bound items: ' || COALESCE((SELECT string_agg(g, '; ') FROM (
        SELECT section || ' (' || COALESCE(available_from::text, 'now') || ' to ' || COALESCE(available_to::text, 'further notice')
               || '): ' || string_agg(name, ', ' ORDER BY id) AS g
        FROM live WHERE available_from IS NOT NULL OR available_to IS NOT NULL
        GROUP BY section, available_from, available_to) x), 'none') || '.',
  'Not available today: ' || COALESCE((SELECT string_agg(name, ', ' ORDER BY id) FROM menu_items WHERE NOT available), 'nothing') || '.',
  'Drinks — ' || (SELECT string_agg(section || ': ' || names, ' | ' ORDER BY o) FROM drinks) || '.'
) AS menu_text;
