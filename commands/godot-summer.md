---
description: Conecta Summer Engine (CLI+MCP) y arranca/contextualiza un proyecto RPG con su lazo vivo
argument-hint: "[setup | new <template> <name> | context <dir>]"
allowed-tools: Bash, Read
---

Integra **Summer Engine** (motor AI-native, MCP en editor vivo). Ver `skills/godot-46-rpg/references/29-summer-engine.md` y `30-mcp-routing-loop.md`. Sub-acción en `$1`:

**setup** — cablea Summer para Claude Code (fuente de verdad; no edites config a mano):
!npx -y summer-engine@latest doctor --json 2>&1 | tail -20

Si `doctor` reporta fallos o Summer no está configurado, guía: `npx -y summer-engine@latest setup claude-code --yes` (escribe la config MCP + instala las ~27 skills), luego `login` e `install`. Confirma con `claude mcp list`.

**new `<template> <name>`** — scaffold con Summer + contexto de la skill:
1. `npx -y summer-engine@latest create $2 $3`
2. `bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/godot-46-rpg/scripts/add_context.sh" $3 summer` (inyecta CLAUDE.md + .claude/ + lazo, sin duplicar el scaffold de Summer)
3. Arranca: `npx -y summer-engine@latest run $3`

**context `<dir>`** — añade el lazo de la skill a un proyecto existente:
!bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/godot-46-rpg/scripts/add_context.sh" "$2" summer

Después: usa el MCP de Summer (`summer_get_scene_tree`/`summer_add_node`/`summer_set_prop`/`summer_play`/`summer_get_diagnostics`) y el lazo auto-correctivo con convergencia (ref 30). Sin Summer, degrada a `/godot-verify` headless. Disciplina: **un verbo, un play, un vistazo**.
