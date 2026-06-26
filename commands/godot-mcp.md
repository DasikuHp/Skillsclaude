---
description: Conecta/diagnostica el MCP Godot AI (editor vivo) para este cliente
allowed-tools: Bash, Read
---

Ayuda a conectar el MCP **Godot AI** (ver `skills/godot-46-rpg/references/27-godot-ai-mcp.md`).

1. Comprueba estado en Claude Code: `!claude mcp list`
2. Si `godot-ai` no aparece: el modo recomendado es abrir el proyecto en Godot, activar el addon **Godot AI** (Project Settings → Plugins) y pulsar **Configure → Claude Code** en el dock (auto-registra el transporte `http` con la URL dinámica). NO escribas el puerto a mano.
3. Verifica `uv` instalado (`!uv --version`) y Godot 4.3+.
4. Cuando esté conectado, prefiere las tools del MCP para tocar la escena (`node_*`, `scene_*`, `script_*`, `signal_manage`, `resource_manage`) y verifica viendo (`project_run`, `editor_screenshot`, `logs_read`).
