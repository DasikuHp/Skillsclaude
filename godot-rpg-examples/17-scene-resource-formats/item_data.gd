@tool
class_name ItemData
extends Resource

## Recurso de datos de item para un RPG. Usable como .tres.

@export var display_name: StringName = &""
@export var max_stack: int = 99
@export var damage: int = 0
@export var icon: Texture2D
@export var stats: Dictionary[StringName, int] = {}
