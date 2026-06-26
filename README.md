# Skill definitiva: RPG 3D libre en Godot 4.6 (filosofía ponytail)

Skill para agentes de IA y guía de referencia para construir un **RPG 3D
open-source en Godot 4.6** cubriendo **GDScript y C# (.NET 8)**, bajo la
filosofía [ponytail](https://github.com/DietrichGebert/ponytail): *el mejor
código es el que no escribes* — reusar nodos y `Resource` nativos del motor
antes que escribir arquitectura propia.

> Construida con búsqueda web real (junio 2026): documentación oficial de Godot
> 4.6, GitHub (RPGs open-source), foro de Godot, r/godot, GDQuest, GameFromScratch,
> Asset Store y StackOverflow. **747 fuentes reales** citadas. Cada sistema se
> generó y revisó con workflows multi-agente: investigación → auditoría adversarial
> contra docs 4.6 → Multi-Agent Debate (MAD) → segunda auditoría/corrección.

## Contenido

- **[`skillgodot4.6.md`](./skillgodot4.6.md)** — la skill ensamblada (formato
  ponytail). Fundamentos (escalera de decisión, features 4.6, GDScript vs C#),
  **26 secciones** en profundidad y un cierre de **filosofía aplicada / anti-stuck**.
- **[`godot-rpg-examples/`](./godot-rpg-examples/)** — ejemplos ejecutables
  `.gd`, `.cs`, `.gdshader`, `.tscn`, `.gdextension`/`.cpp`, etc., por sistema.
- **[`godot-rpg-research/`](./godot-rpg-research/)** — notas de investigación con
  las fuentes reales (`00-rendering`, `01-release-editor`, una por sistema, y
  `17-filosofia-anti-stuck`).

## Los 10 sistemas de RPG

| # | Sistema | Investigación | Ejemplos |
|---|---|---|---|
| 1 | Controlador de personaje + cámara 3ª persona | [`02-character-controller-camera.md`](./godot-rpg-research/02-character-controller-camera.md) | [`01-character-controller-camera/`](./godot-rpg-examples/01-character-controller-camera/) |
| 2 | Animación / AnimationTree / IK | [`03-animation-ik.md`](./godot-rpg-research/03-animation-ik.md) | [`02-animation-ik/`](./godot-rpg-examples/02-animation-ik/) |
| 3 | Combate y daño | [`04-combat-damage.md`](./godot-rpg-research/04-combat-damage.md) | [`03-combat-damage/`](./godot-rpg-examples/03-combat-damage/) |
| 4 | Stats / niveles / progresión | [`05-stats-progression.md`](./godot-rpg-research/05-stats-progression.md) | [`04-stats-progression/`](./godot-rpg-examples/04-stats-progression/) |
| 5 | Inventario / items / equipo | [`06-inventory-equipment.md`](./godot-rpg-research/06-inventory-equipment.md) | [`05-inventory-equipment/`](./godot-rpg-examples/05-inventory-equipment/) |
| 6 | Diálogo y quests | [`07-dialogue-quests.md`](./godot-rpg-research/07-dialogue-quests.md) | [`06-dialogue-quests/`](./godot-rpg-examples/06-dialogue-quests/) |
| 7 | IA enemiga y navegación | [`08-enemy-ai-navigation.md`](./godot-rpg-research/08-enemy-ai-navigation.md) | [`07-enemy-ai-navigation/`](./godot-rpg-examples/07-enemy-ai-navigation/) |
| 8 | Guardado / persistencia | [`09-save-persistence.md`](./godot-rpg-research/09-save-persistence.md) | [`08-save-persistence/`](./godot-rpg-examples/08-save-persistence/) |
| 9 | UI / HUD / menús | [`10-ui-hud-menus.md`](./godot-rpg-research/10-ui-hud-menus.md) | [`09-ui-hud-menus/`](./godot-rpg-examples/09-ui-hud-menus/) |
| 10 | Gestión de mundo / niveles y arquitectura | [`11-world-architecture.md`](./godot-rpg-research/11-world-architecture.md) | [`10-world-architecture/`](./godot-rpg-examples/10-world-architecture/) |

## Temas avanzados (anti-stuck)

| # | Tema | Investigación | Ejemplos |
|---|---|---|---|
| 11 | Shaders para RPG | [`12-shaders-rpg.md`](./godot-rpg-research/12-shaders-rpg.md) | [`11-shaders-rpg/`](./godot-rpg-examples/11-shaders-rpg/) |
| 12 | Importación de assets | [`13-asset-import.md`](./godot-rpg-research/13-asset-import.md) | [`12-asset-import/`](./godot-rpg-examples/12-asset-import/) |
| 13 | Errores comunes y cómo desatascarse | [`14-common-errors-unstuck.md`](./godot-rpg-research/14-common-errors-unstuck.md) | [`13-common-errors-unstuck/`](./godot-rpg-examples/13-common-errors-unstuck/) |
| 14 | Depuración y profiling | [`15-debugging-profiling.md`](./godot-rpg-research/15-debugging-profiling.md) | [`14-debugging-profiling/`](./godot-rpg-examples/14-debugging-profiling/) |
| 15 | C# .NET 8 a fondo | [`16-csharp-dotnet8.md`](./godot-rpg-research/16-csharp-dotnet8.md) | [`15-csharp-dotnet8/`](./godot-rpg-examples/15-csharp-dotnet8/) |

## Infraestructura, lenguaje y extras (para que la IA no falle)

| # | Tema | Investigación | Ejemplos |
|---|---|---|---|
| 16 | Auto-verificación headless, CLI y testing | [`18-headless-cli-testing.md`](./godot-rpg-research/18-headless-cli-testing.md) | [`16-headless-cli-testing/`](./godot-rpg-examples/16-headless-cli-testing/) |
| 17 | Formatos .tscn/.tres/project.godot y UIDs | [`19-scene-resource-formats.md`](./godot-rpg-research/19-scene-resource-formats.md) | [`17-scene-resource-formats/`](./godot-rpg-examples/17-scene-resource-formats/) |
| 18 | Cheat-sheet GDScript 2.0 y C# (vs Godot 3) | [`20-gdscript-csharp-cheatsheet.md`](./godot-rpg-research/20-gdscript-csharp-cheatsheet.md) | [`18-gdscript-csharp-cheatsheet/`](./godot-rpg-examples/18-gdscript-csharp-cheatsheet/) |
| 19 | Audio: música, SFX y buses | [`21-audio.md`](./godot-rpg-research/21-audio.md) | [`19-audio/`](./godot-rpg-examples/19-audio/) |
| 20 | Input a fondo: teclado, ratón y gamepad | [`22-input.md`](./godot-rpg-research/22-input.md) | [`20-input/`](./godot-rpg-examples/20-input/) |
| 21 | Arranque de proyecto y addons curados | [`23-project-bootstrap.md`](./godot-rpg-research/23-project-bootstrap.md) | [`21-project-bootstrap/`](./godot-rpg-examples/21-project-bootstrap/) |
| 22 | Localización (i18n) | [`24-localization.md`](./godot-rpg-research/24-localization.md) | [`22-localization/`](./godot-rpg-examples/22-localization/) |
| 23 | Multiplayer y co-op | [`25-multiplayer.md`](./godot-rpg-research/25-multiplayer.md) | [`23-multiplayer/`](./godot-rpg-examples/23-multiplayer/) |
| 24 | @tool, EditorPlugin y generación procedural | [`26-tool-editor-plugin.md`](./godot-rpg-research/26-tool-editor-plugin.md) | [`24-tool-editor-plugin/`](./godot-rpg-examples/24-tool-editor-plugin/) |
| 25 | VFX y partículas como gameplay | [`27-vfx-particles.md`](./godot-rpg-research/27-vfx-particles.md) | [`25-vfx-particles/`](./godot-rpg-examples/25-vfx-particles/) |
| 26 | GDExtension (C++ y más allá) | [`28-gdextension.md`](./godot-rpg-research/28-gdextension.md) | [`26-gdextension/`](./godot-rpg-examples/26-gdextension/) |

Más un cierre **«Filosofía aplicada: construir vs reusar y cómo no quedarte
atascado»** (checklist reusar-vs-construir, señales de sobre/infra-diseño, guía
anti-stuck para agentes de IA).

## Datos de Godot 4.6 que asume esta skill

- **Jolt** físico 3D por defecto (proyectos nuevos). Suite IK bajo
  `IKModifier3D`/`SkeletonModifier3D`. **SSR** Hi-Z half-res (`ssr_depth_tolerance` 0.2→0.5).
- **Diccionarios/arrays tipados**; `@abstract` desde 4.5. Renderers
  Forward+/Mobile/Compatibility (web = Compatibility, **sin C#**). **D3D12** por
  defecto en Windows (proyectos nuevos).
- `.tscn` 4.6 sin `load_steps`; recursos con `uid://` + archivos `.uid` (desde 4.4).
- Breaking 4.5→4.6: glow más brillante; shaders GLSL crudos `view_matrix` mat4→mat3x4
  (no afecta a `shader_type spatial`); `AnimationPlayer` propiedades de nombre de
  animación String→StringName (GH-110767).

## Cómo se usa

Apunta tu agente al `.md`. La `description` del frontmatter lista las frases que
la activan. El cuerpo es la guía con código real listo para pegar en un proyecto
Godot 4.6, y secciones dedicadas a **auto-verificación headless/CLI** para que la
IA cierre el lazo edito→compruebo→corrijo sin abrir el editor.

## Aviso

Complementa, no sustituye, a la documentación oficial de Godot. Ante una duda de
API concreta, consulta los docs de 4.6. Si una feature cambió en un parche 4.6.x,
gana la documentación oficial.
