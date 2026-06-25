extends Node3D

# --- 1. Nil / null instance: %UniqueName tipado para refs propias ---
# ROTO:  @onready var hud = $UI/HUD            # ruta fragil + sin tipo -> null silencioso
@onready var hud: Control = %HUD               # Scene Unique Name: sobrevive al re-parenting
@onready var player: CharacterBody3D = %Player

var target: Node3D                              # ref que puede morir
@export var speed := 6.0
@export var gravity := 18.0
var dir := Vector3.ZERO

func _ready() -> void:
	# Refs CRUZADAS (hermano/autoload/dinamico): difiere, no las toques en _ready (bottom-up)
	_wire_cross_refs.call_deferred()

func _wire_cross_refs() -> void:
	var boss := get_tree().get_first_node_in_group("boss")
	if is_instance_valid(boss):                 # guard canonico
		_connect_once(boss.tree_exiting, _on_boss_gone)

func _connect_once(s: Signal, c: Callable) -> void:
	if not s.is_connected(c):                   # guard por identidad de Callable
		s.connect(c)

func attack() -> void:
	# tras queue_free el objeto NO se vuelve null: valida antes de tocar
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		target.take_damage(10)
	else:
		target = null

func _on_boss_gone() -> void:
	pass

# --- 2. await sobre senal que puede NO emitirse: timeout de seguridad ---
func open_chest(anim: AnimationPlayer) -> void:
	anim.play(&"open")                          # &"..." = StringName literal (4.6)
	var timer := get_tree().create_timer(2.0)
	var done := [false]
	anim.animation_finished.connect(func(_n): done[0] = true, CONNECT_ONE_SHOT)
	await timer.timeout                          # salida garantizada aunque la senal nunca llegue
	if done[0]:
		pass

# --- 3. Fisica en _physics_process, sin doble delta ---
func _physics_process(delta: float) -> void:
	velocity.x = dir.x * speed                   # SIN delta: move_and_slide lo aplica
	velocity.z = dir.z * speed
	velocity.y -= gravity * delta                # aceleracion SI usa delta
	move_and_slide()

# --- 4. Mutar coleccion mientras se itera: filtra en vez de erase dentro del for ---
func cull_dead(enemies: Array[Node3D]) -> Array[Node3D]:
	return enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())

# --- 5. typed Dictionary 4.6: JSON y lecturas seguras ---
var loot: Dictionary[String, int] = {"gold": 10}

func load_config(txt: String) -> void:
	# ROTO: var d: Dictionary[String,int] = JSON.parse_string(txt) # devuelve Dictionary[Variant,Variant]
	var raw: Variant = JSON.parse_string(txt)
	if raw is Dictionary:
		for k in raw:
			loot[String(k)] = int(raw[k])
	var g: int = loot.get("gold", 0)             # get(), NO loot["gold"] (regresion 4.6 GH-115624)
