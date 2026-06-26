# 29. Summer Engine — el motor AI-native (CLI + MCP + skills)

[Summer Engine](https://www.summerengine.com/) es un **motor AI-native** y **reemplazo
drop-in de Godot 4** (tus proyectos/GDScript/plugins de Godot funcionan). Su capa de
agente es **MIT y open-source**: [`SummerEngine/summer-engine-agent`](https://github.com/SummerEngine/summer-engine-agent)
= **Summer CLI + Summer MCP server + agent skills**, con setup first-class para Claude
Code/Cursor/Codex. Su MCP corre **dentro del engine vivo** (`localhost:6550`) y cierra el
**lazo auto-correctivo** nativo: aplica el cambio → juega → lee el error REAL del runtime
→ se corrige. Eso es lo que los MCP file-level no dan.

> **Disciplina ponytail (G3):** Summer YA trae CLI, MCP (~44 tools) y ~27 agent skills.
> **No los reimplementes.** Esta skill aporta lo que Summer no tiene: la *doctrina RPG
> opinada* (refs 01-26) + el *dispatcher/enrutado* + el contrato lazy-not-negligent.
> Delega el músculo (escena, run, assets, debug) en Summer; tú pones el criterio.

## CLI (verificado en el README del repo)

```bash
npx -y summer-engine@latest doctor --json        # diagnostica Node/login/engine/MCP
npx -y summer-engine@latest setup claude-code --yes   # escribe la config MCP + instala skills (FUENTE DE VERDAD)
npx -y summer-engine@latest login                 # auth (planes/caps)
npx -y summer-engine@latest install               # instala el engine
npx -y summer-engine@latest create <template> <name>  # scaffold (p.ej. 3d-basic, empty)
npx -y summer-engine@latest run <name>            # arranca el proyecto
npx -y summer-engine@latest mcp                    # arranca el MCP server (stdio)
```

**No edites la config MCP a mano**: `summer setup claude-code` la escribe (en la config de
usuario de Claude Code), instala las skills y deja todo cableado.

## El MCP Summer — ~44 tools `summer_*` (transporte stdio, engine en :6550)

Nombres confirmados por README/búsquedas (lista representativa, no exhaustiva):
- **Escena/nodos:** `summer_get_scene_tree`, `summer_add_node`, `summer_set_prop`, `summer_inspect_node`, `summer_instantiate_scene`, `summer_batch`.
- **Runtime/lazo:** `summer_play`, `summer_stop`, `summer_is_running`, `summer_run_game`.
- **Diagnóstico (la clave anti-stuck):** `summer_get_console`, `summer_get_debugger_errors`, `summer_get_debugger_warnings`, `summer_get_diagnostics`, `summer_get_script_errors`.
- **Proyecto:** `summer_get_project_context`.
- **Assets (diferenciador):** `summer_search_assets`, `summer_import_asset`, `summer_import_from_url`, `summer_generate_image`, `summer_generate_3d`, `summer_generate_audio`, `summer_generate_video`.
- **Tarea/cloud:** `summer_start_game_task`, `summer_cloud_push` (gated por plan).

## Agent skills de Summer (≈27) — jerarquía proceso → disciplina → build

- **Proceso:** `brainstorm-game` → escribe **`.summer/GameSoul.md`** (mecánicas, dirección de arte, cut-list V1). **Es la fuente de verdad** que el resto de skills lee.
- **Disciplina:** `scene-composition`, `gdscript-patterns`, `art-direction`, `audio-direction`, `3d-lighting`, `vfx`.
- **Build:** `design-mechanic`, `design-npc`, `design-level`, `fps-controller`.
- **Otros:** `setup-multiplayer`/`host-authoritative-state`/`peer-to-peer-multiplayer`, `tune-performance`, `export-and-ship`, `skill-create`/`skill-improve`/`skill-test`.
- **Hooks:** `session-start` (orienta al agente) + `pre-commit doctor`.

**Cómo encaja con esta skill:** cuando Summer está presente, nuestro dispatcher (SKILL.md)
**enruta a la skill de Summer correcta** y antes aplica la decisión de arquitectura RPG
(refs 01-26). Lee/alimenta `.summer/GameSoul.md`, no mantengas estado paralelo.

## Templates y velocidad (onboarding, G5)

Summer arranca de un **template que ya corre** y cambia **un verbo a la vez**, pulsando
play tras cada paso → prototipo jugable en ~15-30 min ([fastest-way](https://www.summerengine.com/blog/fastest-way-to-make-a-game-with-ai),
[prompt-to-game](https://www.summerengine.com/prompt-to-game)). Categorías RPG/CRPG (quests,
combate, party, progression) confirmadas; `empty`/`3d-basic` verificados como templates del
CLI. (El "70+ templates" de marketing no lo pude verificar → **consulta la galería en
runtime**, no hardcodees una lista.)

## Planes
Gratis + $20/mes + $60/mes. Export a Steam/escritorio/móvil/web y Summer Cloud pueden estar
**gated por plan** → los workflows **avisan**, no prometen.

## Verificado vs inferido (honestidad)
- **Verificado** (README/búsquedas): el CLI de arriba, transporte **stdio**, engine en
  **`:6550`** con token `~/.summer/api-token`, ~44 tools `summer_*`, jerarquía de skills,
  `GameSoul.md`, lazo auto-correctivo, export multiplataforma.
- **No verificado** (docs en 403): el JSON exacto que escribe `summer setup`, el conteo "70+",
  y la lista literal completa de los 44 tools (las fuentes nombran ~25). Por eso **delegamos
  en `summer setup`** y no hardcodeamos la config.

## Fuentes
[summer-engine-agent (GitHub)](https://github.com/SummerEngine/summer-engine-agent) ·
[Summer MCP](https://www.summerengine.com/mcp) · [Summer CLI](https://www.summerengine.com/cli) ·
[docs](https://docs.summerengine.com/) · [Godot AI MCP (Summer)](https://www.summerengine.com/godot-ai-mcp) ·
[best-godot-mcp-server](https://www.summerengine.com/blog/best-godot-mcp-server) ·
[what-is-godot-mcp](https://www.summerengine.com/blog/what-is-godot-mcp) ·
[prompt-to-game](https://www.summerengine.com/prompt-to-game) ·
[fastest-way-to-make-a-game-with-ai](https://www.summerengine.com/blog/fastest-way-to-make-a-game-with-ai)
