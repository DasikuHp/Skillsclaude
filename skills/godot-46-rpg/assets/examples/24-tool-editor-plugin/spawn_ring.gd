@tool
extends Node3D
class_name SpawnRing
## Tool script SEGURO (compile-ready en Godot 4.6).
## Visualiza puntos de spawn en el editor; genera enemigos solo en runtime.
## Demuestra: guardia is_editor_hint, setter con is_node_ready, @export_tool_button,
## y nodos preview SIN owner (no se guardan en el .tscn).

@export var radius: float = 5.0:
	set(value):
		radius = value
		_rebuild()                       # reactividad por setter, no por _process

@export var count: int = 8:
	set(value):
		count = maxi(value, 1)           # validar SIEMPRE: el inspector permite 0/negativos
		_rebuild()

# Botón nativo de inspector (4.4+). El 2o arg nombra un icono de editor/icons (opcional).
@export_tool_button("Regenerar puntos", "Reload") var _regen: Callable = _rebuild

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()                       # en editor: solo dibujar preview
		return
	_spawn_enemies()                     # en juego: lógica real

func _rebuild() -> void:
	if not is_node_ready():              # evita correr durante deserializacion de la escena
		return
	# limpieza idempotente: borra lo viejo antes de crear (evita acumular duplicados)
	for c in get_children():
		if c.is_in_group(&"generated"):
			c.free()                     # free() inmediato en editor; no queue_free
	for i in count:
		var angle := TAU * i / float(count)
		var m := Marker3D.new()
		m.add_to_group(&"generated")
		m.position = Vector3(cos(angle), 0.0, sin(angle)) * radius
		add_child(m)
		# Sin owner -> preview/visual, NO se guarda en el .tscn (intencional).
		# Para bakear: m.owner = get_tree().edited_scene_root (add_child PRIMERO, owner DESPUES).

func _spawn_enemies() -> void:
	pass  # lógica de juego (solo runtime)
