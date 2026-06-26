extends CharacterBody3D
## Jugador server-authoritative del mundo, con interpolación cliente.
## El nombre del nodo == peer_id (lo pone el spawner).

const SPEED := 5.0

@export var sync_position: Vector3  # variable espejo: el Synchronizer NO interpola position
@export var health: int = 100

@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _enter_tree() -> void:
	# Autoridad determinista, idéntica en todos los peers. NUNCA en _ready (GH-75067).
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	_setup_sync()

func _setup_sync() -> void:
	# Construir el SceneReplicationConfig por código (esquiva GH-84793 del editor).
	var cfg := SceneReplicationConfig.new()
	var np := NodePath(".:sync_position")  # "Nodo:propiedad", relativo al synchronizer
	cfg.add_property(np)
	cfg.property_set_spawn(np, true)
	cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var hp := NodePath(".:health")
	cfg.add_property(hp)
	cfg.property_set_replication_mode(hp, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 0.05  # 20 Hz

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		velocity.x = Input.get_axis("left", "right") * SPEED
		velocity.z = Input.get_axis("up", "down") * SPEED
		velocity.y -= 9.8 * delta
		move_and_slide()
		sync_position = global_position  # la autoridad publica
	else:
		# Interpolación suave hacia el valor recibido (Synchronizer no interpola; GH-7280)
		global_position = global_position.lerp(sync_position, 1.0 - exp(-15.0 * delta))

# Cliente pide -> server valida -> server aplica y replica el resultado.
@rpc("any_peer", "call_local", "reliable")
func request_attack(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()  # no spoofeable; valida ownership/rango
	if sender != name.to_int():
		return
	apply_damage.rpc(target_id, 10)

@rpc("authority", "call_local", "reliable")
func apply_damage(target_id: int, dmg: int) -> void:
	if multiplayer.is_server():
		health -= dmg  # el server es authority -> ON_CHANGE replica health a todos
