@tool
extends GridMap
class_name DungeonGrid
## Generador procedural 3D por código (compile-ready en Godot 4.6).
## GridMap serializa sus propias celdas: NO necesita owner por celda.
## Requiere una MeshLibrary asignada en la propiedad 'mesh_library' del inspector.

@export var dungeon_seed: int = 1337
@export_range(8, 64) var map_size: int = 24
@export var room_count: int = 12

@export_tool_button("Generar mazmorra") var _gen: Callable = generate

func generate() -> void:
	if not Engine.is_editor_hint() and not is_node_ready():
		return
	if mesh_library == null:
		push_error("DungeonGrid: asigna una MeshLibrary en 'mesh_library'.")
		return
	# item es un ID del MeshLibrary, NO un índice arbitrario.
	var floor_id := mesh_library.find_item_by_name("floor")
	var wall_id := mesh_library.find_item_by_name("wall")
	if floor_id < 0 or wall_id < 0:
		push_error("MeshLibrary sin items 'floor'/'wall'.")
		return

	clear()                                  # borra todas las celdas previas
	var rng := RandomNumberGenerator.new()
	rng.seed = dungeon_seed                  # determinismo: clave para debug ciego
	var rooms: Array[Rect2i] = []

	for i in room_count:
		var w := rng.randi_range(3, 7)
		var h := rng.randi_range(3, 7)
		var x := rng.randi_range(1, map_size - w - 1)
		var z := rng.randi_range(1, map_size - h - 1)
		var r := Rect2i(x, z, w, h)
		if rooms.any(func(o: Rect2i) -> bool: return o.grow(1).intersects(r)):
			continue                         # rechaza solapes
		_carve_room(r, floor_id)
		if not rooms.is_empty():
			_carve_corridor(rooms.back().get_center(), r.get_center(), floor_id)
		rooms.append(r)

	# Verificación ciega (sin GUI): asegura que algo se generó.
	assert(get_used_cells().size() > 0, "GridMap vacío tras generar")

func _carve_room(r: Rect2i, floor_id: int) -> void:
	for x in range(r.position.x, r.end.x):
		for z in range(r.position.y, r.end.y):
			set_cell_item(Vector3i(x, 0, z), floor_id)

func _carve_corridor(a: Vector2i, b: Vector2i, floor_id: int) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		set_cell_item(Vector3i(x, 0, a.y), floor_id)
	for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		set_cell_item(Vector3i(b.x, 0, z), floor_id)
