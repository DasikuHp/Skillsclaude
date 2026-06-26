@tool
extends EditorPlugin
## Mini EditorPlugin (addons/dungeon/plugin.gd). Compile-ready en 4.6.
## Registra un tipo custom + un dock, y limpia TODO simétricamente en _exit_tree.
## Sin @tool en la primera línea, el plugin NO carga y no hay error obvio.

const TYPE_NAME := "DungeonRoom"

var _dock: Control

func _enter_tree() -> void:
	# add_custom_type(type, base, script, icon): aparece en "Add Node" con icono propio,
	# y desaparece al desactivar el plugin.
	add_custom_type(
		TYPE_NAME, "Node3D",
		preload("res://addons/dungeon/dungeon_room.gd"),
		preload("res://addons/dungeon/icon.svg"))
	_dock = preload("res://addons/dungeon/dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	# Limpieza OBLIGATORIA y simétrica: sin esto -> fuga de memoria / tipo duplicado.
	remove_control_from_docks(_dock)
	_dock.queue_free()
	_dock = null
	remove_custom_type(TYPE_NAME)
