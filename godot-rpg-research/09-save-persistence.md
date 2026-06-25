## Notas de investigación — Domain #8: Guardado / persistencia (Godot 4.6)

### Verificaciones hechas (WebSearch, junio 2026)
- **`FileAccess.store_var(value, full_objects=false)`**: confirmado que `full_objects` default es `false` y que `true` permite ejecución de código en deserialización ("Deserialized objects can contain code which gets executed... potential security threats such as remote code execution"). `open_encrypted_with_pass(path, mode_flags, pass)` confirmado.
- **`ResourceLoader.CACHE_MODE_IGNORE`**: confirmado que recarga desde disco evitando datos cacheados viejos; el default `CACHE_MODE_REUSE` puede devolver instancia stale. Issue #82830 documenta inconsistencias de cache con PackedScenes.
- **Ejecución de código en `.tres`/`.res`**: confirmado por GDQuest y UhiyamaLab. Existe "Godot Safe Resource Loader" (drop-in de `ResourceLoader.load()` que verifica ausencia de código) y "WCSafeResourceFormat" (whitelist completa). `.tres` legible/manipulable; `.res` binario más difícil de tocar pero sin protección real sin cifrado.

### Decisiones de diseño del section
- Tabla dato→mecanismo como núcleo (ConfigFile/JSON/Resource).
- JSON plano + campo `version` + `_migrate()` como patrón canónico para saves del jugador (versionado, portabilidad, seguridad).
- C#: `System.Text.Json` + `FileAccess` (no el `JSON` de Godot), DTO `record` con primitivas (Vector3 descompuesto en x/y/z), `[Signal]...EventHandler`. Gotcha recompilación por `String`→`StringName` en tracks de AnimationPlayer (breaking 4.5→4.6).
- Pitfalls: float-coercion de JSON, no guardar NodePath/refs vivas, falta de versionado nativo de Resources (#7567), cache de ResourceLoader, cifrado no migra entre majors (#78815), `ConfigFile.get_value` siempre con default.

### Honestidad
- Páginas `class_*` de ResourceSaver/ConfigFile/JSON son rama `stable`/`latest`; las clases no cambiaron en 4.6. Solo el tutorial "Runtime file loading and saving" es URL `/en/4.6/`.
- Gotchas C# vienen de Mouillard y Aceade, no de Reddit (sin resultados).

## Fuentes

- https://docs.godotengine.org/en/4.6/tutorials/io/runtime_file_loading_and_saving.html
- https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html
- https://docs.godotengine.org/en/stable/classes/class_resourceloader.html
- https://docs.godotengine.org/en/stable/classes/class_configfile.html
- https://docs.godotengine.org/en/latest/classes/class_fileaccess.html
- https://docs.godotengine.org/en/stable/classes/class_json.html
- https://www.gdquest.com/library/save_game_godot4/
- https://www.gdquest.com/library/cheatsheet_save_systems/
- https://shaggydev.com/2026/04/08/godot-custom-resources/
- https://codingquests.io/blog/how-to-build-a-save-system-in-godot-4
- https://uhiyama-lab.com/en/notes/godot/save-load-system/
- https://godotlearning.com/blog/godot-4-save-system-tutorial
- https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-20-saving-loading-autosaving-4bl3
- https://github.com/gdquest-demos/godot-open-rpg
- https://github.com/SlashScreen/skelerealms
- https://github.com/newold3/Godot-RPG-Creator
- https://github.com/AdamKormos/SaveMadeEasy
- https://github.com/TommyKooij/SaveSystem
- https://github.com/KoBeWi/Metroidvania-System
- https://github.com/MrRobinOfficial/Godot-Saveable
- https://godotengine.org/asset-library/asset/2359
- https://github.com/godotengine/godot-proposals/discussions/7567
- https://github.com/godotengine/godot/issues/78815
- https://github.com/godotengine/godot/issues/82830
- https://medium.com/@romain.mouillard.fr/lightweight-saving-loading-system-in-godot-4-with-c-a-practical-guide-2cb6cbd2faa3
- https://aceade.net/2025/01/12/parsing-arbitrary-json-in-godot-net/
