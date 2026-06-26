# vfx_pool.gd — Godot 4.6 — autoload ("VfxPool")
# Pool de VFX pre-calentado. Evita el lag spike de compilacion de shader (GH-87891)
# y el churn de instanciar/liberar por golpe. Reciclaje idempotente (ATASCO #3).
extends Node

# typed Dictionary 4.6: key -> Array de GPUParticles3D libres
var _pools: Dictionary[StringName, Array] = {}

func _make(scene: PackedScene) -> GPUParticles3D:
	var p: GPUParticles3D = scene.instantiate() as GPUParticles3D
	assert(p != null, "La escena de VFX debe tener un GPUParticles3D en la raiz")
	add_child(p)
	p.one_shot = true
	p.emitting = false
	# PRE-CALENTAR: paga la compilacion del shader al cargar, no en combate.
	p.restart()
	p.emitting = false
	return p

func _acquire(key: StringName, scene: PackedScene) -> GPUParticles3D:
	var bucket: Array = _pools.get_or_add(key, [])
	if bucket.is_empty():
		return _make(scene)
	return bucket.pop_back()

func play(key: StringName, scene: PackedScene, world_pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	var p: GPUParticles3D = _acquire(key, scene)
	p.global_position = world_pos
	if not normal.is_equal_approx(Vector3.UP) and not normal.is_zero_approx():
		p.look_at(world_pos + normal, Vector3.UP)
	p.restart()

	# Reciclaje idempotente: puede llegar por 'finished' O por el Timer de respaldo.
	var done: Array[bool] = [false]
	var ret: Callable = func() -> void:
		if done[0]:
			return
		done[0] = true
		p.emitting = false
		(_pools[key] as Array).push_back(p)

	# ATASCO #3: 'finished' puede no llegar; respaldar con Timer.
	p.finished.connect(ret, CONNECT_ONE_SHOT)
	var safety: float = p.lifetime * 1.5 / maxf(p.speed_scale, 0.01)
	get_tree().create_timer(safety).timeout.connect(ret, CONNECT_ONE_SHOT)
