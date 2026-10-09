# Carta de Flames (demo)

Carta **adaptada y ficticia** para la demo de Khun Aran (*Flames, Talay Cliff Resort*). Se basa en la estructura y el estilo de la carta real de Flames en el InterContinental Koh Samui (agosto de 2026; el hotel está cerrado por reformas hasta el verano de 2027). Nombres, descripciones, precios y marcas de vino están cambiados: **no es la carta real de nadie**.

Estos CSV son la semilla del futuro Google Sheet → Postgres (ver [`docs/idea-contenidos-dinamicos.md`](../../docs/idea-contenidos-dinamicos.md)). Todavía no los usa ningún workflow.

## Ficheros

| Fichero | Contenido |
|---|---|
| `food.csv` | 77 platos, salsas y guarniciones |
| `drinks.csv` | 53 bebidas |
| `set_menus.csv` | Menú de 3 platos para huéspedes con media pensión, pensión completa o todo incluido |
| `venue.csv` | Datos del local en pares `key,value`: horario, zonas, espectáculo de fuego, política de alérgenos, código de vestimenta… |

## Columnas

- `id`: `F###` (comida) o `B###` (bebida). Estable: no se reutiliza al borrar filas.
- `service`: `lunch` (11:30–14:30), `afternoon` (14:30–17:30), `dinner` (18:00–23:00) o `all_day`. Si son varios, van separados por `|`.
- `allergens`: los 14 de declaración obligatoria (UE / Tailandia), separados por `|`. Valores posibles: `gluten, crustaceans, eggs, fish, peanuts, soy, milk, tree_nuts, celery, mustard, sesame, sulphites, lupin, molluscs`. Vacío significa que no contiene ninguno de ellos.
- `diet`: `vegan`, `vegetarian`, `gluten_free` o `gluten_free_on_request`.
- `spicy`: de 0 a 3.
- `contains`: lo que los huéspedes suelen preguntar y no figura entre los alérgenos: `pork`, `beef`, `lamb`, `alcohol`.
- `available` (`yes`/`no`), `available_from` y `available_to` (ISO): sirven para ofertas temporales, como el pop-up de tacos de octubre de 2026, y para platos agotados.
- `notes`: `Signature…` marca los platos estrella; aquí van también los extras y las alternativas (p. ej. "Vegan with coconut sorbet").

## Advertencias

- **Los alérgenos los he deducido de los ingredientes de cada descripción, haciendo de jefe de cocina.** Aunque es una demo, el agente los tratará como ciertos. Antes de usarlos con huéspedes reales, cocina tiene que validarlos plato a plato, y cada cambio de receta obliga a revisarlos.
- Incluso con esta tabla, el agente debe mantener la regla de avisar al equipo ante una alergia grave (HITL) y nunca garantizar que un plato está libre de un alérgeno.
- Los datos de `venue.csv` sustituyen a los de `# Flames facts` del prompt. En particular:
  - el horario real incluye almuerzo, y las reservas por chat siguen siendo solo para cenas;
  - la parrilla es de carbón;
  - la cocina es mediterránea y europea con toques thai, no thai-fusión.

  Hasta que se migren, el prompt sigue diciendo lo contrario.
