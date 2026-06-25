## Notas de adjudicación del debate (Tema #13)

Las tres lentes (docs, veterano, escéptico) fueron **fuertemente convergentes** en la jerarquía de errores y en los fixes canónicos. No hubo contradicciones de hechos; las diferencias fueron de énfasis y de cobertura. Adjudicación:

**Acuerdo total (mantenido sin reservas):**
- El error nº1 absoluto es `Invalid get index ... (on base: 'Nil')`, con cuatro causas: ruta `@onready` mal, orden `_ready` bottom-up (hermano/padre no listo), `get_node` antes de `add_child`, y ref liberada. Las tres lentes coinciden palabra por palabra. Fixes: `%UniqueName` tipado, `call_deferred`/`await process_frame` para cruces, `is_instance_valid`.
- Señales: `already connected` → `is_connected`/`CONNECT_ONE_SHOT`; trampa de lambdas (siempre `false`); mismatch de aridad = args señal + `bind`.
- `await` colgado por señal que nunca se emite = el atasco más cruel (sin error). Las tres lo destacan; el escéptico aporta la causa más nicho y verificable: **typo en el nombre de la señal no se valida en el sitio del `await`**. Adjudicado a favor de incluirlo + patrón timeout.
- Física en `_physics_process`, sin doble delta en `move_and_slide`.
- Fugas: `queue_free` vs `free`, orphan nodes (Monitors + `print_orphan_nodes`), ciclos RefCounted → `weakref` en una sola dirección.
- Mutar colección mientras se itera → `filter`/`duplicate`/loop inverso.

**Donde discreparon en énfasis y cómo lo resolví:**
1. **Migración 4.6 (Jolt/shader/StringName) vs atascos diarios.** El escéptico argumenta que Jolt/shader/StringName son de baja frecuencia frente al `await` colgado y el `@onready` null, y que si la guía tuviera una sola página debería priorizar Nil + árbol de decisión. El veterano y docs los tratan como imprescindibles para porting. **Adjudicación:** incluí ambos, pero coloqué Nil/señal/física/fugas como el cuerpo principal y agrupé los breaking changes 4.6 como bloques etiquetados de "migración" (StringName en C#, shader mat3x4). Sigo la prioridad del escéptico en el orden, sin descartar lo de docs/veterano.
2. **typed Dictionary 4.6.** Solo el escéptico aportó el detalle verificable y de alto valor anti-stuck: `JSON.parse_string` devuelve `Dictionary[Variant,Variant]` (rompe asignación a dict tipado) y la **regresión GH-115624** (`operator[] used when there was no value`). Verifiqué GH-115624 por WebSearch (regresión real 4.5→4.6, reproducible en 4.6.stable). Adjudicado a incluir, con fix `dict.get(k, default)`.
3. **Jolt como fuente de bugs silenciosos.** El escéptico aporta el matiz más útil: nuevos proyectos usan Jolt por defecto pero los existentes conservan su motor; migrar puede romper joints (`damp` en `HingeJoint3D` solo en Godot Physics) sin lanzar error. Lo mencioné en el árbol/prosa pero sin sobredimensionar (es porting, baja frecuencia). Coherente con los FACTS (Jolt default 3D en proyectos nuevos).
4. **C# señales no se autodesconectan al liberar.** El veterano (GH-89116) lo marca como mordisco real; lo incorporé al ejemplo C# con `_ExitTree`.

**Descartado/atenuado por dudoso o de baja verificabilidad:**
- La "regresión de rendering 4.6 (sky/VoxelGI/SDFGI, GH-115599)" que menciona el veterano: la dejé fuera del cuerpo por ser un issue puntual y volátil ("verifica en ~4.6.3"), no un patrón de atasco generalizable.
- `await_any([...])` que insinúa el escéptico: no es API nativa de Godot, así que escribí el patrón timeout explícito con `create_timer` + `CONNECT_ONE_SHOT` para no inventar API.

**Verificaciones propias (WebSearch):**
- GH-110767 (AnimationPlayer String→StringName): confirmado, props exactas `current_animation`/`assigned_animation`/`autoplay`/`get_queue()`/señal `current_animation_changed`; GDScript-compatible, NO C# binario/fuente. Coincide con los FACTS.
- GH-115624 (Dictionary::operator[] regresión 4.5→4.6): confirmado reproducible en 4.6.stable, no en 4.5.1 ni en proyecto vacío.

## Fuentes
- https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html
- https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/migrating/upgrading_to_godot_4.6.rst
- https://github.com/godotengine/godot/issues/115624
- https://github.com/godotengine/godot/issues/110509
- https://github.com/godotengine/godot-docs/issues/11744
- https://github.com/godotengine/godot/issues/89116
- https://github.com/godotengine/godot/issues/53563
- https://github.com/godotengine/godot/issues/18829
- https://github.com/godotengine/godot/issues/95222
- https://github.com/godotengine/godot/issues/74449
- https://forum.godotengine.org/t/invalid-get-index-position-on-base-null-instance-when-instance-should-exist/69339
- https://forum.godotengine.org/t/already-connected-to-callable-error/84444
- https://www.gdquest.com/library/null_instance_error/
- https://bugnet.io/blog/fix-godot-packed-scene-ready-order-incorrect
- https://bugnet.io/blog/fix-godot-gdscript-await-signal-never-completing
- https://bugnet.io/blog/fix-godot-physics-interpolation-jitter
- https://bugnet.io/blog/how-to-find-memory-leaks-in-godot-games
- https://gdscript.com/solutions/coroutines-and-yield/
- https://shaggydev.com/2025/11/03/godot-refcounted/
- https://kidscancode.org/godot_recipes/4.x/basics/getting_nodes/index.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html
