## Notas de investigación — Dominio #7: IA enemiga y navegación (Godot 4.6)

### Arquitectura nativa
- La pila de navegación 3D de 4.6 es la misma arquitectura de servidor de 4.3–4.5. `NavigationServer3D` NO se rediseñó en 4.6 y sigue marcado **experimental** en docs.
- Patrón canónico del enemigo: `CharacterBody3D` (raíz) + `NavigationAgent3D` (hijo) + `Timer` (repath) + opcional `NavigationObstacle3D`. La geometría navegable la define `NavigationRegion3D` con un `NavigationMesh` horneado.
- API de alto nivel `NavigationAgent3D` (verificada en docs stable + WebSearch jun-2026):
  - `target_position`, `get_next_path_position()`, `is_navigation_finished()`, `is_target_reachable()`, `distance_to_target()`, `set_velocity()`.
  - Señales: `velocity_computed(safe_velocity)`, `target_reached`, `navigation_finished`, `waypoint_reached`.
  - Avoidance: `avoidance_enabled`, `radius`, `neighbor_distance`, `max_neighbors`, `time_horizon_agents`, `max_speed`.
- Capa baja: `NavigationServer3D.map_get_path(map, origin, target, optimize, navigation_layers=1) -> PackedVector3Array`. Vacío si no hay ruta.

### Confirmaciones vía WebSearch (jun-2026)
- WebSearch confirma textualmente: "velocity_computed signal only works if collision avoidance is enabled; otherwise the signal is not emitted" y que `get_next_path_position()` maneja avoidance/emite señales al terminar. NavigationAgent3D sigue "experimental".
- LimboAI: confirmado asset 4852 = build **4.6+** en el Asset Library; repo limbonaut/limboai activo 2026, MIT, C++ con módulo o GDExtension, tasks/states en GDScript.

### Pitfalls clave
1. Sincronización DIFERIDA del servidor → esperar `await get_tree().physics_frame` antes del primer target. Causa #1 de "no se mueve".
2. `get_next_path_position()` debe llamarse cada frame físico tras setear target.
3. `velocity_computed` solo con `avoidance_enabled = true`. Sin avoidance, aplicar velocity directo.
4. Avoidance descarta Y al terminar nav → reaplicar `velocity.y` (issue #108252).
5. `map_get_path` vacío en C# antes de sincronizar (issue #82209) → `await PhysicsFrame`.
6. `NavigationObstacle3D` solo avoidance local, no replanifica path global.
7. Guardar paths vacíos con `is_empty()`/`is_navigation_finished()`.

### 4.6 específico
- 4.6.1: `map_get_closest_point_normal` ahora normalizado; hornear navmesh de GridMap colliders más rápido.
- Gotcha C#: track names AnimationPlayer `String -> StringName` en 4.6 → recompilar ensamblado al migrar de 4.5.

### Addons
- Navegación: nativo siempre.
- FSM pocos estados: enum + match propio.
- BT complejos: LimboAI (asset 4852, 4.6+).
- Beehave: sin confirmación 4.6, no recomendado.

## Fuentes
- https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html
- https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html
- https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_introduction_3d.html
- https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationmeshes.html
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationpaths.html
- https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationobstacles.html
- https://docs.godotengine.org/en/stable/classes/class_navigationobstacle3d.html
- https://github.com/godotengine/godot-proposals/issues/5013
- https://github.com/godotengine/godot/issues/47337
- https://github.com/godotengine/godot/issues/81761
- https://github.com/godotengine/godot/issues/82209
- https://github.com/godotengine/godot/issues/108252
- https://forum.godotengine.org/t/solved-navigationagent3d-get-next-path-position-is-not-working/91973
- https://forum.godotengine.org/t/navigation-agent-empty-path/73690
- https://forum.godotengine.org/t/navigationserver3d-map-get-path-dont-give-correct-path/90818
- https://github.com/emagood/PathfindingGodot-3D
- https://github.com/godot-addons/godot-finite-state-machine
- https://github.com/limbonaut/limboai
- https://godotengine.org/asset-library/asset/4852
- https://codingquests.io/blog/godot-4-enemy-ai-tutorial
- https://www.danieltperry.me/post/godot-navigation/
- https://gameidea.org/2024/12/13/using-godot-navigation-system-for-path-finding/
- https://www.summerengine.com/blog/how-to-make-ai-in-godot
- https://godotengine.org/article/maintenance-release-godot-4-6-1/
