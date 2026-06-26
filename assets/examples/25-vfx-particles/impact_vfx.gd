# impact_vfx.gd — Godot 4.6
# Adjuntar a un GPUParticles3D guardado en una escena con one_shot=true.
# Emisor one-shot de impacto disparado por una senal de combate.
class_name ImpactVfx
extends GPUParticles3D

func _ready() -> void:
	one_shot = true
	emitting = false
	# ATASCO #1: AABB amplio explicito para que NO lo culleen al moverse la camara.
	# (equivalente por codigo del boton "Particles -> Generate AABB" del editor)
	visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	extra_cull_margin = 4.0

func play_at(world_pos: Vector3, surface_normal: Vector3 = Vector3.UP) -> void:
	global_position = world_pos
	# Evitar "Up vector and direction are aligned" si la normal es paralela al up.
	if not surface_normal.is_equal_approx(Vector3.UP) and not surface_normal.is_zero_approx():
		look_at(world_pos + surface_normal, Vector3.UP)
	# ATASCO #2: re-disparar con restart(), NUNCA con emitting = true.
	restart()
