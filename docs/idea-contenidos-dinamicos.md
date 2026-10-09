# Idea: contenidos dinámicos (carta, datos del local, cambios del día)

Estado: **idea, sin construir.** Semilla de datos en [`data/menu/`](../data/menu/README.md).

## Problema
La información de Flames está escrita a mano dentro del `systemMessage` del agente (`# Flames facts`). Si cambia la carta, el horario o hay un plato agotado, hay que editar el prompt en n8n. El restaurante tiene que poder hacerlo por su cuenta, cada día o cada semana.

## Principios
1. **Una sola fuente de verdad: Postgres** (`menu_items`, `drinks`, `venue_facts`). El agente solo lee de ahí.
2. **Datos estructurados en tabla, no en RAG.** En la carta, los alérgenos tienen que ser exactos, y la carta completa cabe en el contexto (unos pocos miles de tokens). El RAG en Qdrant se deja para texto largo sin estructura, si algún día lo hay: historia del chef, fichas de vino, menús de eventos.
3. **Dos puertas de entrada, según el tipo de cambio.** Ninguna escribe directamente en vivo sin pasar validación.

| Cambio | Quién | Vía |
|---|---|---|
| Carta nueva, cambios semanales, precios, alérgenos | Encargado u oficina | **Google Sheet** → n8n sincroniza → valida (tipos, vocabulario de alérgenos, precios > 0) → Postgres. Si una fila no pasa la validación, se rechaza y se avisa al grupo del equipo; la carta en vivo no se toca. Cada sincronización guarda versión. |
| Operativa del día: "hoy no hay lubina", "especial: X" | Jefe de cocina | **Telegram**, con el bot del equipo del HITL → la IA lo convierte en un cambio concreto → botón **Confirmar** → Postgres, con autor y hora. **Los alérgenos no se cambian por Telegram**, solo por el Sheet. |

4. **A largo plazo, el POS/TPV** pasa a ser la fuente de platos y precios, y el Sheet queda para lo que el POS no tiene (alérgenos, textos, platos estrella).

## Cómo lo lee el agente
- Datos del local (`venue_facts`): se inyectan siempre en el prompt, porque son pocos.
- Carta: con una tool `get_menu(service, diet, exclude_allergens)` o inyectando la carta del servicio en curso. Hay que decidirlo al construirlo según el tamaño; con los 77 platos actuales, la inyección es viable.
- Solo se lee lo que está `available = yes` y dentro de `available_from/to`.

## Fases
1. Tablas + sincronización desde el Sheet. El agente lee de la BD y `# Flames facts` sale del prompt.
2. Cambios del día por Telegram, reutilizando el bot y el grupo del equipo del HITL.
3. RAG, solo si aparece contenido largo que lo justifique.
