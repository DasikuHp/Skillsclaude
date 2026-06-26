extends State
## Vuelve a Idle cuando no hay input. La transición vive aquí, no en un match central.

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO:
		machine.transition_to(&"Idle")
