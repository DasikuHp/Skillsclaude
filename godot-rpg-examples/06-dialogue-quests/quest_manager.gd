# quest_manager.gd
# Godot 4.6 - Autoload "Quests". Actualizacion dirigida por eventos, sin polling.
# Conectar senales de gameplay, ej: enemy.died.connect(Quests.on_enemy_killed)
extends Node

signal objective_updated(quest: Quest, objective: QuestObjective)
signal quest_completed(quest: Quest)

## Quests activas, fuertemente tipadas (cada una con Array[QuestObjective] dentro).
var active: Array[Quest] = []

func add_quest(quest: Quest) -> void:
	if quest not in active:
		active.append(quest)

func on_enemy_killed(enemy_id: StringName) -> void:
	_progress(QuestObjective.Kind.KILL, enemy_id)

func on_item_collected(item_id: StringName) -> void:
	_progress(QuestObjective.Kind.COLLECT, item_id)

func _progress(kind: QuestObjective.Kind, target: StringName) -> void:
	for q in active:
		for obj in q.objectives:
			if obj.kind == kind and obj.target == target and not obj.is_done():
				obj.progress += 1
				objective_updated.emit(q, obj)
				if q.is_complete():
					quest_completed.emit(q)
