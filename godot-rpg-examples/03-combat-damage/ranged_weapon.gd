# ranged_weapon.gd
# Hitscan ranged sin nodo extra usando una consulta directa al espacio fisico.
# Mejor que RayCast3D cuando disparas varias balas por frame.
# HURTBOX_LAYER debe ser el bit de la capa donde viven las hurtboxes.
extends Node3D

const HURTBOX_LAYER := 4  # 1 << 2 -> capa 3 "enemy_hurtbox"

@export var damage_info: DamageInfo
@export var range_distance: float = 40.0

func fire() -> void:
	var from := global_position
	var to := from - global_transform.basis.z * range_distance  # -Z = adelante
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = HURTBOX_LAYER
	var hit: Dictionary = space.intersect_ray(q)  # {} si no golpea nada
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider.has_method("take_damage"):
		damage_info.source = self
		collider.take_damage(damage_info)
