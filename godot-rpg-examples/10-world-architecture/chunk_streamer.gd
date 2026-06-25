# chunk_streamer.gd
# Streaming open-world minimo y nativo para Godot 4.6: carga aditiva de chunks
# (PackedScene + add_child) por proximidad del jugador, y libera los lejanos.
#
# Para un RPG open-world masivo, considera reutilizar el addon
# DigitallyTailored/Godot-Open-World-Database en vez de extender esto.
# Aqui se muestra el patron base nativo: instantiate() + add_child() coexisten
# con la escena actual sin reemplazar el arbol.
extends Node3D

@export var player_path: NodePath
@export var chunk_size: float = 64.0
@export var load_radius: int = 1          # en chunks (1 => grid 3x3)
@export var chunk_scene_template: String = "res://world/chunks/chunk_%d_%d.tscn"

# Diccionario tipado 4.6: coord de chunk -> nodo instanciado.
var _loaded: Dictionary[Vector2i, Node3D] = {}
var _player: Node3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D

func _process(_delta: float) -> void:
	if _player == null:
		return
	var center := _world_to_chunk(_player.global_position)
	_ensure_loaded(center)
	_unload_far(center)

func _world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / chunk_size)), int(floor(pos.z / chunk_size)))

func _ensure_loaded(center: Vector2i) -> void:
	for x in range(center.x - load_radius, center.x + load_radius + 1):
		for y in range(center.y - load_radius, center.y + load_radius + 1):
			var coord := Vector2i(x, y)
			if _loaded.has(coord):
				continue
			var path := chunk_scene_template % [coord.x, coord.y]
			if not ResourceLoader.exists(path):
				continue
			var packed: PackedScene = load(path)
			var inst: Node3D = packed.instantiate()
			add_child(inst)               # carga aditiva: no reemplaza el arbol
			_loaded[coord] = inst

func _unload_far(center: Vector2i) -> void:
	var to_free: Array[Vector2i] = []
	for coord in _loaded.keys():
		if absi(coord.x - center.x) > load_radius or absi(coord.y - center.y) > load_radius:
			to_free.append(coord)
	for coord in to_free:
		_loaded[coord].queue_free()
		_loaded.erase(coord)
