# Ejemplos de RPG 3D en Godot 4.6 (estilo ponytail)

Scripts mínimos y tipados que la skill [`../skillgodot4.6.md`](../skillgodot4.6.md)
referencia. Cada uno resuelve un sistema de RPG apoyándose en nodos/Resources
nativos en vez de arquitectura propia. Pégalos en un proyecto Godot 4.6 y
cablea como se indica abajo.

## Archivos

| Archivo | Qué es | Nodo/recurso base |
|---|---|---|
| `player.gd` | Locomoción del personaje | `CharacterBody3D` |
| `item_data.gd` | Definición de item (dato puro) | `Resource` |
| `inventory.gd` | Inventario + señal `changed` | `Resource` (Dictionary tipado) |
| `stats.gd` | Salud/combate + señales | `Resource` |
| `state.gd` | Base abstracta de estado | `@abstract` (4.5+) |
| `state_machine.gd` | Delega al estado activo | `Node` |
| `states/idle_state.gd` | Estado de ejemplo | `State` |
| `states/run_state.gd` | Estado de ejemplo | `State` |
| `save_system.gd` | Guardado JSON en `user://` | autoload |

## Cableado de principio a fin

1. **Input** — en *Project Settings → Input Map* crea las acciones
   `move_left`, `move_right`, `move_forward`, `move_back`, `jump`.
2. **Player** — escena con raíz `CharacterBody3D` + `CollisionShape3D` + malla;
   asigna `player.gd`.
3. **Máquina de estados** — añade un `Node` hijo del player con
   `state_machine.gd`. Cuélgale dos hijos `Node` llamados **exactamente**
   `Idle` y `Run` con `states/idle_state.gd` y `states/run_state.gd`
   (los nombres de nodo son los destinos de `transition_to`).
4. **Inventario** — crea un `Inventory` (`.tres`) y varios `ItemData` (`.tres`).
   En la UI: `inventory.changed.connect(_rebuild)`. Nunca acoples la UI a la
   lógica salvo por la señal.
5. **Stats** — añade un `Stats` (`.tres`) al player/enemigos; la barra de vida
   hace `stats.health_changed.connect(...)` y `stats.died.connect(...)`.
6. **Guardado** — registra `save_system.gd` como autoload llamado `SaveSystem`
   (*Project Settings → Autoload*). Llama `SaveSystem.save_game(player, inv)` /
   `SaveSystem.load_game(player, inv)`.

## Lo que estos ejemplos NO incluyen a propósito (ponytail: `yagni`)

Sin `GameManager` global, sin EventBus propio, sin wrapper de `move_and_slide`,
sin serializar Resources al save, sin A* a mano. Eso lo dan
`NavigationAgent3D`, las señales, `user://` y los nodos del motor. Añádelo solo
cuando un segundo caso real lo pida.
