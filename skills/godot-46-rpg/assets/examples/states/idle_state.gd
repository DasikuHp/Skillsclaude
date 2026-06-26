extends State
## Estado de ejemplo. Conecta señales en enter(), desconéctalas en exit():
## así el estado solo escucha cuando está activo.

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
		machine.transition_to(&"Run")
