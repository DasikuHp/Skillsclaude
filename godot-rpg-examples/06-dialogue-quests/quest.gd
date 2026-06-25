# quest.gd
# Godot 4.6 - Quest y sus objetivos como Resource. Datos serializables (.tres).
class_name QuestObjective
extends Resource

enum Kind { KILL, COLLECT, TALK, REACH }

@export var kind: Kind = Kind.KILL
@export var target: StringName = &""
@export var required: int = 1
@export var progress: int = 0

func is_done() -> bool:
	return progress >= required
