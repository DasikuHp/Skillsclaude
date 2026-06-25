extends CharacterBody3D
## enemy_chaser.gd
## Enemigo de RPG que persigue a un objetivo usando NavigationAgent3D nativo.
## Godot 4.6 - sin avoidance (caso comun: pocos enemigos).
##
## Escena recomendada:
##   CharacterBody3D (este script)
##   |- NavigationAgent3D
##   |- RepathTimer (Timer, autostart=true, wait_time=0.3)
##   |- CollisionShape3D
##
## Requiere un NavigationRegion3D horneado en la escena padre.

@export var speed: float = 4.0
@export var gravity: float = 9.8
@export var target: Node3D

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _repath_timer: Timer = $RepathTimer

func _ready() -> void:
	# El NavigationServer sincroniza de forma DIFERIDA. Si fijamos el target
	# en _ready() sin esperar, get_next_path_position() devuelve nuestra propia
	# posicion y el enemigo no se mueve. Esperar un frame fisico primero.
	_repath_timer.timeout.connect(_on_repath)
	call_deferred("_setup")

func _setup() -> void:
	await get_tree().physics_frame
	_refresh_target()

func _on_repath() -> void:
	_refresh_target()

func _refresh_target() -> void:
	if target and _agent.is_target_reachable():
		_agent.target_position = target.global_position

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _agent.is_navigation_finished():            # GUARDA: nada que hacer
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Obligatorio cada frame fisico tras setear target: actualiza el path.
	var next: Vector3 = _agent.get_next_path_position()
	var dir: Vector3 = global_position.direction_to(next)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
