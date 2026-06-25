## Notas de investigación — Dominio #3: Combate y daño (Godot 4.6)

### Verificaciones vía WebSearch (junio 2026)
- **Area3D / monitoring / monitorable:** confirmado que `area_entered` solo dispara con `Monitoring = true` en el lado que escucha; las capas de colisión deben hacer el chequeo de tipos en vez de `is`/cast en runtime (dredyson, GDQuest).
- **CollisionShape3D vs Area3D al deshabilitar:** confirmado que deshabilitar `CollisionShape3D.disabled` retira la forma de los tests de solapamiento, mientras tocar `monitorable` deja el nodo en el mundo físico (deferido → race conditions). Disparo múltiple con hurtboxes por hueso (4-6 señales por golpe).
- **Jolt issue #106482:** confirmado y vigente. `JoltArea3D` fija el sensor a kinematic aunque `monitorable=false`, costoso con muchas Areas solapadas. Existe PR #106490 (mihe) en curso. Issue #118047 corrobora el lag con Area3D solapadas en Jolt.
- **Addon cluttered-code:** v5.0.3 (últ. actualización ~mayo 2026), MIT, 2D y 3D. v5 prefija componentes base con "Basic" y añade variantes con tipos de daño/modificadores. Recomendado migrar a v4.4.0 antes de v5.0.0.

### Decisiones de diseño del código
- `DamageInfo` como `Resource` con `Dictionary[StringName, float]` para resistencias (typed dictionary 4.6).
- Blacklist anti-doble-golpe con `Dictionary[int, bool]` por `instance_id`, limpiada en `start_attack()`.
- Hitscan ofrecido en dos formas: `RayCast3D` (nodo) y `direct_space_state.intersect_ray()` (consulta directa, mejor para múltiples disparos/frame).
- C#: `[GlobalClass]` en Resource, `[Signal]`/`[Export]`, `AreaEntered +=`, y nota del breaking change String→StringName en pistas de AnimationPlayer (recompilar).

### Honestidad
- No existe un único tutorial que combine custom Resource + Area3D + C# en una guía; la parte C# se apoya en la API oficial de Area3D, hilos de foro sobre `AreaEntered`/`Monitoring` y los breaking changes 4.5→4.6 dados. Los bugs de Jolt son issues reales abiertos/etiquetados 4.4+; conviene verificar su estado en la versión 4.6.x exacta del proyecto.

## Fuentes
- https://www.gdquest.com/library/hitbox_hurtbox_godot4/
- https://github.com/gdquest-demos/godot-4-hitbox-hurtbox
- https://github.com/gdquest-demos/godot-open-rpg
- https://github.com/cluttered-code/godot-health-hitbox-hurtbox
- https://godotengine.org/asset-library/asset/3636
- https://codingquests.io/blog/godot-4-hitbox-hurtbox-tutorial
- https://dredyson.com/advanced-area3d-hitbox-optimization-how-i-mastered-duplicate-hit-prevention-with-professional-collision-detection-techniques-complete-configuration-guide-for-godot-4-6-2/
- https://dredyson.com/fix-duplicate-hit-detection-in-godot-4-6-2-area3d-hurt-hit-boxes-a-beginners-step-by-step-guide-to-resolving-race-conditions-collisionshape3d-vs-area3d-disabling-and-blacklist-dictionary-workarou/
- https://github.com/godotengine/godot/issues/109721
- https://github.com/godotengine/godot/issues/106482
- https://github.com/godotengine/godot/pull/106490
- https://github.com/godotengine/godot/issues/118047
- https://github.com/godotengine/godot/issues/88441
- https://github.com/godotengine/godot-proposals/issues/8610
- https://docs.godotengine.org/en/stable/classes/class_area3d.html
- https://docs.godotengine.org/en/stable/classes/class_raycast3d.html
- https://kidscancode.org/godot_recipes/4.x/3d/shooting_raycasts/index.html
- https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-12-player-shooting-dealing-damage-3n46
- https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-14-enemy-shooting-dealing-damage-2540
- https://shaggydev.com/2026/04/08/godot-custom-resources/
- https://ezcha.net/news/3-1-23-custom-resources-are-op-in-godot-4
- https://lasteamlab.com/documentation/game-design/godot/RPG/lessons/4-knockback.html
- https://godotengine.org/releases/4.6/
