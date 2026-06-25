# quest_manager.gd
# Godot 4.6 - Autoload "Quests". Actualizacion dirigida por eventos, sin polling.
# Conectar senales de gameplay, ej: enemy.died.connect(Quests.on_enemy_killed)
extends Node

signal objective_updated(quest: Resource, objective: QuestObjective)
signal quest_completed(quest: Resource)

## active contiene Resources de tipo Quest (Array[QuestObjective] dentro).
var active: Array[Resource] = []

func add_quest(quest: Resource) -> void:
	if quest not in active:
		active.append(quest)

func on_enemy_killed(enemy_id: StringName) -> void:
	_progress(QuestObjective.Kind.KILL, enemy_id)

func on_item_collected(item_id: StringName) -> void:
	_progress(QuestObjective.Kind.COLLECT, item_id)

func _progress(kind: QuestObjective.Kind, target: StringName) -> void:
	for q in active:
		var objectives: Array = q.get("objectives")
		for obj: QuestObjective in objectives:
			if obj.kind == kind and obj.target == target and not obj.is_done():
				obj.progress += 1
				objective_updated.emit(q, obj)
				if _is_complete(objectives):
					quest_completed.emit(q)

func _is_complete(objectives: Array) -> bool:
	return objectives.all(func(o: QuestObjective) -> bool: return o.is_done())
