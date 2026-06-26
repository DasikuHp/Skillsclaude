class_name StateMachine
extends Node
## Solo delega _physics_process al estado activo y expone transition_to().
## Los estados son nodos hijos; el estado inicial es el primer hijo.

var current: State

func _ready() -> void:
	for child in get_children():
		if child is State:
			(child as State).machine = self
	current = get_child(0) as State
	current.enter()

func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)

func transition_to(state_name: StringName) -> void:
	var next := get_node_or_null(NodePath(state_name)) as State
	if next == null or next == current:
		return
	current.exit()
	current = next
	current.enter()
