## Notas de adjudicación (Juez-Sintetizador, Tema #17)

Los tres dossiers están **muy alineados** en lo esencial. Discrepancias y cómo las resolví:

1. **`load_steps` en el header de ejemplo.** El dossier ESCÉPTICO muestra en su §1 una cabecera de anatomía `[gd_scene load_steps=... format=3 uid="..."]` aunque su propia prosa dice (correctamente) que se eliminó en 4.6. Los dossiers DOCS y FIELD coinciden en que NO debe escribirse. **Adjudicación:** verifiqué vía WebSearch la guía oficial de upgrade 4.5→4.6 y el PR godot#103352 (merged): `load_steps` se eliminó del header en 4.6, el engine ya no lo escribe. Descarté el ejemplo del escéptico y usé el header sin `load_steps`. Es además el principal "tell" de texto generado por IA con docs viejos, así que lo destaqué.

2. **Hecho 4.6 nuevo que ningún dossier capturó del todo.** La guía oficial de upgrade confirma que en 4.6 **los nodos guardan ahora un UID propio en la escena** (para rastrear nodos al mover/renombrar; cambio retro/forward-compatible). Ninguno de los tres lo mencionó explícitamente. Lo añadí porque explica parte del diff masivo al re-guardar y es directamente relevante al tema (UIDs).

3. **Nombres de método de `ResourceUID`.** El dossier FIELD advierte que `path_to_uid()` e `id_to_path()` NO existen (son `path_to_id()` que devuelve int, y `get_id_path()`). El resultado de WebSearch sobre la clase mencionó ambos `path_to_id()`/`path_to_uid()` como posibles. **Adjudicación:** mantuve solo los nombres corroborados por múltiples fuentes y por la doc de clase: `text_to_id`, `id_to_text`, `path_to_id`, `get_id_path`, `has_id`, `create_id`, `add_id`, `set_id`. Evité `id_to_path` (inexistente) y no afirmé `path_to_uid` como API canónica para no arriesgar inventar. En los ejemplos usé solo los seguros (`text_to_id`/`id_to_text`/`get_id_path`/`has_id`/`create_id`/`add_id`).

4. **`--quit-after 2` vs `--quit`.** Los tres coinciden; verifiqué issue godot#77508 ("works with `--quit-after 2`", falla con `--quit`/`--quit-after 1`). Confirmado y mantenido como desatasque CI canónico.

5. **Commitear `*.import`.** El ESCÉPTICO dice commitear `*.import` (contienen UID estable del asset); el FIELD lo matiza ("según el caso"); DOCS dice ignorar `.import/` (carpeta legacy 3.x). **Adjudicación:** distinción clave verificada — la carpeta `.import/` era de Godot 3.x (se ignora si existe). En 4.x los **sidecars `*.import` por asset** (junto a texturas/audio) SÍ se commitean porque guardan el UID estable. Ignorar `.godot/` (que en 4.x absorbe la cache de import + `uid_cache.bin`) es lo correcto. Lo redacté con esa precisión.

6. **`run/main_scene` como `uid://`.** Los tres coinciden en que 4.4+ permite `uid://` o `res://`. Mantenido; advertí del riesgo de UID inventado → `Cannot load main scene`.

7. **Seguridad de `ResourceLoader.load()` desde savegames.** Solo el FIELD lo trae (RCE vía recursos embebidos, addon godot-safe-resource-loader). Es nicho y muy útil anti-stuck/seguridad; lo incluí en "Addon vs construirlo" porque es exactamente el tipo de decisión addon-vs-código relevante a un RPG con saves.

8. **AnimationPlayer String→StringName (GH-110767).** Solo el ESCÉPTICO lo trae. Verifiqué vía WebSearch: confirmado para `current_animation`/`assigned_animation`/`autoplay` (props de nombre de animación), NO nombres de track. Lo incluí en pitfalls con el literal `current_animation = &"walk"`.

Material descartado por dudoso/no verificable: no afirmé el contenido exacto del bloque `[input]` como copy-paste (los tres advierten que es frágil; coincido y recomiendo no editarlo a mano). No incluí el parser externo `godotclj-tscn` (referencia tangencial, no anti-stuck accionable).

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html
- https://github.com/godotengine/godot-docs/blob/master/engine_details/file_formats/tscn.rst
- https://github.com/godotengine/godot-docs/issues/11707
- https://github.com/godotengine/godot-proposals/issues/11802
- https://github.com/godotengine/godot/pull/103352
- https://github.com/godotengine/godot/issues/117421
- https://godotengine.org/article/uid-changes-coming-to-godot-4-4/
- https://dev.to/ziva/godot-44-added-uid-files-everywhere-heres-what-they-actually-do-4e56
- https://docs.godotengine.org/en/stable/classes/class_resourceuid.html
- https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html
- https://docs.godotengine.org/en/stable/classes/class_resourceloader.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html
- https://github.com/github/gitignore/blob/main/Godot.gitignore
- https://github.com/godotengine/godot/issues/77508
- https://github.com/godotengine/godot/issues/69511
- https://github.com/godotengine/godot/issues/71521
- https://github.com/godotengine/godot/issues/75617
- https://github.com/godotengine/godot/issues/96126
- https://forum.godotengine.org/t/how-to-fix-invalid-uid-warning/127542
- https://github.com/derkork/godot-safe-resource-loader
- https://www.gdquest.com/library/save_game_godot4/
