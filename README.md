# Skill definitiva: RPG 3D libre en Godot 4.6 (filosofía ponytail)

Skill para agentes de IA y guía de referencia para construir un **RPG 3D
open-source en Godot 4.6** cubriendo **GDScript y C# (.NET 8)**, bajo la
filosofía [ponytail](https://github.com/DietrichGebert/ponytail): *el mejor
código es el que no escribes* — reusar nodos y `Resource` nativos del motor
antes que escribir arquitectura propia.

> Investigación con búsqueda web real (junio 2026): documentación oficial de
> Godot 4.6, GitHub (RPGs open-source), foro de Godot, r/godot, GDQuest,
> GameFromScratch, Asset Store y StackOverflow. **419 fuentes reales**
> citadas. Los 15 sistemas se construyeron y revisaron con workflows
> multi-agente (investigación → auditoría adversarial contra docs 4.6 →
> Multi-Agent Debate para los temas anti-stuck).

## Contenido

- **[`skillgodot4.6.md`](./skillgodot4.6.md)** — la skill ensamblada (formato
  ponytail: frontmatter con frases-gatillo + cuerpo markdown). Escalera de
  decisión, features de 4.6 (Jolt, suite `IKModifier3D`, diccionarios tipados,
  `@abstract` desde 4.5, renderers, SSR Hi-Z), GDScript vs C#, **15 sistemas en
  profundidad** y una sección de **filosofía aplicada / anti-stuck**.
- **[`godot-rpg-examples/`](./godot-rpg-examples/)** — scripts `.gd`, `.cs` y
  shaders `.gdshader` ejecutables. Raíz: ejemplos mínimos base; subcarpetas
  `NN-sistema/`: ejemplos por dominio.
- **[`godot-rpg-research/`](./godot-rpg-research/)** — notas de investigación
  con las fuentes reales: `00-rendering`, `01-release-editor`, una nota por cada
  sistema (`02`–`16`) y `17-filosofia-anti-stuck`.

## Los 10 sistemas de RPG

| # | Sistema | Investigación | Ejemplos |
|---|---|---|---|
| 1 | Controlador de personaje + cámara 3ª persona | [`godot-rpg-research/02-character-controller-camera.md`](./godot-rpg-research/02-character-controller-camera.md) | [`godot-rpg-examples/01-character-controller-camera/`](./godot-rpg-examples/01-character-controller-camera/) |
| 2 | Animación / AnimationTree / IK | [`godot-rpg-research/03-animation-ik.md`](./godot-rpg-research/03-animation-ik.md) | [`godot-rpg-examples/02-animation-ik/`](./godot-rpg-examples/02-animation-ik/) |
| 3 | Combate y daño | [`godot-rpg-research/04-combat-damage.md`](./godot-rpg-research/04-combat-damage.md) | [`godot-rpg-examples/03-combat-damage/`](./godot-rpg-examples/03-combat-damage/) |
| 4 | Stats / niveles / progresión | [`godot-rpg-research/05-stats-progression.md`](./godot-rpg-research/05-stats-progression.md) | [`godot-rpg-examples/04-stats-progression/`](./godot-rpg-examples/04-stats-progression/) |
| 5 | Inventario / items / equipo | [`godot-rpg-research/06-inventory-equipment.md`](./godot-rpg-research/06-inventory-equipment.md) | [`godot-rpg-examples/05-inventory-equipment/`](./godot-rpg-examples/05-inventory-equipment/) |
| 6 | Diálogo y quests | [`godot-rpg-research/07-dialogue-quests.md`](./godot-rpg-research/07-dialogue-quests.md) | [`godot-rpg-examples/06-dialogue-quests/`](./godot-rpg-examples/06-dialogue-quests/) |
| 7 | IA enemiga y navegación | [`godot-rpg-research/08-enemy-ai-navigation.md`](./godot-rpg-research/08-enemy-ai-navigation.md) | [`godot-rpg-examples/07-enemy-ai-navigation/`](./godot-rpg-examples/07-enemy-ai-navigation/) |
| 8 | Guardado / persistencia | [`godot-rpg-research/09-save-persistence.md`](./godot-rpg-research/09-save-persistence.md) | [`godot-rpg-examples/08-save-persistence/`](./godot-rpg-examples/08-save-persistence/) |
| 9 | UI / HUD / menús | [`godot-rpg-research/10-ui-hud-menus.md`](./godot-rpg-research/10-ui-hud-menus.md) | [`godot-rpg-examples/09-ui-hud-menus/`](./godot-rpg-examples/09-ui-hud-menus/) |
| 10 | Gestión de mundo / niveles y arquitectura | [`godot-rpg-research/11-world-architecture.md`](./godot-rpg-research/11-world-architecture.md) | [`godot-rpg-examples/10-world-architecture/`](./godot-rpg-examples/10-world-architecture/) |

## Temas avanzados (anti-stuck)

| # | Tema | Investigación | Ejemplos |
|---|---|---|---|
| 11 | Shaders para RPG | [`godot-rpg-research/12-shaders-rpg.md`](./godot-rpg-research/12-shaders-rpg.md) | [`godot-rpg-examples/11-shaders-rpg/`](./godot-rpg-examples/11-shaders-rpg/) |
| 12 | Importación de assets | [`godot-rpg-research/13-asset-import.md`](./godot-rpg-research/13-asset-import.md) | [`godot-rpg-examples/12-asset-import/`](./godot-rpg-examples/12-asset-import/) |
| 13 | Errores comunes y cómo desatascarse | [`godot-rpg-research/14-common-errors-unstuck.md`](./godot-rpg-research/14-common-errors-unstuck.md) | [`godot-rpg-examples/13-common-errors-unstuck/`](./godot-rpg-examples/13-common-errors-unstuck/) |
| 14 | Depuración y profiling | [`godot-rpg-research/15-debugging-profiling.md`](./godot-rpg-research/15-debugging-profiling.md) | [`godot-rpg-examples/14-debugging-profiling/`](./godot-rpg-examples/14-debugging-profiling/) |
| 15 | C# .NET 8 a fondo | [`godot-rpg-research/16-csharp-dotnet8.md`](./godot-rpg-research/16-csharp-dotnet8.md) | [`godot-rpg-examples/15-csharp-dotnet8/`](./godot-rpg-examples/15-csharp-dotnet8/) |

Más una sección **«Filosofía aplicada: construir vs reusar y cómo no quedarte
atascado»** (checklist de decisión reusar-vs-construir, señales de sobre/infra-diseño
y guía anti-stuck para agentes de IA).

## Datos de Godot 4.6 que asume esta skill

- **Jolt** es el motor de física 3D por defecto en proyectos nuevos.
- Suite IK bajo `IKModifier3D`/`SkeletonModifier3D`: `TwoBoneIK3D`, `SplineIK3D`,
  `FABRIK3D`, `CCDIK3D`, `JacobianIK3D`, `ChainIK3D`, `IterateIK3D`.
- **SSR reescrito** (Hi-Z, half-res); `ssr_depth_tolerance` 0.2→0.5.
- **Diccionarios tipados** `Dictionary[K, V]`. `@abstract` existe **desde 4.5**.
- Renderers Forward+ / Mobile / Compatibility (web = Compatibility, **sin C#**).
- **D3D12** driver por defecto en Windows (proyectos nuevos).
- Breaking 4.5→4.6: glow más brillante; en shaders GLSL crudos `view_matrix`
  mat4→mat3x4 (no afecta a `shader_type spatial`); `AnimationPlayer` propiedades
  de nombre de animación String→StringName (GH-110767).

## Cómo se usa

Apunta tu agente al `.md`. La `description` del frontmatter lista las frases
que la activan. El cuerpo es la guía con código real listo para pegar en un
proyecto Godot 4.6.

## Aviso

Complementa, no sustituye, a la documentación oficial de Godot. Ante una duda
de API concreta, consulta los docs de 4.6. Si una feature citada cambió en un
parche 4.6.x, gana la documentación oficial.
