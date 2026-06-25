# hit_box_3d.gd
# Hitbox de melee dirigida por animacion. Area3D que INFLIGE dano.
# La AnimationPlayer llama start_attack()/end_attack() en keyframes (Call Method Track).
# El CollisionShape3D hijo "HitShape" debe arrancar con disabled = true.
#
# Capas recomendadas (ningun cast en runtime, el filtrado lo hacen las capas):
#   collision_layer = capa "player_hitbox", collision_mask = 0
# La hurtbox del enemigo escucha; este hitbox solo necesita ser monitorable/visible.
class_name HitBox3D
extends Area3D

@export var damage_info: DamageInfo

# Blacklist por swing: un golpe por victima. Clave = instance_id de la victima.
var _already_hit: Dictionary[int, bool] = {}

@onready var _shape: CollisionShape3D = $HitShape

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func start_attack() -> void:
	_already_hit.clear()          # limpiar ANTES de habilitar el shape
	_shape.disabled = false       # habilita el SHAPE, nunca el Area3D entero

func end_attack() -> void:
	_shape.disabled = true

func _on_area_entered(area: Area3D) -> void:
	var victim: Node = area.owner
	if victim == null:
		return
	var id := victim.get_instance_id()
	if _already_hit.has(id):       # evita el doble golpe en el mismo frame
		return
	_already_hit[id] = true
	if victim.has_method("take_damage"):
		damage_info.source = owner as Node3D
		victim.take_damage(damage_info)
