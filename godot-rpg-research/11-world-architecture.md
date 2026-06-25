## Notas de investigación — Dominio #10 (Gestión de mundo / niveles y arquitectura)

### Verificación de API (WebSearch, junio 2026)
- Confirmado `SceneTree.change_scene_to_packed` y `change_scene_to_file` como métodos nativos de cambio de escena en Godot 4.x; docs issue #8868 pide más enseñanza sobre ambos.
- Confirmado patrón `ResourceLoader.load_threaded_request` → `load_threaded_get_status(path, progress)` → `load_threaded_get` en docs background_loading; `progress` array de salida 0.0–1.0; enum `ThreadLoadStatus`.
- Confirmado `WorkerThreadPool.add_task(action, high_priority, description) -> int` y `wait_for_task_completion(task_id)` con la advertencia oficial de que TODA task debe esperarse para liberar recursos. `wait_for_task_completion` puede devolver `ERR_BUSY` por riesgo de deadlock (call stack más bajo).

### Issues reales relevantes confirmados en búsqueda
- #111202: load_threaded_request crashea con múltiples escenas complejas (4.6.dev1).
- #95470: load_threaded_get_status devuelve 0 / THREAD_LOAD_INVALID_RESOURCE espurio (complementa al #56882 del dossier sobre progress[0]).
- #84936: wait_for_task_completion ocasionalmente cuelga pese a is_task_completed.
- #103674 / #78734: use_sub_threads=true deadlock/cuelga (C#).
- #87752: NativeAOT C# LoadThreadedGet cuelga.
- #109914: background loading roto en Web.

### Decisiones de autoría
- Reescribí el SceneManager para combinar fade (CanvasLayer+ColorRect+Tween) + carga threaded en un solo autoload coherente, con signals tipados (`load_progress`, `load_finished`) y `@export fade_color`.
- Versión C# idiomática: `partial class : Node`, `[Signal] delegate ...EventHandler`, `[Export]`, `Callable.From` mencionado para el gotcha de CallDeferred, `useSubThreads: false` explícito, nota de recompilación String->StringName.
- Mantuve el principio ponytail: nativo para transiciones, addon (Open-World-Database) solo para streaming por chunks.

## Fuentes
- https://docs.godotengine.org/en/stable/classes/class_scenetree.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html
- https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html
- https://docs.godotengine.org/en/stable/classes/class_resourceloader.html
- https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
- https://godotengine.org/releases/4.6/
- https://github.com/godotengine/godot/issues/111202
- https://github.com/godotengine/godot/issues/103674
- https://github.com/godotengine/godot/issues/78734
- https://github.com/godotengine/godot/issues/87752
- https://github.com/godotengine/godot/issues/56882
- https://github.com/godotengine/godot/issues/95470
- https://github.com/godotengine/godot/issues/84936
- https://github.com/godotengine/godot/issues/109914
- https://github.com/godotengine/godot-docs/issues/8868
- https://github.com/gdquest-demos/godot-open-rpg
- https://github.com/SlashScreen/skelerealms
- https://github.com/DigitallyTailored/Godot-Open-World-Database
- https://github.com/EiTaNBaRiBoA/AsyncScene
- https://github.com/abmarnie/godot-architecture-organization-advice
- https://github.com/SlayHorizon/godot-project-structure-template
- https://github.com/ProFiLeR4100/AsyncResourceLoaderForCS
- https://kidscancode.org/godot_recipes/4.x/basics/node_communication/index.html
- https://www.gdquest.com/tutorial/godot/best-practices/signals/
- https://www.gdquest.com/tutorial/godot/2d/scene-transition-rect/
- https://codingquests.io/blog/godot-4-scene-transitions-fade
- https://shaggydev.com/2022/06/13/godot-scene-transitions/
- https://catlikecoding.com/godot/true-top-down-2d/7-map-transitions/
- https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-18-scene-transitions-day-night-cycle-4mnm
- https://bugnet.io/blog/fix-godot-csharp-call-deferred-not-running-on-main-thread
- https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language
- https://godotassetlibrary.com/asset/SpXqE2/transit-(godot-4)
- https://godotassetlibrary.com/asset/1WuQP4/threadpool
