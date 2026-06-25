extends Node
## Autoload "DebugTools". Centraliza custom monitors, backtraces y toggles de
## visualizacion para un RPG en Godot 4.6. Registralo como singleton UNA vez.

# ---------------------------------------------------------------------------
# Custom monitors (firma Godot 4: id: StringName, callable: Callable, args := [])
# El callable DEBE devolver un numero >= 0. El "/" en el id define la categoria.
# ---------------------------------------------------------------------------
func _ready() -> void:
	_register_monitor(&"game/enemies_alive", _count_enemies)
	_register_monitor(&"game/projectile_pool", _pool_size)
	_register_monitor(&"nav/path_cache_size", _path_cache_size)

func _register_monitor(id: StringName, fn: Callable) -> void:
	# Protege contra "Custom monitor 'X' already exists." si el autoload re-corre.
	if not Performance.has_custom_monitor(id):
		Performance.add_custom_monitor(id, fn)

func _exit_tree() -> void:
	for id: StringName in [&"game/enemies_alive", &"game/projectile_pool", &"nav/path_cache_size"]:
		if Performance.has_custom_monitor(id):
			Performance.remove_custom_monitor(id)

func _count_enemies() -> int:
	return get_tree().get_nodes_in_group(&"enemies").size()

func _pool_size() -> int:
	return maxi(0, get_tree().get_nodes_in_group(&"projectiles").size())

func _path_cache_size() -> int:
	return 0  # devuelve Pathfinder.cache.size() en tu proyecto; nunca negativo

# ---------------------------------------------------------------------------
# Backtraces y asserts. print_stack/get_stack solo funcionan conectados al
# servidor de debug (editor / export con Remote Debug). assert() se ELIMINA en
# release: jamas pongas logica con efectos secundarios dentro.
# ---------------------------------------------------------------------------
func apply_damage(amount: int) -> void:
	assert(amount >= 0, "dano negativo: %d" % amount)  # solo condicion pura
	if amount < 0:
		breakpoint  # palabra clave: se versiona en git, viaja con el script
	print_debug("dano aplicado: %d" % amount)  # incluye archivo:linea; mudo en release

func dump_call_stack() -> void:
	print_stack()                       # vuelca al Output (requiere debugger)
	var frames: Array = get_stack()     # Array[Dictionary] {function, line, source}
	for frame: Dictionary in frames:
		print("%s:%d  %s" % [frame.source, frame.line, frame.function])

# ---------------------------------------------------------------------------
# Chequeo de leaks: ejecuta tras N ciclos de combate (p.ej. una tecla de debug).
# Confirma con el ObjectDB Profiler (snapshot diff) en el panel Debugger.
# ---------------------------------------------------------------------------
func check_leaks() -> void:
	print_orphan_nodes()  # lista cada huerfano: clase, nombre, Instance ID
	print("Objects: ", Performance.get_monitor(Performance.OBJECT_COUNT))
	print("Nodes:   ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("Orphans: ", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

# ---------------------------------------------------------------------------
# Visualizacion de fisica/navegacion. Setea ANTES del primer frame fisico; no
# mezcles con el menu Debug > Visible Collision Shapes (godot#64353).
# Desactivalas antes de medir frame time (tienen coste de render).
# ---------------------------------------------------------------------------
func set_debug_visuals(enabled: bool) -> void:
	get_tree().debug_collisions_hint = enabled
	get_tree().debug_navigation_hint = enabled
