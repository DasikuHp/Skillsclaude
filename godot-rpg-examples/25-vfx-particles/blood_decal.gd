# blood_decal.gd — Godot 4.6
# Decal de sangre orientado a la superficie y desvanecido. Adjuntar a un Decal
# con texture_albedo ya asignado en la escena (sin textura = invisible, sin error).
class_name BloodDecal
extends Decal

@export var lifetime: float = 20.0
@export var fade_seconds: float = 5.0

func splat(hit_pos: Vector3, surface_normal: Vector3) -> void:
	# Pequeno offset para evitar z-fighting con la superficie.
	global_position = hit_pos + surface_normal * 0.05
	# El Decal proyecta por su eje -Y LOCAL: hay que orientar -Y hacia la superficie.
	# look_at apunta -Z al objetivo, asi que rotamos -90 en X local para pasar -Z -> -Y.
	if not surface_normal.is_equal_approx(Vector3.UP):
		look_at_from_position(global_position, global_position - surface_normal, Vector3.UP)
		rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	albedo_mix = 1.0  # en 0 el decal es invisible aunque la textura cargue
	modulate = Color(1.0, 1.0, 1.0, randf_range(0.7, 1.0))
	size = Vector3(randf_range(0.4, 0.8), 1.0, randf_range(0.4, 0.8))
	distance_fade_enabled = true

	var t: Tween = create_tween()
	t.tween_interval(lifetime)
	t.tween_property(self, "modulate:a", 0.0, fade_seconds)
	t.tween_callback(queue_free)
