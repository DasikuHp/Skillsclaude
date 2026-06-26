# godot-46-rpg — Claude Code plugin para crear RPGs 3D en Godot 4.6

Plugin de Claude Code que convierte a Claude en un **creador de videojuegos Godot 4.6
operativo**: una skill con dispatcher + 26 sistemas, un **lazo de verificación headless**,
**hooks** que validan cada `.gd`/`.tscn` al editarlo y devuelven el error al modelo,
**comandos** y **subagentes**, y **flujos premium** que orquestan el MCP **Godot AI**
(editor vivo). Filosofía [ponytail](https://github.com/DietrichGebert/ponytail): *el mejor
código es el que no escribes* — reusar nodos/`Resource` nativos antes que arquitectura
propia (con su límite: **lazy, no negligente**).

## Estructura (layout de plugin)

```
.claude-plugin/plugin.json     # manifiesto del plugin
.mcp.json                      # ejemplo http del MCP Godot AI (la URL la fija el dock)
settings.json                  # registro de hooks (${CLAUDE_PLUGIN_ROOT}/hooks/…)
hooks/                         # validate_gd_post_edit.sh · session_start.sh · errors.json
commands/                      # /godot-new /godot-add /godot-verify /godot-flow /godot-mcp
agents/                        # godot-reviewer · godot-scripter
output-styles/                 # ponytail-terse
skills/godot-46-rpg/           # la SKILL (entry point + contenido)
  ├── SKILL.md                 # dispatcher tema→archivo + workflow + lazo + MCP
  ├── references/              # 00-principios, 01..26 sistemas, 27-MCP, 28-flujos premium, 99-filosofía, research/
  ├── scripts/                 # new_project.sh + verify_loop/validate_all/validate_gd/smoke_test
  ├── assets/                  # plantillas (project.godot/.gitignore/.gitattributes) + examples/ (130+)
  └── skillgodot4.6.md         # respaldo full-text
```

## Simbiosis con Claude (lo que lo hace "creador real")

- **Lazo automático**: el hook `PostToolUse` valida el `.gd`/`.tscn` recién editado y, si
  Godot lo rechaza, devuelve `archivo:línea` (+ fix de `hooks/errors.json`) al modelo. El
  lazo edito→compruebo→corrijo deja de depender de que Claude se acuerde. Decide por texto
  (`SCRIPT ERROR`/`Parse Error`), nunca por el exit code poco fiable de `--check-only`;
  no-op seguro sin `godot`. Desactiva con `GODOT_HOOK_DISABLE=1`.
- **SessionStart**: warm-up de imports + orientación a `SKILL.md`.
- **Comandos**: `/godot-new <n> <target>` (scaffold jugable), `/godot-add <sistema>`,
  `/godot-verify`, `/godot-flow <Fn>` (flujos premium), `/godot-mcp` (conectar el editor).
- **Subagentes**: `godot-reviewer` (auditor ponytail read-only), `godot-scripter` (GDScript tipado).
- **MCP Godot AI** (editor vivo): ~40 tools en 22 dominios; Claude inspecciona la escena,
  crea nodos, corre el juego y saca capturas. Ver `skills/godot-46-rpg/references/27-godot-ai-mcp.md`.
- **Flujos premium** (`references/28-premium-flows.md`): encadenan el MCP en acciones caras y
  útiles — cablear un enemigo de combate, bindear el HUD, playtest con capturas, lazo auto-fix.
- **Proyectos autosimbióticos**: `new_project.sh` deja en cada proyecto un `CLAUDE.md` + `.claude/`
  (hooks + settings), así el lazo viaja con el juego.

## Instalar

```bash
claude plugin install /ruta/a/este/repo        # o la URL del repo en GitHub
claude plugin validate /ruta/a/este/repo       # comprobar el manifiesto
```
Uso directo (sin instalar): apunta tu agente a `skills/godot-46-rpg/SKILL.md`.

El MCP **Godot AI** (rama `main` de este repo = addon) se conecta aparte: copia
`addons/godot_ai/` a tu proyecto, actívalo y pulsa **Configure** en su dock.

## Arranque rápido

```bash
bash skills/godot-46-rpg/scripts/new_project.sh MiRPG desktop
cd MiRPG && bash verify_loop.sh        # requiere 'godot' 4.6 en PATH
```

## Notas

- Investigación con búsqueda web real (junio 2026): docs 4.6, GitHub, foro, r/godot, GDQuest,
  Asset Store, StackOverflow — **747 fuentes reales** citadas en `references/research/`.
- El binario `godot` 4.6 debe estar en PATH para el lazo end-to-end; sin él, los hooks/scripts hacen no-op seguro.
- Complementa, no sustituye, la documentación oficial de Godot.
