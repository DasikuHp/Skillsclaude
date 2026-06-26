# hit_box_3d.gd
# Hitbox de melee dirigida por animacion. Area3D que INFLIGE dano.
# La AnimationPlayer llama start_attack()/end_attack() en keyframes (Call Method Track).
# El CollisionShape3D hijo "HitShape" debe arrancar con disabled = true.
#
# Capas recomendadas (ningun cast en runtime, el filtrado lo hacen las capas):
#   collision_layer = capa "player_hitbox", collision_mask = capa "enemy_hurtbox", monitoring = true
# Este hitbox ES el que escucha y llama take_damage; necesita la capa de la hurtbox
# en su mask y monitoring=true. La hurtbox solo se deja detectar (monitorable=true, mask=0).
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
	# owner solo apunta a la victima si la hurtbox vive dentro de una escena
	# instanciada cuyo root lleva take_damage; si se anadio en runtime sin owner,
	# area.owner es null. Fallback robusto al padre directo.
	var victim: Node = area.owner if area.owner != null else area.get_parent()
	if victim == null:
		return
	var id := victim.get_instance_id()
	if _already_hit.has(id):       # evita el doble golpe en el mismo frame
		return
	_already_hit[id] = true
	if victim.has_method("take_damage"):
		# source es un campo transitorio por golpe: duplicamos para no mutar el
		# .tres compartido entre atacantes (aliasing). Ver Resource.duplicate().
		var info := damage_info.duplicate() as DamageInfo
		info.source = owner as Node3D
		victim.take_damage(info)
