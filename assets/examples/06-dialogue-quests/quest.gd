# quest.gd
# Godot 4.6 - Quest como Resource. Agrupa objetivos tipados (Array[QuestObjective]).
# Un solo class_name por archivo: QuestObjective vive en quest_objective.gd.
class_name Quest
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var objectives: Array[QuestObjective] = []

func is_complete() -> bool:
	return objectives.all(func(o: QuestObjective) -> bool: return o.is_done())
