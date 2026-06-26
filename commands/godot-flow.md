---
description: Ejecuta un flujo premium que orquesta varias tools del MCP en una acción de alto valor
argument-hint: <F1..F8 | rpg_scaffold|enemy_combat_wire|hud_bind|nav_bake_patrol|material_fx_pack|dungeon_gen|playtest_capture|verify_and_fix>
allowed-tools: Read, Bash, Glob, Edit, Write
---

Ejecuta el flujo premium "$1" descrito en `skills/godot-46-rpg/references/28-premium-flows.md`.

1. LEE `references/28-premium-flows.md` y localiza el flujo "$1": su objetivo, las tools MCP que encadena y el veredicto.
2. Comprueba si el MCP Godot AI está conectado (un editor vivo). Si sí, ejecuta las tools en orden **verificando entre pasos** (`node_find` antes de `node_create` para idempotencia; `logs_read`/`editor_screenshot` para confirmar). Si no hay editor, degrada al equivalente en `scripts/` cuando exista (F1→new_project.sh, F7/F8→verify_loop.sh).
3. No recortes validación en combate (layers/máscaras) ni en save (rutas).
4. Termina con un veredicto: qué tools compuso, qué NO se construyó a mano, y `net` de pasos manuales ahorrados.
