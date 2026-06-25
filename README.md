# Skill definitiva: RPG 3D libre en Godot 4.6 (filosofía ponytail)

Skill para agentes de IA y guía de referencia para construir un **RPG 3D
open-source en Godot 4.6** cubriendo **GDScript y C# (.NET 8)**, bajo la
filosofía [ponytail](https://github.com/DietrichGebert/ponytail): *el mejor
código es el que no escribes* — reusar nodos y `Resource` nativos del motor
antes que escribir arquitectura propia.

> Investigación realizada con búsqueda web real (junio 2026): documentación
> oficial de Godot 4.6, GitHub (proyectos RPG open-source), foro de Godot,
> r/godot, GDQuest, Asset Library y StackOverflow. **254 fuentes
> reales** citadas a lo largo de las secciones y notas.

## Contenido

- **[`skillgodot4.6.md`](./skillgodot4.6.md)** — la skill ensamblada (formato
  ponytail: frontmatter con frases-gatillo + cuerpo markdown). Incluye la
  escalera de decisión, las features de 4.6 que cambian tus decisiones (Jolt por
  defecto, suite `IKModifier3D`, diccionarios tipados, `@abstract` desde 4.5,
  renderers, SSR Hi-Z), GDScript vs C#, y **los 10 sistemas de RPG en
  profundidad**.
- **[`godot-rpg-examples/`](./godot-rpg-examples/)** — scripts `.gd` y `.cs`
  ejecutables. En la raíz, los ejemplos mínimos base; en subcarpetas
  `NN-sistema/`, los ejemplos profundos por dominio.
- **[`godot-rpg-research/`](./godot-rpg-research/)** — notas de investigación
  con las fuentes reales: `00-rendering.md`, `01-release-editor.md` y una nota
  por cada uno de los 10 sistemas.

## Los 10 sistemas

| # | Sistema | Investigación | Ejemplos | Fuentes |
|---|---|---|---|---|
| 1 | Controlador de personaje + cámara 3ª persona | [`godot-rpg-research/02-character-controller-camera.md`](./godot-rpg-research/02-character-controller-camera.md) | [`godot-rpg-examples/01-character-controller-camera/`](./godot-rpg-examples/01-character-controller-camera/) | 23 |
| 2 | Animación / AnimationTree / IK | [`godot-rpg-research/03-animation-ik.md`](./godot-rpg-research/03-animation-ik.md) | [`godot-rpg-examples/02-animation-ik/`](./godot-rpg-examples/02-animation-ik/) | 27 |
| 3 | Combate y daño | [`godot-rpg-research/04-combat-damage.md`](./godot-rpg-research/04-combat-damage.md) | [`godot-rpg-examples/03-combat-damage/`](./godot-rpg-examples/03-combat-damage/) | 23 |
| 4 | Stats / niveles / progresión | [`godot-rpg-research/05-stats-progression.md`](./godot-rpg-research/05-stats-progression.md) | [`godot-rpg-examples/04-stats-progression/`](./godot-rpg-examples/04-stats-progression/) | 29 |
| 5 | Inventario / items / equipo | [`godot-rpg-research/06-inventory-equipment.md`](./godot-rpg-research/06-inventory-equipment.md) | [`godot-rpg-examples/05-inventory-equipment/`](./godot-rpg-examples/05-inventory-equipment/) | 24 |
| 6 | Diálogo y quests | [`godot-rpg-research/07-dialogue-quests.md`](./godot-rpg-research/07-dialogue-quests.md) | [`godot-rpg-examples/06-dialogue-quests/`](./godot-rpg-examples/06-dialogue-quests/) | 19 |
| 7 | IA enemiga y navegación | [`godot-rpg-research/08-enemy-ai-navigation.md`](./godot-rpg-research/08-enemy-ai-navigation.md) | [`godot-rpg-examples/07-enemy-ai-navigation/`](./godot-rpg-examples/07-enemy-ai-navigation/) | 25 |
| 8 | Guardado / persistencia | [`godot-rpg-research/09-save-persistence.md`](./godot-rpg-research/09-save-persistence.md) | [`godot-rpg-examples/08-save-persistence/`](./godot-rpg-examples/08-save-persistence/) | 26 |
| 9 | UI / HUD / menús | [`godot-rpg-research/10-ui-hud-menus.md`](./godot-rpg-research/10-ui-hud-menus.md) | [`godot-rpg-examples/09-ui-hud-menus/`](./godot-rpg-examples/09-ui-hud-menus/) | 21 |
| 10 | Gestión de mundo / niveles y arquitectura | [`godot-rpg-research/11-world-architecture.md`](./godot-rpg-research/11-world-architecture.md) | [`godot-rpg-examples/10-world-architecture/`](./godot-rpg-examples/10-world-architecture/) | 37 |

## Datos de Godot 4.6 que asume esta skill

- **Jolt** es el motor de física 3D por defecto en proyectos nuevos.
- Suite IK completa bajo `IKModifier3D`/`SkeletonModifier3D`: `TwoBoneIK3D`,
  `SplineIK3D`, `FABRIK3D`, `CCDIK3D`, `JacobianIK3D`, `ChainIK3D`, `IterateIK3D`.
- **SSR reescrito** (Hi-Z, half-res por defecto); `ssr_depth_tolerance` 0.2→0.5.
- **Diccionarios tipados** `Dictionary[K, V]`.
- `@abstract` existe **desde 4.5** (no es de 4.6).
- Renderers Forward+ / Mobile / Compatibility (web = Compatibility).
- **D3D12** es el driver por defecto en Windows en proyectos nuevos.
- Breaking 4.5→4.6: glow más brillante, GLSL `view_matrix` mat4→mat3x4,
  `AnimationPlayer` String→StringName (recompilar C#).

## Cómo se usa

Apunta tu agente al `.md`. La sección `description` del frontmatter lista las
frases que la activan (p. ej. "RPG en Godot", "Godot 4.6", "inventario",
"combate", "IA enemiga"). El cuerpo es la guía que el agente sigue, con código
real listo para pegar en un proyecto Godot 4.6.

## Aviso

Complementa, no sustituye, a la documentación oficial de Godot. Ante una duda
de API concreta, consulta los docs de la versión 4.6. Si una feature citada
cambió en un parche 4.6.x, gana la documentación oficial.
