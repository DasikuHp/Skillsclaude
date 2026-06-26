---
description: Añade un sistema de RPG leyendo su guía y copiando su ejemplo (respeta el veredicto ponytail)
argument-hint: "<sistema> (personaje|animacion|combate|stats|inventario|dialogo|ia|guardado|ui|mundo|shaders|audio|input|vfx|...)"
allowed-tools: Read, Glob, Bash, Edit, Write
---

Vas a añadir el sistema "$1" al proyecto Godot actual.

1. Abre `skills/godot-46-rpg/SKILL.md` y localiza la fila del dispatcher que corresponde a "$1".
2. LEE su `reference` (`skills/godot-46-rpg/references/NN-*.md`) — el enfoque nativo, pitfalls y el **Veredicto ponytail**.
3. Si hay un editor Godot vivo con el MCP conectado, prefiere construirlo con las tools del MCP (`node_create`, `script_attach`, `signal_manage`, `resource_manage`…) en vez de editar `.tscn` a mano (ver `references/27-godot-ai-mcp.md`). Si no, copia los archivos de `skills/godot-46-rpg/assets/examples/NN-*/` y adáptalos.
4. Respeta el veredicto: NO construyas lo que el motor ya da (no managers/EventBus si una señal/nodo basta).
5. Cierra el lazo: `bash verify_loop.sh` (o el MCP `test_run`/`project_run`).
