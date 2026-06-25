---
name: godot-4.6-rpg
description: >
  Construir un RPG 3D libre (open-source) en Godot 4.6 con la filosofía
  ponytail: el mejor código es el que no escribes. Cubre GDScript y C#,
  features nuevas de 4.6 (Jolt por defecto, IKModifier3D, diccionarios
  tipados, clases @abstract, SSR/LOD) y los sistemas de RPG (estados,
  inventario, diálogo, combate, guardado) resolviéndolos con nodos y
  recursos nativos antes que con arquitectura propia. Úsalo cuando el
  usuario diga "RPG en Godot", "Godot 4.6", "personaje 3D", "inventario",
  "sistema de guardado", "GDScript vs C#", o invoque /godot-4.6-rpg.
  Complementa, no sustituye, a la documentación oficial: ante una duda de
  API concreta, consulta los docs de la versión 4.6.
---

Antes de escribir UNA línea de un sistema de RPG en Godot, baja la escalera
ponytail. El motor ya trae casi todo lo de un RPG; la mayoría del "código de
gameplay" es plomería que Godot resuelve con un nodo o un Resource.

## La escalera (aplícala a cada sistema antes de codear)

1. ¿Hace falta que exista? Un RPG no necesita un `GameManager` singleton el día 1.
2. ¿Lo da un **nodo** de Godot? `CharacterBody3D`, `NavigationAgent3D`, `AnimationTree`, `AudioStreamPlayer3D`, `GPUParticles3D`. No reescribas su lógica.
3. ¿Lo da un **Resource**? Items, stats, recetas, diálogos, loot tables = `Resource` con `@export`. No clases de datos a mano, no JSON parseado a mano.
4. ¿Lo dan **señales + grupos + autoloads**? Es el bus de eventos nativo. No escribas tu propio EventBus si una señal basta.
5. ¿Es una línea? `velocity = direction * speed; move_and_slide()` ya es tu locomoción. No envuelvas `move_and_slide` en un framework.
6. Solo entonces: escribe el mínimo que funciona, tipado.

El veredicto ponytail al revisar un sistema: `net: -<N> líneas posibles.` Si no hay nada que cortar y usa nodos nativos: `Limpio. A jugar.`

## Qué trae 4.6 que cambia tus decisiones

- **Jolt es el motor de física 3D por defecto** en proyectos nuevos (2-3× en escenas complejas). No instales plugins de física; no toques el `PhysicsServer` salvo necesidad real. Si migras un proyecto 4.5, actívalo en Project Settings → Physics → 3D → Physics Engine = Jolt.
- **`IKModifier3D`** integra IK en el núcleo: FABRIK (cadenas: colas, tentáculos, columna), CCD (aproximado y rápido para tiempo real), y two-bone IK (óptimo para brazos/piernas, p. ej. pies pegados al terreno). Antes esto era un plugin o math propio: ahora es un nodo hijo del `Skeleton3D`. Bórralo de tu TODO de "escribir IK".
- **SSR rehecho** (reflejos screen-space más estables, mejor roughness, más rápido) y **LOD** que preserva mejor la forma de mallas multi-parte. Calidad gratis: no hagas tu propio sistema de impostores para empezar.
- **Diccionarios tipados**: `Dictionary[String, ItemData]`. Inspector mejor y type-safety. Úsalos para inventarios/tablas en vez de `Dictionary` suelto.
- **Clases y métodos `@abstract`** (desde 4.5): define la base de tus estados/items como abstracta en vez de simular interfaces con `assert`.
- **GDScript más rápido** por optimizaciones de bytecode, sobre todo en **código tipado**. Regla 4.6: si te importa el rendimiento de GDScript, **tipa todo** (`var hp: int`, `func take(dmg: int) -> void`). El tipado no es estilo, es velocidad.
- **Editor**: Select y Transform desacoplados (modo Transform + modo Select-only); GridMap pinta/borra con interpolación Bresenham (líneas sólidas al arrastrar). Útil para construir mazmorras con GridMap.

## GDScript vs C#: elige una, no las mezcles por sistema

- **GDScript** por defecto: iteración instantánea, integración total con el editor, señales y `@export` sin fricción. En 4.6 tipado va sobrado para la lógica de un RPG. Es la opción ponytail (menos andamiaje).
- **C#** solo si ya lo justificas: simulación pesada en CPU (pathfinding masivo, ECS propio, miles de entidades), o reutilizar librerías .NET. Usa **.NET 8**; en desktop todos los runtimes; NativeAOT (`PublishAOT=true`, target ≥ net7) para arranque rápido. Android/iOS con NativeAOT siguen **experimentales** y web **no** soporta C#. Si tu RPG apunta a web, GDScript.
- No partas un mismo sistema entre los dos lenguajes por moda. El cruce GDScript↔C# tiene coste de marshalling; cruza por arquitectura, no por capricho.

## Locomoción del personaje (la base, sin framework)

GDScript — esto ES el sistema de movimiento, no le pongas capas encima:

```gdscript
extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input := Input.get_vector("left", "right", "forward", "back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
```

`move_and_slide()` ya resuelve colisiones, rampas y suelo. Envolverlo en un "MovementController" con eventos es el anti-patrón que ponytail caza: `yagni`.

## Datos del RPG = Resources, siempre

Items, stats, hechizos, recetas, enemigos: `Resource` con `@export`. Se editan en el Inspector, se duplican baratos, se referencian desde escenas. No los modeles como nodos ni como diccionarios crudos.

```gdscript
# item_data.gd
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 99
@export var scene: PackedScene  # solo el pickup físico en el mundo es un nodo
```

Inventario como datos puros + señal; la UI se reconstruye sola (decoplado total):

```gdscript
# inventory.gd
class_name Inventory
extends Resource

signal changed
@export var slots: Dictionary[StringName, int] = {}  # id -> cantidad (tipado 4.6)

func add(id: StringName, n: int = 1) -> void:
	slots[id] = slots.get(id, 0) + n
	changed.emit()
```

La UI hace `inventory.changed.connect(_rebuild)`. Cambias el almacenamiento sin tocar la UI y al revés. No construyas un mediador entre ambos: la señal **es** el pegamento.

## Máquina de estados (estados que deciden, no un `match` gigante)

Cada estado es un nodo hijo y decide cuándo y a dónde transita. Base abstracta en 4.6:

```gdscript
# state.gd
@abstract class_name State
extends Node

@abstract func enter() -> void
@abstract func physics_update(delta: float) -> void
```

El `StateMachine` solo delega `_physics_process` al estado activo y expone `transition_to(name)`. Conecta señales en `enter()` y desconéctalas en `exit()` para que un estado solo escuche cuando está activo. No centralices las transiciones: las dispersa cada estado a propósito.

## Guardado (ids, no objetos)

Serializa a datos planos (id + cantidad + posición), escribe **JSON en `user://`**, y al cargar busca los ids para reencontrar los Resources. Nunca vuelques objetos `Resource` al archivo de guardado.

```gdscript
func save_game() -> void:
	var data := {"player_pos": var_to_str(player.global_position), "inv": inventory.slots}
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
```

`user://` es la ruta nativa multiplataforma. No inventes tu propia gestión de rutas ni cifres el save el día 1 (`yagni`).

## Diálogo, navegación, combate (delega al motor)

- **Diálogo**: árbol de `Resource` (línea, opciones, condición) recorrido por un nodo simple. Para algo grande, un plugin libre como Dialogic antes que un parser propio.
- **IA / navegación**: `NavigationRegion3D` + `NavigationAgent3D`. El pathfinding y la evitación ya están; tú solo das destinos. No escribas A* a mano.
- **Combate por turnos/acción**: stats en Resources, daño en una función pura (`func apply(dmg: int) -> int`), y señales `health_changed`/`died`. La barra de vida escucha la señal. Sin "CombatManager" omnisciente hasta que dos sistemas lo necesiten de verdad.
- **Audio 3D**: `AudioStreamPlayer3D` da atenuación por distancia gratis.
- **Pies al terreno / mirada a objetivos**: `IKModifier3D`, no math propio.

## Estructura mínima de proyecto libre

```
/scenes      escenas .tscn (player, enemigos, niveles, UI)
/scripts     .gd o .cs por sistema
/resources   .tres: items, stats, diálogos, loot
/autoload    singletons SOLO si son globales de verdad (settings, save)
LICENSE      MIT/GPL para que sea libre de verdad
```

Autoloads (singletons) con moderación: settings y save sí; un `Global` que lo toca todo, no. Cada autoload extra es estado global que ponytail marcará para borrar.

## Límites de este skill

Alcance: arquitectura y decisiones de "qué nodo/recurso usa Godot 4.6 por mí" para un RPG 3D libre. **No** sustituye la documentación oficial de la API ni decide tu game design. Para firmas exactas de métodos, consulta los docs de 4.6. Para nombres de assets, balance o narrativa: eso es tu juego, no este skill. Si una feature que cito cambió en un parche 4.6.x, gana la documentación.

## Fuentes

- [Godot 4.6 — Release oficial](https://godotengine.org/releases/4.6/)
- [Godot 4.6 Complete Guide 2026](https://www.live-laugh-love.world/blog/godot-46-complete-guide-2026/)
- [Godot 4.6: What changes for you — GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)
- [Diccionarios tipados — Godot 4.4 dev snapshot](https://godotengine.org/article/dev-snapshot-godot-4-4-dev-2/)
- [Clases abstractas en GDScript — propuesta #5641](https://github.com/godotengine/godot-proposals/issues/5641)
- [GDScript vs C# en 2026 — StraySpark](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language)
- [C#/.NET en Godot — docs oficiales](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html)
- [Máquina de estados en Godot 4 — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Sistema de inventario y crafteo — StraySpark](https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide)
- [Estado de C# en plataformas — Godot Engine](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/)
- [Concepto ponytail — DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
