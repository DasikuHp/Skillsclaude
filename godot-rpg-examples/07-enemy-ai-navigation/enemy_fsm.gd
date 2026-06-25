extends CharacterBody3D
## enemy_fsm.gd
## FSM enum + match para un enemigo de RPG (idle/patrol/chase/attack).
## Godot 4.6 - cero dependencias, navegacion nativa via NavigationAgent3D.
##
## Escena:
##   CharacterBody3D (este script)
##   |- NavigationAgent3D
##   |- DetectionArea (Area3D)   -> body_entered / body_exited
##   |- AttackRange (Area3D)     -> body_entered / body_exited
##   |- CollisionShape3D

enum State { IDLE, PATROL, CHASE, ATTACK }

@export var speed: float = 4.0
@export var gravity: float = 9.8
@export var patrol_points: Array[Node3D] = []
@export var state: State = State.PATROL

@onready var _agent: NavigationAgent3D = $NavigationAgent3D

var _target: Node3D
var _patrol_index: int = 0

# Tabla de nombres para depurar transiciones (Dictionary tipado 4.6).
var _state_names: Dictionary[State, StringName] = {
	State.IDLE: &"idle",
	State.PATROL: &"patrol",
	State.CHASE: &"chase",
	State.ATTACK: &"attack",
}

func _ready() -> void:
	call_deferred("_setup")

func _setup() -> void:
	await get_tree().physics_frame
	_goto_next_patrol_point()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		State.IDLE:   _move_to_agent(0.0)
		State.PATROL: _do_patrol()
		State.CHASE:  _do_chase()
		State.ATTACK: _move_to_agent(0.0)

	move_and_slide()

func _do_patrol() -> void:
	if _agent.is_navigation_finished():
		_goto_next_patrol_point()
	_move_to_agent(speed)

func _do_chase() -> void:
	if _target and _agent.is_target_reachable():
		_agent.target_position = _target.global_position
	_move_to_agent(speed)

func _move_to_agent(move_speed: float) -> void:
	if _agent.is_navigation_finished() or move_speed == 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next: Vector3 = _agent.get_next_path_position()
	var dir: Vector3 = global_position.direction_to(next)
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

func _goto_next_patrol_point() -> void:
	if patrol_points.is_empty():
		state = State.IDLE
		return
	_agent.target_position = patrol_points[_patrol_index].global_position
	_patrol_index = (_patrol_index + 1) % patrol_points.size()

func _change_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_target = body
		_change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == _target:
		_target = null
		_change_state(State.PATROL)
		_goto_next_patrol_point()

func _on_attack_range_body_entered(body: Node3D) -> void:
	if body == _target:
		_change_state(State.ATTACK)

func _on_attack_range_body_exited(body: Node3D) -> void:
	if body == _target:
		_change_state(State.CHASE)
