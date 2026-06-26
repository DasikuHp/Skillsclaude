---
name: godot-46-rpg
description: "Construye un RPG 3D open-source en Godot 4.6 (GDScript y C#/.NET 8) con filosofía ponytail: reusar nodos y Resources nativos antes que escribir arquitectura propia. Cubre personaje 3D y cámara en tercera persona, AnimationTree/IK, combate, stats, inventario, diálogo, quests, IA enemiga con NavigationAgent3D, guardado, HUD y menús, shaders, importación de assets, audio, input, localización, multiplayer, y auto-verificación headless por CLI. Úsala cuando el usuario hable de RPG en Godot, Godot 4.6, GDScript vs C#, o cualquiera de esos sistemas, o cuando pida crear/depurar un juego en Godot."
license: MIT
---

# Godot 4.6 — Creador de RPG 3D (ponytail)

Esta skill convierte el trabajo de "hacer un RPG en Godot 4.6" en pasos
accionables. **No leas todo de golpe**: usa el *dispatcher* para saltar a la
sección que necesitas. El detalle por sistema vive en `references/`, el código
copiable en `assets/examples/`, las fuentes en `references/research/`, y las
herramientas ejecutables en `scripts/`.

## La escalera ponytail (aplícala ANTES de escribir una línea)

El motor ya trae casi todo lo de un RPG; la mayoría del "código de gameplay" es
plomería que Godot resuelve con un nodo o un Resource. Antes de codear, baja la
escalera y **detente en el primer peldaño que resuelve**:

1. **¿Hace falta que exista?** Un RPG no necesita un `GameManager` el día 1 (YAGNI).
2. **¿Lo da un nodo de Godot?** `CharacterBody3D`, `NavigationAgent3D`, `AnimationTree`, `AudioStreamPlayer3D`, `GPUParticles3D`. No reescribas su lógica.
3. **¿Lo da un Resource?** Items, stats, recetas, diálogos, loot = `Resource` con `@export`. No clases de datos a mano ni JSON parseado a mano.
4. **¿Lo dan señales + grupos + autoloads?** Es el bus de eventos nativo. No escribas tu propio EventBus si una señal basta.
5. **¿Es una línea?** `velocity = dir * speed; move_and_slide()` ya es tu locomoción. No la envuelvas en un framework.
6. **Solo entonces**: escribe el mínimo que funciona, **tipado**.

## Lazy, no negligente (el límite)

La pereza aplica SOLO al código que no aporta. **NUNCA recortes**: validación en
límites de confianza (saves, red, input externo), manejo de errores (no pierdas
progreso), seguridad (no cargues `.tres`/`.gd` arbitrarios de un save), ni
accesibilidad (remapeo de input, subtítulos). Si un atajo tiene **techo conocido**,
nómbralo en un comentario con el upgrade:

```gdscript
# TECHO: escaneo O(n) por frame, ok hasta ~200 items.
# UPGRADE: indexar por id en un Dictionary si crece.
```

**Veredicto de cada sistema** (formato): *qué NO construir · qué reusar · rung donde
se detuvo la escalera · net propio (lo que sí escribes)*. El grueso lo da el motor.

## Qué trae 4.6 que cambia tus decisiones

- **Jolt** es el motor de física 3D por defecto en proyectos nuevos. No instales plugins de física.
- **`IKModifier3D`** + suite (`TwoBoneIK3D`, `FABRIK3D`, `CCDIK3D`…): IK en el núcleo. Bórralo de tu TODO.
- **Diccionarios y arrays tipados** (`Dictionary[K,V]`, `Array[T]`): úsalos para inventarios/tablas.
- **`@abstract`** (desde 4.5) para bases de estados/items.
- **Tipar = velocidad**: en 4.6 el GDScript tipado es notablemente más rápido. Tipa todo.
- Renderers **Forward+ / Mobile / Compatibility**. **Web = Compatibility y NO soporta C#** → si apuntas a web, GDScript.
- `.tscn` 4.6 ya **no escribe `load_steps`**; los recursos usan **`uid://` + archivos `.uid`** (desde 4.4). No edites esos números a mano.

## GDScript vs C#

GDScript por defecto (iteración instantánea, menos andamiaje = ponytail). C# solo
si lo justificas (simulación CPU pesada, libs .NET); **.NET 8**; web sin C#. No
partas un mismo sistema entre ambos: el cruce tiene coste de marshalling.

## Dispatcher — salta a lo que necesitas

Lee SOLO la fila que aplica (progressive disclosure). `references/NN` = guía;
`examples/NN` = código copiable; `rNN` = notas + fuentes reales.

| Necesito… | Guía | Código | Fuentes |
|---|---|---|---|
| Personaje + cámara 3ª persona | [`01`](references/01-character-controller-camera.md) | [`examples/01`](assets/examples/01-character-controller-camera/) | [`r02`](references/research/02-character-controller-camera.md) |
| Animación / AnimationTree / IK | [`02`](references/02-animation-ik.md) | [`examples/02`](assets/examples/02-animation-ik/) | [`r03`](references/research/03-animation-ik.md) |
| Combate y daño | [`03`](references/03-combat-damage.md) | [`examples/03`](assets/examples/03-combat-damage/) | [`r04`](references/research/04-combat-damage.md) |
| Stats / niveles / XP | [`04`](references/04-stats-progression.md) | [`examples/04`](assets/examples/04-stats-progression/) | [`r05`](references/research/05-stats-progression.md) |
| Inventario / items / equipo | [`05`](references/05-inventory-equipment.md) | [`examples/05`](assets/examples/05-inventory-equipment/) | [`r06`](references/research/06-inventory-equipment.md) |
| Diálogo y quests | [`06`](references/06-dialogue-quests.md) | [`examples/06`](assets/examples/06-dialogue-quests/) | [`r07`](references/research/07-dialogue-quests.md) |
| IA enemiga + navegación | [`07`](references/07-enemy-ai-navigation.md) | [`examples/07`](assets/examples/07-enemy-ai-navigation/) | [`r08`](references/research/08-enemy-ai-navigation.md) |
| Guardado / persistencia | [`08`](references/08-save-persistence.md) | [`examples/08`](assets/examples/08-save-persistence/) | [`r09`](references/research/09-save-persistence.md) |
| UI / HUD / menús | [`09`](references/09-ui-hud-menus.md) | [`examples/09`](assets/examples/09-ui-hud-menus/) | [`r10`](references/research/10-ui-hud-menus.md) |
| Mundo / niveles / arquitectura | [`10`](references/10-world-architecture.md) | [`examples/10`](assets/examples/10-world-architecture/) | [`r11`](references/research/11-world-architecture.md) |
| Shaders (hit-flash, dissolve…) | [`11`](references/11-shaders-rpg.md) | [`examples/11`](assets/examples/11-shaders-rpg/) | [`r12`](references/research/12-shaders-rpg.md) |
| Importar modelos/escenas (glTF) | [`12`](references/12-asset-import.md) | [`examples/12`](assets/examples/12-asset-import/) | [`r13`](references/research/13-asset-import.md) |
| Un error cripto / me atasco | [`13`](references/13-common-errors-unstuck.md) | [`examples/13`](assets/examples/13-common-errors-unstuck/) | [`r14`](references/research/14-common-errors-unstuck.md) |
| Depurar / medir rendimiento | [`14`](references/14-debugging-profiling.md) | [`examples/14`](assets/examples/14-debugging-profiling/) | [`r15`](references/research/15-debugging-profiling.md) |
| C# .NET 8 a fondo | [`15`](references/15-csharp-dotnet8.md) | [`examples/15`](assets/examples/15-csharp-dotnet8/) | [`r16`](references/research/16-csharp-dotnet8.md) |
| Verificar sin abrir el editor | [`16`](references/16-headless-cli-testing.md) | [`examples/16`](assets/examples/16-headless-cli-testing/) | [`r18`](references/research/18-headless-cli-testing.md) |
| .tscn/.tres/project.godot/uid | [`17`](references/17-scene-resource-formats.md) | [`examples/17`](assets/examples/17-scene-resource-formats/) | [`r19`](references/research/19-scene-resource-formats.md) |
| Sintaxis 4.6 (no Godot 3) | [`18`](references/18-gdscript-csharp-cheatsheet.md) | [`examples/18`](assets/examples/18-gdscript-csharp-cheatsheet/) | [`r20`](references/research/20-gdscript-csharp-cheatsheet.md) |
| Audio / música / SFX | [`19`](references/19-audio.md) | [`examples/19`](assets/examples/19-audio/) | [`r21`](references/research/21-audio.md) |
| Input (teclado/ratón/gamepad) | [`20`](references/20-input.md) | [`examples/20`](assets/examples/20-input/) | [`r22`](references/research/22-input.md) |
| Arrancar el proyecto / addons | [`21`](references/21-project-bootstrap.md) | [`examples/21`](assets/examples/21-project-bootstrap/) | [`r23`](references/research/23-project-bootstrap.md) |
| Localización (i18n) | [`22`](references/22-localization.md) | [`examples/22`](assets/examples/22-localization/) | [`r24`](references/research/24-localization.md) |
| Multiplayer / co-op | [`23`](references/23-multiplayer.md) | [`examples/23`](assets/examples/23-multiplayer/) | [`r25`](references/research/25-multiplayer.md) |
| @tool / EditorPlugin / procedural | [`24`](references/24-tool-editor-plugin.md) | [`examples/24`](assets/examples/24-tool-editor-plugin/) | [`r26`](references/research/26-tool-editor-plugin.md) |
| VFX / partículas | [`25`](references/25-vfx-particles.md) | [`examples/25`](assets/examples/25-vfx-particles/) | [`r27`](references/research/27-vfx-particles.md) |
| Nativo C++ (GDExtension) | [`26`](references/26-gdextension.md) | [`examples/26`](assets/examples/26-gdextension/) | [`r28`](references/research/28-gdextension.md) |
| **MCP: editor vivo (Godot AI)** | [`27`](references/27-godot-ai-mcp.md) | — | — |
| **Flujos premium (orquestar el MCP)** | [`28`](references/28-premium-flows.md) | — | — |
| **Summer Engine (CLI+MCP+skills)** | [`29`](references/29-summer-engine.md) | — | — |
| **Enrutado MCP + lazo auto-correctivo** | [`30`](references/30-mcp-routing-loop.md) | — | — |

Doctrina y escalera completas: [`references/00-escalera-y-principios.md`](references/00-escalera-y-principios.md).
Filosofía aplicada (construir vs reusar, anti-stuck): [`references/99-filosofia-aplicada.md`](references/99-filosofia-aplicada.md).
Respaldo full-text (todo en un archivo, para búsqueda): [`skillgodot4.6.md`](skillgodot4.6.md).

## MCP: Claude controla el editor en vivo (Godot AI)

Si hay un editor Godot abierto con el addon **Godot AI** conectado (MCP), **prefiérelo**
para tocar la escena: `node_create`/`node_set_property`/`scene_*` (no edites `.tscn` a
mano — el MCP registra bien `uid://`), `script_create`/`script_patch`, `signal_manage`,
`resource_manage`, y **verifica viendo** con `project_run` + `editor_screenshot` +
`logs_read`. Son ~40 tools en 22 dominios. Conéctalo con `/godot-mcp` (o el botón
Configure del dock). Detalle y mapa sistema→tool: [`references/27-godot-ai-mcp.md`](references/27-godot-ai-mcp.md).
Para acciones de alto valor que encadenan varias tools (cablear un enemigo de combate,
bindear el HUD, playtest con capturas, lazo auto-fix), usa los **flujos premium**:
[`references/28-premium-flows.md`](references/28-premium-flows.md) (`/godot-flow <Fn>`).
Sin editor vivo, degrada al lazo headless de `scripts/`.

**Summer Engine** ([`references/29`](references/29-summer-engine.md)) es un motor AI-native
(drop-in de Godot 4) con su propio MCP (stdio, engine vivo en `:6550`, ~44 tools `summer_*`)
y ~27 agent skills. Si está presente, **prefiérelo y delega en sus skills/tools** (no
reimplementes lo que ya trae): `/godot-summer setup` lo cablea, `/godot-summer new <tpl>
<name>` scaffolda + añade el lazo de la skill. Esta skill **detecta el backend**
(Summer stdio vs Godot AI HTTP vs headless) y **enruta por contrato de capacidades** con un
**lazo auto-correctivo de convergencia** (lee el error real → arregla → re-play → escala si
no converge): ver [`references/30`](references/30-mcp-routing-loop.md). Regla anti-stuck:
**un verbo, un play, un vistazo**.

## Workflow: "Quiero un RPG" en 5 pasos

1. **Elige el target** → fija renderer y lenguaje. Desktop: Forward+. Móvil: Mobile.
   **Web: Compatibility + GDScript (sin C#)**. Detalle: fila 21.
2. **Scaffold el proyecto**: `bash scripts/new_project.sh <nombre> <desktop|mobile|web>`
   → crea `project.godot`, estructura de carpetas, `.gitignore`/`.gitattributes`,
   3 autoloads (settings, save, event_bus) y `git init`. (Plantillas en `assets/`.)
3. **Por cada sistema pedido**: localiza su fila en el dispatcher → lee `references/NN`
   → copia de `assets/examples/NN-*/` → adáptalo siguiendo el **veredicto ponytail**
   de esa sección (no construyas lo que el motor ya da).
4. **Cierra el lazo tras CADA cambio** (clave si no ves el editor):
   `bash scripts/verify_loop.sh` (ver siguiente bloque).
5. **Si te atascas**: fila 13 (errores con mensaje literal + árbol de decisión) y
   fila 16 (verificación headless). No adivines: reproduce el error por CLI.

## El lazo de verificación (para un agente que NO ve el editor)

Compilar no es arrancar. Pipeline de 4 fases, de barato a caro:

```bash
# 0. Warm-up de imports (puebla .godot/: caché, class_name, uid://). NUNCA --quit; usa --quit-after 2.
godot --headless --path . --import --quit-after 2
# 1. Validar sintaxis de TODOS los .gd con exit code FIABLE (no uses $? de --check-only).
#    (new_project.sh ya copia validate_all.gd a res://ci/ de tu proyecto.)
godot --headless --path . --script res://ci/validate_all.gd
# 2. Smoke test: ¿arranca el juego de verdad? timeout + </dev/null evitan que el debugger cuelgue el CI.
timeout 120 godot --headless --path . --quit-after 90 </dev/null
# 3. Tests (exit code fiable): GUT (-gexit) o gdUnit4 (--ignoreHeadlessMode).
```

`scripts/verify_loop.sh` encadena las 4 fases. **3 trampas que atascan a una IA**:
(a) sin `.godot/` en un checkout limpio, los errores de "Could not find base class"/"Unrecognized UID" son **caché, no código** → corre la fase 0; (b) el exit code de `--check-only` **miente** → grepea `SCRIPT ERROR`/`Parse Error` en stdout; (c) un break de debugger en headless **espera stdin para siempre** → `--quit-after N` + `timeout` + `</dev/null`. Detalle: `references/16-headless-cli-testing.md`.

## Reglas de oro

- **Tipa todo** (en 4.6 es velocidad, no estilo). - **Items/stats/loot = `Resource`**, no JSON a mano.
- **Señales + grupos + autoloads = tu event bus**; no escribas otro. - **3 autoloads de servicios reales**, no 12.
- **No mezcles GDScript/C# por sistema**. - **Web ⇒ GDScript** (sin C#). - Tras cada cambio, **cierra el lazo** (verify_loop).
