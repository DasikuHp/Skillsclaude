## 25. VFX y partículas como gameplay

VFX en un RPG 3D NO es decoración: una bola de fuego que explota en chispas al chocar, una estela de espada, sangre en el suelo, un volley de flechas o un vórtice que arrastra partículas son *gameplay legible*. El reto para una IA que no ve el editor es que **el 80% de los atascos de VFX no producen ningún error en consola**: el código es "correcto", `emitting = true`, y simplemente no se ve nada. Esta sección está organizada alrededor de esos fallos silenciosos y de cómo escribir invariantes en código en vez de pulsar botones del editor.

### Enfoque nativo recomendado

Arquitectura canónica para combate: **la lógica de combate NO instancia ni configura partículas**. Emite una señal (`hit`, `died`, `parried`) con un payload (posición, normal, tipo de daño); un `VfxManager` (autoload) escucha y dispara el VFX desde un **pool pre-calentado**. Esto desacopla presentación de gameplay y permite hacer swap GPU↔CPU por plataforma sin tocar el combate.

Mapa de nodos nativos 4.6 (verificados contra `docs.godotengine.org`):

| Efecto de gameplay | Nodo / recurso nativo 4.6 | Nota clave |
|---|---|---|
| Impacto / explosión / chispas | `GPUParticles3D` (`one_shot=true`) + `ParticleProcessMaterial` | re-disparo con `restart()`, NUNCA `emitting=true` |
| Fireball → chispas al chocar | `sub_emitter` (NodePath) + `ParticleProcessMaterial.sub_emitter_mode = SUB_EMITTER_AT_COLLISION` | exige colisión activa |
| Estela de espada / proyectil | `GPUParticles3D.trail_enabled` + `RibbonTrailMesh`/`TubeTrailMesh` | requiere `BaseMaterial3D.use_particle_trails = true` |
| Sangre / quemaduras / runas | `Decal` | proyecta en su eje **−Y local** |
| Volley de flechas / hierba | `MultiMeshInstance3D` + `MultiMesh` | un draw call |
| Atracción / viento / vórtice | `GPUParticlesAttractor3D` (Box/Sphere/VectorField) | solo dentro del AABB del emisor |
| Colisión con el mundo | `GPUParticlesCollision3D` (Box3D/Sphere3D/SDF3D/HeightField3D) | **solo GPU**, NO ve PhysicsBody3D/Jolt |
| Fallback Web/Compatibility | `CPUParticles3D` | sin colisión/attractors/sub-emitters/compute |

Propiedades canónicas de `GPUParticles3D`: `emitting`, `amount` (≥1), `one_shot`, `explosiveness` (0–1), `lifetime`, `speed_scale`, `fixed_fps`, `process_material`, `draw_pass_1`..`draw_pass_4`, `sub_emitter` (NodePath), `trail_enabled`, `trail_lifetime`, `visibility_aabb` (AABB). Señal: `finished` — **se emite SOLO con `one_shot == true`**, nunca en loop. Métodos: `restart()`, `emit_particle(...)`, `capture_aabb()` — ojo: `capture_aabb()` **devuelve** el AABB de las partículas vivas del frame actual (es un cálculo, NO asigna nada); para que sirva como "Generate AABB" tienes que asignar tú su resultado a `visibility_aabb` (o `custom_aabb`) tras 1 frame.

Nombres C# (.NET 8): la clase es `GpuParticles3D` (PascalCase, no `GPUParticles3D`), `Aabb`, `VisibilityAabb`, `OneShot`, `Emitting`, `Restart()`, evento `Finished`.

### Pitfalls y mensajes de error literales

**ATASCO #1 — partículas invisibles por `visibility_aabb` (el que más mata a una IA ciega).**
Síntoma: código perfecto, `emitting = true`, sin error, y nada se ve; o parpadea/desaparece al mover la cámara. Causa: el `visibility_aabb` (heredado de `GeometryInstance3D`) es la caja que debe estar en pantalla para que el sistema se *procese*; por defecto es pequeño y **local al nodo**. Si las partículas vuelan fuera (velocidad alta, emisor en movimiento siguiendo un proyectil), el motor culling-ea TODO el emisor. El fix "canónico" es el botón **Particles → Generate AABB**, que una IA NO puede pulsar. Además (GH-93567) **el AABB delimita también la zona de colisión**: un AABB pequeño rompe colisión en silencio. Y `GeometryInstance3D.custom_aabb`, si tiene valor no-default, **sobrescribe** `visibility_aabb`.
Fix por código: AABB amplio explícito + `extra_cull_margin`, o asignar el resultado de `capture_aabb()` a `visibility_aabb` tras un frame (equivalente al botón; `capture_aabb()` solo lo calcula, no lo escribe).

**ATASCO #2 — one-shot que no re-dispara (impactos que solo funcionan la primera vez).**
Con `one_shot = true`, poner `emitting = true` **no reinicia** el ciclo si quedan partículas vivas en GPU (GH-79689, GH-83909, GH-93991). En combate rápido el segundo golpe no muestra nada. Fix: usar **`restart()`** siempre. Nunca `emitting = false; emitting = true`.

**ATASCO #3 — la señal `finished` que no llega (rompe el pool).**
`finished` solo se emite con `one_shot`; llega con retraso variable (sim en GPU); bugs históricos: espuria en `_ready` (corregido en PR-101596), no emitida con one_shot puesto por GDScript (GH-93991), o suprimida por una pista RESET de `AnimationPlayer` (GH-85802). Fix defensivo: NO confíes solo en la señal; respáldala con un `Timer` de seguridad = `lifetime * 1.5 / speed_scale`, y haz el callback de reciclaje **idempotente** (puede llamarse dos veces).

**ATASCO #4 — lag spike de la primera instancia (GH-87891).** La primera emisión compila/sube el shader de proceso → pico de frame. NO instancies VFX en caliente: pre-calienta el pool con un `restart()` al cargar el nivel, fuera de cámara.

**ATASCO #5 — Web/Compatibility falla en silencio.** Compatibility (OpenGL ES 3.0 / WebGL 2) **no tiene compute shaders ni `RenderingDevice`**. En Web (forzado a Compatibility, **sin C#**) el comportamiento de `GPUParticles3D` es poco fiable entre versiones: o no renderiza sin warning, o cae a sim CPU silenciosa con features avanzadas (attractors/turbulence/colisión) comportándose distinto (GH-107633, GH-100872, GH-84072). No confíes en ningún resultado concreto: prepara escenas `*_cpu.tscn` con `CPUParticles3D` por adelantado y detecta el backend en runtime con `RenderingServer.get_rendering_device() == null` o `OS.has_feature("web")`. La conversión GPU→CPU en editor no preserva todo (ring emission GH-100946, comportamiento raro GH-97621); revísala a mano.

**ATASCO #6 — trails de espada rotos.** Tres cosas obligatorias o no hay estela (sin error): `trail_enabled=true`, un `RibbonTrailMesh`/`TubeTrailMesh` en `draw_pass_1`, y **`use_particle_trails=true` en el material del mesh**. Subir `sections` a ≥7 rompe la geometría (extremos conectados al origen, GH-81109): mantener **≤6**. Secciones/subdivisiones van en el MESH, no en el nodo (a diferencia de 2D). En Web los trails han fallado en silencio (GH-88748).

**ATASCO #7 — sub-emitters.** Cuando `sub_emitter` está asignado, el nodo hijo **deja de emitir por su cuenta** (debe quedar con `emitting=false`; lo gobierna el padre). Para `SUB_EMITTER_AT_COLLISION` el material del padre necesita `collision_mode = COLLISION_RIGID` (o `COLLISION_HIDE_ON_CONTACT`) y un `GPUParticlesCollision*3D` dentro del AABB.

**ATASCO #8 — colisión / SDF que "no hace nada".** Las partículas **NO colisionan con PhysicsBody3D ni Jolt**, solo con nodos `GPUParticlesCollision3D`. `collision_mode` por defecto es `COLLISION_DISABLED`. `GPUParticlesCollisionSDF3D` requiere **Bake SDF** (botón de editor) y tras bakear puede no colisionar hasta guardar/recargar (GH-60994). Pragmático para una IA: usa `GPUParticlesCollisionBox3D`/`Sphere3D`/`HeightField3D` (dinámicos, **sin bake**) en vez de SDF.

**ATASCO #9 — Decal invisible o mal orientado.** El `Decal` proyecta por su eje **−Y local**; si no lo orientas, la sangre va siempre hacia abajo. Debe tener `texture_albedo` O `texture_emission` asignado, y `albedo_mix > 0`, o es invisible sin error. `cull_mask` controla qué capas recibe (sangre en suelo, no en jugador). Presupuesto limitado por clúster: usa pool con máximo, no `instantiate` infinito. Cuidado con `look_at` cuando la normal es paralela al up (`Up vector and direction ... are aligned`): early-return o up alternativo.

**ATASCO #10 — MultiMesh todo en el origen.** Orden obligatorio: `transform_format = TRANSFORM_3D` → `mesh` → `instance_count` → `set_instance_transform(i, xf)`. Si pones transforms antes de `instance_count`, salen al origen. Prefiere `set_instance_transform()` sobre `set_buffer()` (GH-76884). `visible_instance_count` revela progresivamente pero re-subir buffers cada frame da pico; no lo toques por frame. El AABB agregado puede cullear tramos: considera `custom_aabb`.

Errores literales que SÍ salen en consola:

| Mensaje literal | Causa | Fix |
|---|---|---|
| `Condition "p_amount < 1" is true.` | `amount = 0` | `amount >= 1` |
| `Index p_pass = N is out of bounds (draw_passes = M).` | asignar `draw_pass_X` fuera de rango | subir `draw_passes` antes |
| `Compute shaders are not supported on the Compatibility rendering backend.` | features GPU en Web | fallback `CPUParticles3D` |
| `Nonexistent function 'restart'` / cast inválido | cast mal a `GPUParticles3D`, o `null` | verifica `as GPUParticles3D` |
| Shader: `SCREEN_TEXTURE`/`DEPTH_TEXTURE` no declarado | shader VFX pre-4.0 | `uniform sampler2D t : hint_screen_texture;` / `hint_depth_texture` |
| `Up vector and direction ... are aligned` | normal paralela al up en `look_at` | up alternativo / early-return |
| errores de `load_steps`/recursos al cargar `.tscn` viejo | proyecto pre-4.4 sin `.uid` | **Project → Tools → Upgrade Project Files** |

### Cómo no quedarte atascado

Sin editor, escribe **invariantes defensivas** y valida en headless:

```bash
godot --headless --check-only --script res://vfx/vfx_pool.gd   # valida sintaxis/tipos
godot --headless --import                                       # genera .uid / importa recursos
godot --verbose --headless --quit-after 5 res://test_vfx.tscn   # smoke test + warnings de render
godot --export-release "Web" build/index.html                   # OJO: Web = Compatibility, sin C#
```

Checklist de invariantes que una IA ciega DEBE codificar:
1. AABB explícita por código (`visibility_aabb` amplio, o asignar el resultado de `capture_aabb()` a `visibility_aabb` tras 1 frame) — nunca depender de "Generate AABB".
2. Re-disparo de one-shot SIEMPRE con `restart()`.
3. Reciclaje del pool respaldado con `Timer` idempotente, no solo `finished`.
4. Pool pre-calentado (un `restart()` al cargar) contra el lag spike.
5. Detectar Compatibility en runtime y hacer swap a `CPUParticles3D`; tener escenas CPU/GPU separadas en disco.
6. En trails: comprobar `use_particle_trails` y `sections <= 6`.
7. En sub-emitter: hijo con `emitting=false` + `collision_mode` activo.
8. En `.tscn` generados a mano: NO escribir `load_steps` (4.6 ya no lo usa); recursos vía `uid://` + `.uid`.

Recuerda 4.6: `.tscn` ya no escribe `load_steps`; recursos usan `uid://` + ficheros `.uid` (desde 4.4). En shaders de VFX, `SCREEN_TEXTURE`/`DEPTH_TEXTURE` fueron eliminados → `hint_screen_texture`/`hint_depth_texture`.

### Addon vs construirlo

- **Nativo (construir)**: impactos one-shot, sub-emitters, attractors, colisión Box/Sphere/HeightField, decals planos de sangre, volleys MultiMesh, trails ≤6 sections. Todo robusto en 4.6; meter addons aquí es deuda.
- **Estela de espada de alta fidelidad o en Web**: el trail nativo sirve si ≤6 sections y no apuntas a Web; si no, [`celyk/GPUTrail`](https://github.com/celyk/GPUTrail) (trail GPU) o un `ImmediateMesh`-ribbon procedural para un corte limpio determinista.
- **Decals sobre geometría curva / material custom**: el nativo no soporta material custom (proposal #4938) → [`Master-J/DecalCo`](https://github.com/Master-J/DecalCo) (shader-based). Para sangre plana en suelo/pared, `Decal` nativo basta.

**Veredicto ponytail:** El mejor VFX es el que no escribes a mano: GPUParticles3D + ParticleProcessMaterial + Decal + MultiMesh cubren el 100% de un RPG sin shaders ni nodos custom. La trampa no es la API — es que el editor "arregla" en silencio (Generate AABB, Bake SDF, Convert to CPU) cosas que una IA ciega tiene que codificar. Reusa los nodos nativos, dispara por señal desde un pool pre-calentado, fija el AABB y usa `restart()` por código, y prepara escenas `*_cpu.tscn` para Web. Cero addons hasta que el look lo exija.



> **Escalera ponytail:** rung 4 (GPUParticles3D/Decal/MultiMesh) · **net propio:** emisor one-shot + pool; dispara VFX por señal de combate.
