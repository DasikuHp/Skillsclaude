## Notas de adjudicación — Tema #25

Las tres lentes (docs / veterano / escéptico) coincidieron en un grado inusualmente alto. No hubo contradicciones de hechos de fondo; las diferencias fueron de énfasis y de un matiz técnico sobre Web. Adjudicación priorizando lo verificable en docs 4.6 y lo confirmado por WebSearch (jun-2026).

### Acuerdos unánimes (mantenidos como núcleo)
- `visibility_aabb` como atasco #1, con doble función render+colisión (GH-93567) y el matiz de que `custom_aabb` lo sobrescribe.
- `restart()` en vez de `emitting=true` para re-disparar one-shots (GH-79689/83909/93991).
- `finished` poco fiable → respaldo con Timer idempotente (GH-93991, PR-101596, GH-85802).
- Trails: tres requisitos + `sections<=6` (GH-81109). **Verificado por WebSearch**: "if Sections is set to 7 or more, it becomes broken" y "use_particle_trails must also be enabled ... Setting trail_enabled to true will have no effect if this is not enabled". Confirmado.
- Sub-emitter: el hijo deja de emitir solo + necesita colisión. **Verificado por WebSearch**: "When sub_emitter is set, the target GPUParticles3D node will no longer emit particles on its own" y "collision properties are only effective if collision_mode is COLLISION_RIGID or COLLISION_HIDE_ON_CONTACT". Confirmado.
- MultiMesh: orden `transform_format` → `instance_count` → transforms; preferir `set_instance_transform()` (GH-76884).
- Decal proyecta en −Y local; necesita textura + `albedo_mix>0`.
- Web = Compatibility, sin C#, sin compute.
- Nombres C#: `GpuParticles3D`/`Aabb`/`VisibilityAabb`.

### Discrepancia 1 — comportamiento exacto en Web/Compatibility
- **docs** y **field**: en Web las GPUParticles "no renderizan, SIN error ni warning" (fallo silencioso duro).
- **skeptic**: matiza que en versiones recientes pueden **caer a simulación CPU silenciosa**, funcionando pero con features avanzadas comportándose distinto, citando bugs vigentes (GH-107633, GH-100872, GH-84072).
- **Adjudicación**: ambos describen el mismo riesgo (resultado impredecible y silencioso) con outcome distinto según versión. No fijo un outcome concreto porque no es verificable de forma estable; doy la instrucción accionable y segura para los dos casos: **no confíes en ningún resultado, prepara escenas `*_cpu.tscn` y detecta el backend en runtime** (`RenderingServer.get_rendering_device() == null`). Esto es robusto sea cual sea el comportamiento real.

### Discrepancia 2 — `capture_aabb()`
- **docs** y **skeptic** lo citan como método de `GPUParticles3D` (equivalente al botón Generate AABB). **field** no lo menciona y usa AABB manual + `extra_cull_margin`.
- **Adjudicación**: incluyo ambos (AABB manual amplio como opción primaria a prueba de balas, `capture_aabb()` tras un frame como equivalente al botón). `capture_aabb()` y `extra_cull_margin` (de `GeometryInstance3D`) son APIs reales; ambos enfoques son válidos y complementarios. Recomiendo el AABB manual como invariante por defecto porque no depende de timing de un frame.

### Discrepancia 3 — SDF vs colisión simple
- **docs**: explica el flujo SDF (bake en editor, commitear `.tres`).
- **skeptic**: añade el bug de recarga (GH-60994) y recomienda evitar SDF para gameplay reactivo, usando Box/Sphere/HeightField sin bake.
- **Adjudicación**: tomo la postura del escéptico como recomendación práctica (sin bake = sin botón de editor que una IA no puede pulsar = anti-stuck), mencionando SDF solo como opción para entorno estático con su pitfall.

### Descartado / no incluido
- No incluí `directional-blood-splatter` (kubsterman) como recomendación: el propio field lo califica de "trivial de replicar"; se cae por el principio ponytail (construir es más simple que el addon). Mencionado solo como referencia conceptual, no en el veredicto.
- Issue de gizmo AABB (#9591) y doc faltante (#83913): ruido, no accionables para una IA.
- Nota de honestidad de las tres lentes: WebFetch estaba bloqueado; firmas exactas de parámetros (p. ej. `emit_particle`) deben re-confirmarse en la página de clase si se requiere precisión absoluta. Los enums clave (`SUB_EMITTER_AT_COLLISION`, `COLLISION_RIGID`, `use_particle_trails`) sí quedaron confirmados por WebSearch arriba.

### Verificación de hechos del enunciado (Godot 4.6)
Coherente con FACTS: Web=Compatibility sin C#; `.tscn` sin `load_steps` + `uid://`/`.uid` desde 4.4; shader built-ins `SCREEN_TEXTURE`/`DEPTH_TEXTURE` → `hint_screen_texture`/`hint_depth_texture`; CLI `--headless/--check-only/--import/--export-release/--verbose/--quit-after`. No se tocó IK, typed Dictionary se usó idiomáticamente en el pool GDScript (`Dictionary[StringName, Array]`).

## Fuentes
- https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html
- https://docs.godotengine.org/en/stable/classes/class_particleprocessmaterial.html
- https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html
- https://docs.godotengine.org/en/stable/tutorials/3d/particles/subemitters.html
- https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html
- https://docs.godotengine.org/en/stable/tutorials/3d/particles/collision.html
- https://docs.godotengine.org/en/stable/tutorials/3d/particles/turbulence.html
- https://docs.godotengine.org/en/stable/classes/class_ribbontrailmesh.html
- https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html
- https://docs.godotengine.org/en/stable/classes/class_gpuparticlescollisionsdf3d.html
- https://docs.godotengine.org/en/stable/classes/class_gpuparticlesattractor3d.html
- https://docs.godotengine.org/en/stable/classes/class_multimesh.html
- https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html
- https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html
- https://github.com/godotengine/godot/issues/93567
- https://github.com/godotengine/godot/issues/81109
- https://github.com/godotengine/godot/issues/79689
- https://github.com/godotengine/godot/issues/83909
- https://github.com/godotengine/godot/issues/93991
- https://github.com/godotengine/godot/pull/101596
- https://github.com/godotengine/godot/issues/85802
- https://github.com/godotengine/godot/issues/87891
- https://github.com/godotengine/godot/issues/60994
- https://github.com/godotengine/godot/issues/76884
- https://github.com/godotengine/godot/issues/94136
- https://github.com/godotengine/godot/issues/107633
- https://github.com/godotengine/godot/issues/100872
- https://github.com/godotengine/godot/issues/84072
- https://github.com/godotengine/godot/issues/80901
- https://github.com/godotengine/godot/issues/88748
- https://github.com/godotengine/godot/issues/100946
- https://github.com/godotengine/godot/issues/97621
- https://github.com/godotengine/godot-proposals/issues/4938
- https://github.com/celyk/GPUTrail
- https://github.com/Master-J/DecalCo
- https://forum.godotengine.org/t/3d-particles-only-rendering-in-certain-spots/75962
- https://forum.godotengine.org/t/cant-setup-gpuparticles3d-trails-they-look-broken-wrong-rendering/105199
- https://forum.godotengine.org/t/solutions-for-projecting-a-blood-texture-on-many-surfaces/84882
- https://godotforums.org/d/25780-multimesh-3d-performance-spike-due-to-setting-visible-instance-count
- https://bugnet.io/blog/fix-godot-gpu-particles-not-rendering-mobile
