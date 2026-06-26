# Skill: Creador de RPG 3D en Godot 4.6 (ponytail)

**Agent Skill** que convierte a Claude en un creador de videojuegos Godot 4.6
operativo (no solo una guía): carga `SKILL.md`, salta a lo que necesita vía un
*dispatcher*, copia código real y **cierra el lazo de verificación headless** sin
abrir el editor. Filosofía [ponytail](https://github.com/DietrichGebert/ponytail):
*el mejor código es el que no escribes* — reusar nodos y `Resource` nativos antes
que escribir arquitectura propia (con su límite: **lazy, no negligente**).

> Construida con búsqueda web real (junio 2026): docs oficiales 4.6, GitHub
> (RPGs open-source), foro de Godot, r/godot, GDQuest, Asset Store, StackOverflow.
> **747 fuentes reales**. Cada sistema pasó por investigación → auditoría
> adversarial contra docs 4.6 → Multi-Agent Debate → segunda auditoría.

## Cómo se usa (progressive disclosure)

1. **Punto de entrada: [`SKILL.md`](./SKILL.md)** (~130 líneas / ~2.9k tokens) —
   escalera ponytail, principio *lazy-not-negligent*, qué trae 4.6, **dispatcher
   tema→archivo**, workflow "Quiero un RPG" en 5 pasos, y el lazo de verificación.
2. **`references/`** — el detalle por sistema (26 guías + `00-escalera-y-principios`
   + `99-filosofia-aplicada`). Se leen **bajo demanda**, solo la fila que aplica.
3. **`assets/examples/`** — 130+ ejemplos copiables (`.gd`/`.cs`/`.gdshader`/`.tscn`/…).
4. **`scripts/`** — herramientas ejecutables: `new_project.sh` (scaffolder),
   `verify_loop.sh` / `validate_all.gd` / `validate_gd.sh` / `smoke_test.sh` (lazo headless).
5. **`references/research/`** — notas con las 747 fuentes reales.
6. **[`skillgodot4.6.md`](./skillgodot4.6.md)** — respaldo full-text monolítico (no canónico).

## Estructura

```
SKILL.md                 # entry point (<500 líneas, dispatcher + workflow)
references/               # 00-principios, 01..26 sistemas, 99-filosofía, research/
scripts/                 # new_project.sh + lazo de verificación headless
assets/                  # plantillas (project.godot/.gitignore/.gitattributes) + examples/
skillgodot4.6.md         # respaldo full-text
```

## Los 10 sistemas de RPG

| # | Sistema | Guía | Ejemplos | Fuentes |
|---|---|---|---|---|
| 1 | Personaje + cámara 3ª persona | [`references/01-character-controller-camera.md`](./references/01-character-controller-camera.md) | [`01/`](./assets/examples/01-character-controller-camera/) | [`r02`](./references/research/02-character-controller-camera.md) |
| 2 | Animación / AnimationTree / IK | [`references/02-animation-ik.md`](./references/02-animation-ik.md) | [`02/`](./assets/examples/02-animation-ik/) | [`r03`](./references/research/03-animation-ik.md) |
| 3 | Combate y daño | [`references/03-combat-damage.md`](./references/03-combat-damage.md) | [`03/`](./assets/examples/03-combat-damage/) | [`r04`](./references/research/04-combat-damage.md) |
| 4 | Stats / niveles / progresión | [`references/04-stats-progression.md`](./references/04-stats-progression.md) | [`04/`](./assets/examples/04-stats-progression/) | [`r05`](./references/research/05-stats-progression.md) |
| 5 | Inventario / items / equipo | [`references/05-inventory-equipment.md`](./references/05-inventory-equipment.md) | [`05/`](./assets/examples/05-inventory-equipment/) | [`r06`](./references/research/06-inventory-equipment.md) |
| 6 | Diálogo y quests | [`references/06-dialogue-quests.md`](./references/06-dialogue-quests.md) | [`06/`](./assets/examples/06-dialogue-quests/) | [`r07`](./references/research/07-dialogue-quests.md) |
| 7 | IA enemiga y navegación | [`references/07-enemy-ai-navigation.md`](./references/07-enemy-ai-navigation.md) | [`07/`](./assets/examples/07-enemy-ai-navigation/) | [`r08`](./references/research/08-enemy-ai-navigation.md) |
| 8 | Guardado / persistencia | [`references/08-save-persistence.md`](./references/08-save-persistence.md) | [`08/`](./assets/examples/08-save-persistence/) | [`r09`](./references/research/09-save-persistence.md) |
| 9 | UI / HUD / menús | [`references/09-ui-hud-menus.md`](./references/09-ui-hud-menus.md) | [`09/`](./assets/examples/09-ui-hud-menus/) | [`r10`](./references/research/10-ui-hud-menus.md) |
| 10 | Mundo / niveles / arquitectura | [`references/10-world-architecture.md`](./references/10-world-architecture.md) | [`10/`](./assets/examples/10-world-architecture/) | [`r11`](./references/research/11-world-architecture.md) |

## Temas avanzados (anti-stuck)

| # | Tema | Guía | Ejemplos | Fuentes |
|---|---|---|---|---|
| 11 | Shaders para RPG | [`references/11-shaders-rpg.md`](./references/11-shaders-rpg.md) | [`11/`](./assets/examples/11-shaders-rpg/) | [`r12`](./references/research/12-shaders-rpg.md) |
| 12 | Importación de assets | [`references/12-asset-import.md`](./references/12-asset-import.md) | [`12/`](./assets/examples/12-asset-import/) | [`r13`](./references/research/13-asset-import.md) |
| 13 | Errores comunes / desatascarse | [`references/13-common-errors-unstuck.md`](./references/13-common-errors-unstuck.md) | [`13/`](./assets/examples/13-common-errors-unstuck/) | [`r14`](./references/research/14-common-errors-unstuck.md) |
| 14 | Depuración y profiling | [`references/14-debugging-profiling.md`](./references/14-debugging-profiling.md) | [`14/`](./assets/examples/14-debugging-profiling/) | [`r15`](./references/research/15-debugging-profiling.md) |
| 15 | C# .NET 8 a fondo | [`references/15-csharp-dotnet8.md`](./references/15-csharp-dotnet8.md) | [`15/`](./assets/examples/15-csharp-dotnet8/) | [`r16`](./references/research/16-csharp-dotnet8.md) |

## Infraestructura, lenguaje y extras (para que la IA no falle)

| # | Tema | Guía | Ejemplos | Fuentes |
|---|---|---|---|---|
| 16 | Headless / CLI / testing | [`references/16-headless-cli-testing.md`](./references/16-headless-cli-testing.md) | [`16/`](./assets/examples/16-headless-cli-testing/) | [`r18`](./references/research/18-headless-cli-testing.md) |
| 17 | Formatos .tscn/.tres/uid | [`references/17-scene-resource-formats.md`](./references/17-scene-resource-formats.md) | [`17/`](./assets/examples/17-scene-resource-formats/) | [`r19`](./references/research/19-scene-resource-formats.md) |
| 18 | Cheat-sheet GDScript/C# (vs G3) | [`references/18-gdscript-csharp-cheatsheet.md`](./references/18-gdscript-csharp-cheatsheet.md) | [`18/`](./assets/examples/18-gdscript-csharp-cheatsheet/) | [`r20`](./references/research/20-gdscript-csharp-cheatsheet.md) |
| 19 | Audio | [`references/19-audio.md`](./references/19-audio.md) | [`19/`](./assets/examples/19-audio/) | [`r21`](./references/research/21-audio.md) |
| 20 | Input (teclado/ratón/gamepad) | [`references/20-input.md`](./references/20-input.md) | [`20/`](./assets/examples/20-input/) | [`r22`](./references/research/22-input.md) |
| 21 | Arranque de proyecto + addons | [`references/21-project-bootstrap.md`](./references/21-project-bootstrap.md) | [`21/`](./assets/examples/21-project-bootstrap/) | [`r23`](./references/research/23-project-bootstrap.md) |
| 22 | Localización (i18n) | [`references/22-localization.md`](./references/22-localization.md) | [`22/`](./assets/examples/22-localization/) | [`r24`](./references/research/24-localization.md) |
| 23 | Multiplayer / co-op | [`references/23-multiplayer.md`](./references/23-multiplayer.md) | [`23/`](./assets/examples/23-multiplayer/) | [`r25`](./references/research/25-multiplayer.md) |
| 24 | @tool / EditorPlugin / procedural | [`references/24-tool-editor-plugin.md`](./references/24-tool-editor-plugin.md) | [`24/`](./assets/examples/24-tool-editor-plugin/) | [`r26`](./references/research/26-tool-editor-plugin.md) |
| 25 | VFX / partículas | [`references/25-vfx-particles.md`](./references/25-vfx-particles.md) | [`25/`](./assets/examples/25-vfx-particles/) | [`r27`](./references/research/27-vfx-particles.md) |
| 26 | GDExtension (C++) | [`references/26-gdextension.md`](./references/26-gdextension.md) | [`26/`](./assets/examples/26-gdextension/) | [`r28`](./references/research/28-gdextension.md) |

## Arranque rápido

```bash
# Genera un proyecto RPG mínimo y arrancable (target: desktop|mobile|web)
bash scripts/new_project.sh MiRPG desktop
# Tras cada cambio, cierra el lazo (dentro del proyecto Godot):
bash scripts/verify_loop.sh
```

## Datos de Godot 4.6 que asume

Jolt físico 3D por defecto · suite `IKModifier3D` · diccionarios/arrays tipados ·
`@abstract` desde 4.5 · renderers Forward+/Mobile/Compatibility (**web sin C#**) ·
D3D12 por defecto en Windows · `.tscn` sin `load_steps`, recursos con `uid://`+`.uid` ·
`AnimationPlayer` propiedades de nombre String→StringName (GH-110767).

## Aviso

Complementa, no sustituye, la documentación oficial de Godot. Ante duda de API,
consulta los docs de 4.6. El binario `godot` 4.6 debe estar en PATH para correr
el lazo de verificación end-to-end.
