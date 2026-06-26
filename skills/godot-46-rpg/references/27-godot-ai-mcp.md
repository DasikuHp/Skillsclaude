# 27. Godot AI (MCP) — Claude controla el editor en vivo

El repo trae un MCP **funcional**: [`Godot AI`](https://github.com/hi-godot/godot-ai)
(rama `main` de este repo = el **addon de Godot**; el servidor MCP en Python se
instala con `uv`). Conecta Claude Code/Codex/Cursor/… a un **editor Godot vivo**:
inspeccionar la escena, crear nodos, editar propiedades, correr el juego, sacar
capturas, correr tests y buscar en el proyecto — todo desde el prompt. Esto es el
salto de "Claude escribe a ciegas" a **"Claude ve y manipula el editor real"**.

## Instalar y conectar (una vez)

1. Copia `addons/godot_ai/` a `addons/` de tu proyecto y actívalo en
   **Project Settings → Plugins → Godot AI**.
2. En el dock **Godot AI**, elige tu cliente (p.ej. *Claude Code*) y pulsa **Configure**.
   - Para Claude Code ejecuta por ti: `claude mcp add --scope user --transport http godot-ai <url>`
     (escribe `{"godot-ai":{"type":"http","url":"<url>"}}` en `~/.claude.json`).
   - El servidor arranca solo (WebSocket/HTTP); la URL/puerto es dinámica → **usa el botón Configure**, no escribas el puerto a mano.
3. Requiere Godot 4.3+ (4.4+ recomendado) y [`uv`](https://docs.astral.sh/uv/).

> El `.mcp.json` de este plugin es solo un **ejemplo** del shape `http`; la fuente de
> verdad es el Configure del dock (la URL cambia por sesión).

## Las ~40 tools, por dominio (v2.7.6)

**Core (siempre on):** `editor_state` · `node_get_properties` · `scene_get_hierarchy` · `session_activate`.

| Dominio | Tools |
|---|---|
| scene | `scene_open` `scene_save` `scene_manage` |
| node | `node_create` `node_find` `node_set_property` `node_manage` |
| script | `script_create` `script_attach` `script_patch` `script_manage` |
| animation | `animation_create` `animation_manage` |
| material | `material_manage` |
| particle | `particle_manage` |
| camera | `camera_manage` |
| audio | `audio_manage` |
| ui / theme | `ui_manage` · `theme_manage` |
| signal | `signal_manage` |
| autoload | `autoload_manage` |
| input_map | `input_map_manage` |
| resource | `resource_manage` |
| filesystem | `filesystem_manage` |
| project | `project_manage` `project_run` |
| editor | `editor_manage` `editor_reload_plugin` `editor_screenshot` `logs_read` |
| testing | `test_manage` `test_run` |
| game | `game_manage` |
| api / batch | `api_manage` · `batch_execute` |

Puedes excluir dominios por `--exclude-domains` para reducir superficie.

## Qué tool usar por sistema de RPG (dispatcher → MCP)

| Sistema (ver reference) | Tools MCP que lo construyen en vivo |
|---|---|
| 1 Personaje + cámara | `node_create` (CharacterBody3D/SpringArm3D), `script_create`+`script_attach`, `camera_manage`, `node_set_property` |
| 2 Animación / IK | `animation_create`/`animation_manage`, `node_create` (AnimationTree/Skeleton3D) |
| 3 Combate | `node_create` (Area3D), `node_set_property` (layers/masks), `signal_manage` (area_entered→take_damage), `script_patch` |
| 4 Stats / 5 Inventario / 6 Diálogo | `resource_manage` (crear .tres), `script_create`, `ui_manage` |
| 7 IA + navegación | `node_create` (NavigationRegion3D/Agent3D), `node_set_property`, `script_attach` |
| 8 Guardado | `script_create`, `filesystem_manage` |
| 9 UI / HUD | `ui_manage`, `theme_manage`, `signal_manage`, `node_create` (Control) |
| 10 Mundo / arquitectura | `scene_open`/`scene_save`/`scene_manage`, `autoload_manage`, `project_manage` |
| 11 Shaders | `material_manage` |
| 12 Importación | `filesystem_manage`, `resource_manage` |
| 13/14 Errores y depuración | `logs_read`, `editor_screenshot`, `test_run`, `game_manage` |
| 19 Audio | `audio_manage` | | 20 Input | `input_map_manage` | | 25 VFX | `particle_manage` |
| 16 Verificación | `test_run`/`test_manage`, `project_run`, `game_manage`, `logs_read` |

## Cuándo MCP vs scripts vs escribir archivos (la simbiosis)

- **Editor vivo disponible → usa el MCP.** Ve el estado real (jerarquía, propiedades,
  errores), modifica in situ y **valida visualmente** (`editor_screenshot`, `project_run`,
  `logs_read`). Es lo más "caro y útil": cierra el lazo viendo el juego, no a ciegas.
- **Sin editor (CI, headless, agente solo) → usa `scripts/`** (`verify_loop.sh`,
  `validate_all.gd`): el lazo edito→compruebo→corrijo por CLI.
- **Autoría de texto** (`.gd`/`.tres`/`.tscn`) → `script_create`/`script_patch`/`resource_manage`
  del MCP si hay editor; si no, escribe el archivo y valida con los scripts.

**Regla:** si el MCP está conectado, prefiérelo para tocar la escena (no edites el
`.tscn` a mano: deja que `node_*`/`scene_*` lo hagan bien y registren `uid://`). El
veredicto ponytail sigue mandando: no crees nodos que el motor ya da.

> Fuente del addon: este repo (rama `main`) · upstream: https://github.com/hi-godot/godot-ai
