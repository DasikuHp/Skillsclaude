extends CharacterBody3D
## Locomoción RPG en Godot 4.6: AnimationTree (BlendSpace2D + StateMachine),
## root motion vía accumulator, e IK de pie con TwoBoneIK3D (API por índice).
##
## Estructura de escena esperada:
##   Player (CharacterBody3D) [este script]
##   ├── Visual
##   │   └── Skeleton3D
##   │       ├── FootIK_L (TwoBoneIK3D)
##   │       └── FootTarget_L (Marker3D)
##   ├── AnimationPlayer
##   ├── AnimationTree  (tree_root = AnimationNodeStateMachine con un
##   │                   AnimationNodeBlendSpace2D llamado "Locomotion")
##   └── FootRay_L (RayCast3D apuntando hacia abajo)

@export var move_speed: float = 4.0
@export_node_path("AnimationTree") var tree_path: NodePath

@onready var tree: AnimationTree = get_node(tree_path)
@onready var skel: Skeleton3D = $Visual/Skeleton3D
@onready var sm: AnimationNodeStateMachinePlayback = tree["parameters/playback"]
@onready var foot_ik_l: TwoBoneIK3D = $Visual/Skeleton3D/FootIK_L
@onready var foot_target_l: Marker3D = $Visual/Skeleton3D/FootTarget_L
@onready var foot_ray_l: RayCast3D = $FootRay_L

# En 4.6 los parámetros/tracks son StringName y NO autoconvierten (#64171): cachéalos.
const ST_BLEND: StringName = &"parameters/Locomotion/blend_position"
const ST_ATTACK: StringName = &"attack"
const ST_IDLE: StringName = &"idle"

# Diccionario tipado 4.6: acción de input -> estado de animación.
var action_to_state: Dictionary[StringName, StringName] = {
	&"slash": &"attack",
	&"roll": &"dodge",
}

signal attack_started

func _ready() -> void:
	tree.active = true
	# Configurar la cadena IK (setting 0) por código (también puede hacerse en el editor).
	foot_ik_l.set_setting_count(1)
	foot_ik_l.set_root_bone_name(0, &"UpperLeg.L")
	foot_ik_l.set_middle_bone_name(0, &"LowerLeg.L")
	foot_ik_l.set_end_bone_name(0, &"Foot.L")
	foot_ik_l.set_target_node(0, foot_ik_l.get_path_to(foot_target_l))
	foot_ik_l.active = false

func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"left", &"right", &"back", &"forward")
	tree.set(ST_BLEND, input)
	_apply_root_motion(delta)
	move_and_slide()
	_update_foot_ik()

func _apply_root_motion(delta: float) -> void:
	# Rotación absoluta vía accumulator (evita el bug incremental #93821 / #95688).
	var rot := tree.get_root_motion_rotation_accumulator()
	var pos: Vector3 = tree.get_root_motion_position()  # delta local, NO velocidad
	transform.basis = Basis(rot) * transform.basis.orthonormalized()
	var motion := transform.basis * pos
	velocity = (motion / delta) if delta > 0.0 else Vector3.ZERO

func _update_foot_ik() -> void:
	if foot_ray_l.is_colliding():
		foot_target_l.global_position = foot_ray_l.get_collision_point()
		foot_ik_l.active = true
	else:
		foot_ik_l.active = false

func attack() -> void:
	sm.travel(ST_ATTACK)   # A* sobre las transiciones del grafo
	attack_started.emit()

func play_action(action: StringName) -> void:
	if action_to_state.has(action):
		sm.travel(action_to_state[action])
