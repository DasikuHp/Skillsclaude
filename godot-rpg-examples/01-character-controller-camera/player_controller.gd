# player_controller.gd
# Controlador de personaje + camara 3a persona para Godot 4.6.
# Jerarquia de escena esperada:
#   Player (CharacterBody3D)  <- este script
#   |-- CollisionShape3D (CapsuleShape3D)
#   |-- Visual (Node3D)            # modelo + AnimationPlayer/AnimationTree
#   `-- CameraPivot (Node3D)       # recibe yaw/pitch del raton
#       `-- SpringArm3D            # camara collision-aware
#           `-- Camera3D
#
# Acciones de input requeridas (Project > Project Settings > Input Map):
#   move_left, move_right, move_forward, move_back, jump
# Notas 4.6:
#   - Jolt es el motor 3D por defecto; CharacterBody3D funciona igual.
#   - get_gravity() existe desde 4.4 y devuelve un Vector3.
class_name PlayerController
extends CharacterBody3D

signal jumped
signal landed

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export_range(0.0005, 0.01, 0.0001) var mouse_sens: float = 0.003
@export var pitch_min: float = -1.2  # rad, mirando hacia abajo
@export var pitch_max: float = 0.4   # rad, mirando hacia arriba
@export var camera_distance: float = 4.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var _pitch: float = 0.0
var _was_on_floor: bool = true

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Configuracion de suelo: valores robustos para terreno irregular de RPG.
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true

	# Configuracion de la camara collision-aware.
	spring_arm.spring_length = camera_distance
	spring_arm.margin = 0.2
	# Excluir el collider del propio Player para que el brazo no colapse sobre el.
	spring_arm.add_excluded_object(get_rid())
	# Shape-cast con esfera pequena: mas suave que raycast, evita pop-in en bordes.
	var s := SphereShape3D.new()
	s.radius = 0.3
	spring_arm.shape = s

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		# Yaw en el pivote, pitch acumulado y clamped.
		camera_pivot.rotate_y(-mm.relative.x * mouse_sens)
		_pitch = clampf(_pitch - mm.relative.y * mouse_sens, pitch_min, pitch_max)
		camera_pivot.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	# Gravedad SOLO en el aire (no acumular en suelo, rompe is_on_floor en bordes).
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		jumped.emit()

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Direccion relativa al yaw del pivote de camara, aplanada al plano XZ.
	var dir := (camera_pivot.global_basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized()

	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		# Resetear SOLO los ejes XZ que controlamos, nunca la velocidad entera.
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	# move_and_slide() lee y actualiza 'velocity'; en 4.x no acepta argumento.
	move_and_slide()

	var grounded := is_on_floor()
	if grounded and not _was_on_floor:
		landed.emit()
	_was_on_floor = grounded
