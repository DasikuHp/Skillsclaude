# res://autoload/game_state.gd
# Autoload nº2. SOLO estado verdaderamente global y serializable. NO es un
# "cajon de sastre": el estado local de escena se queda en la escena.
extends Node

var gold: int = 0
var party: Array[Resource] = []                     # typed array (GDScript 2.0)
var flags: Dictionary[StringName, bool] = {}        # typed Dictionary[K,V] (desde 4.4)

func _ready() -> void:
	# Conectar a EventBus en _ready (no en _init): aqui EventBus ya existe
	# porque va antes en el bloque [autoload].
	EventBus.item_picked.connect(_on_item_picked)
	EventBus.flag_changed.connect(_on_flag_changed)

func set_flag(flag: StringName, value: bool) -> void:
	flags[flag] = value
	EventBus.flag_changed.emit(flag, value)

func _on_item_picked(item_id: StringName, amount: int) -> void:
	print("[GameState] recogido %s x%d" % [item_id, amount])

func _on_flag_changed(flag: StringName, value: bool) -> void:
	flags[flag] = value
