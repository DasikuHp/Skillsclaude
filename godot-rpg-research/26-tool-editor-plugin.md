## Notas de adjudicación — Tema #24

Los tres lentes (docs / veterano / escéptico) son **fuertemente convergentes**; no hubo contradicciones de fondo, solo diferencias de énfasis y un par de matices a reconciliar.

### Coincidencias (alta confianza, conservadas)
- Las 4 capas (`@tool` → `@export_tool_button` → `EditorPlugin` → custom Resource) y la regla de "elige la mínima": los tres lentes la afirman. Conservada como tabla.
- `Engine.is_editor_hint()` como guardia central, y que `_ready`/`_process`/setters corren en editor: idéntico en los tres.
- El pitfall de `owner` para persistir nodos generados, con `add_child` antes y `owner` después: triple-confirmado con issues distintos (GH-37144, GH-82756, GH-95646). Conservado.
- `@export_tool_button` (4.4+) reemplaza el hack `bool`+setter: triple-confirmado.
- GridMap `set_cell_item(Vector3i, item, orientation)`, item = ID de MeshLibrary, orientation = 0–23 (no grados): triple-confirmado.
- MultiMesh: `transform_format`/`instance_count` antes de transforms: triple-confirmado.
- CLI headless para validación ciega: triple-confirmado.

### Discrepancias / matices resueltos
1. **`--check-only` ¿requiere `--script`?** El lente docs lo marcó como "verificación pendiente". Lo verifiqué vía WebSearch (command_line_tutorial + GH-78587): `--check-only` opera sobre el script pasado con `-s`/`--script`; la forma `godot --headless --check-only --script <path>` es válida. Adjudicado a favor de incluirlo, con nota de que tiene edge cases (no resuelve autoloads igual que el editor — GH-78587). Mantengo `--script` en los ejemplos.
2. **Icono del `@export_tool_button`.** El docs decía "nombre de EditorIcons theme"; verifiqué que es el nombre de archivo de `editor/icons/` (case-sensitive) y que el default sin especificar es `"Callable"` (PR #96290 docs + gdscript_exports.rst). Precisado en la sección.
3. **Bake al `.tscn`: ¿recomendar o no?** El docs es neutral/descriptivo; veterano y escéptico son enfáticos en **NO bakear mazmorras procedurales**, generar en runtime o preview-sin-owner. Adjudico a favor de la postura fuerte de los dos lentes de campo: es la guía anti-stuck más útil y evita la clase entera de bugs de corrupción. Conservada como "decisión clave de diseño".
4. **NOTIFICATION de pre-save para tool scripts** (flag pendiente del docs): ninguno de los tres confirmó el identificador canónico en 4.6. **Descartado** — no lo incluyo para no inventar API. En su lugar, la receta verificable de persistencia es `ResourceSaver.save()` explícito.
5. **`instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)`** (solo en escéptico, vía godot-docs#8801): plausible y útil para sub-instancias en tool, pero solo un lente lo cita y la constante exacta no la re-verifiqué en 4.6. Lo menciono de forma indirecta (no en code block con esa constante) para no arriesgar API inventada; el contrato de owner principal queda con la receta triple-confirmada.

### C#
Diagnósticos GD0108/GD0111 (botón fuera de tool class / no expression-bodied) confirmados por el lente docs con URLs de diagnostics; conservados. Nota de contexto 4.6: NO C# en web (Compatibility renderer).

### Lo que mantuve por valor nicho/anti-stuck
- Procedimiento de emergencia para editor en crash-loop (editar `.gd` externo, vaciar `main_scene`, reimportar) — único en veterano/escéptico, altísimo valor.
- Tabla de errores literales — fusión de las tres tablas, deduplicada.
- Trampa de `_init()` con exports en default (GH-68427) — solo escéptico, conservada.
- Facts 4.6 (uid://, shader hints, StringName en AnimationPlayer, @abstract) — alineados con los FACTS del brief.

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html
- https://docs.godotengine.org/en/stable/classes/class_editorplugin.html
- https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html
- https://docs.godotengine.org/en/stable/classes/class_editorinspectorplugin.html
- https://docs.godotengine.org/en/stable/classes/class_editornode3dgizmoplugin.html
- https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
- https://docs.godotengine.org/en/stable/classes/class_gridmap.html
- https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html
- https://docs.godotengine.org/en/stable/classes/class_multimesh.html
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/scripting/gdscript/gdscript_exports.rst
- https://github.com/godotengine/godot/pull/96290
- https://github.com/godotengine/godot/issues/78587
- https://docs.godotengine.org/en/4.4/tutorials/scripting/c_sharp/diagnostics/GD0108.html
- https://docs.godotengine.org/en/4.4/tutorials/scripting/c_sharp/diagnostics/GD0111.html
- https://github.com/godotengine/godot/issues/37144
- https://github.com/godotengine/godot/issues/82756
- https://github.com/godotengine/godot/issues/95646
- https://github.com/godotengine/godot/issues/73905
- https://github.com/godotengine/godot/issues/58883
- https://github.com/godotengine/godot/issues/54999
- https://github.com/godotengine/godot/issues/79545
- https://github.com/godotengine/godot/issues/116902
- https://github.com/godotengine/godot/issues/83696
- https://github.com/godotengine/godot/issues/111635
- https://github.com/godotengine/godot/issues/98331
- https://github.com/godotengine/godot/issues/68427
- https://github.com/godotengine/godot/issues/110767
- https://github.com/godotengine/godot/issues/76884
- https://github.com/godotengine/godot-docs/issues/8801
- https://godotengine.org/article/dev-snapshot-godot-4-4-dev-3/
- https://github.com/HungryProton/scatter
- https://github.com/majikayogames/SimpleDungeons
- https://github.com/gdquest-demos/godot-4-procedural-generation
