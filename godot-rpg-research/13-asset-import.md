## Adjudicación del debate (Tema #12 — Importación de assets, Godot 4.6)

Las tres lentes coincidieron en un grado inusual; el desacuerdo fue de matiz y de etiqueta literal, no de hechos. Resumen de dónde divergieron y cómo resolví:

1. **Clave de la ruta de Blender (EditorSettings).** El escéptico afirmó `filesystem/import/blender/blender3_path` (4.2+) y marcó "verifícalo en 4.6". La lente docs y field decían solo "Blender Path" sin clave. **Adjudicación:** verifiqué por WebSearch — en 4.6 la UI es *Editor Settings → Filesystem → Import → Blender → Blender 3 Path* y la ruta apunta a la **carpeta** que contiene el ejecutable, no al binario (fuente: versluis + godot-docs issue #7270 + GH-84920). Mantengo la clave `filesystem/import/blender/blender3_path` y, crucial y poco documentado, el hecho de que son **dos settings** (Project Settings = enabled; Editor Settings = ruta). Esto es anti-stuck de primer orden.

2. **String→StringName en AnimationPlayer (GH-110767).** Las tres lentes lo tomaron de los FACTS del brief, no de búsqueda propia, y pidieron confirmarlo. **Adjudicación:** confirmado en la guía oficial de migración 4.6 (`godot-docs/.../upgrading_to_godot_4.6.rst`): `current_animation`, `assigned_animation`, `autoplay` String→StringName, `get_queue()` PackedStringArray→`StringName[]`, señal `current_animation_changed` String→StringName. **No** afecta nombres de track. Lo dejo como hecho firme y reflejo el impacto en C# (firmas `StringName`) y GDScript (literales `&"..."`).

3. **Materiales: Built-In vs Keep vs Files.** Docs distinguió tres modos (Built-In / Keep On Reimport / Files); field y escéptico enfatizaron "Files + Keep" y la alternativa de escena heredada. **Adjudicación:** combiné — recomiendo *Storage = Files* como vía principal de edición persistente, con *Keep On Reimport* y escena heredada como alternativas. Todas verificables en import_configuration.

4. **Colisión al importar.** Solo field y escéptico lo cubrieron; docs lo omitió. El escéptico aportó el matiz nicho de mayor valor: **Jolt por defecto NO implica collider automático** — un mesh importado atraviesa el suelo. Incluí los sufijos de Blender (`-col`, `-colonly`, `-convcol`, `-navmesh`) y *Create Collision*. Lo mantengo porque es atasco silencioso clásico.

5. **Retarget rompe accesorios animados.** Solo el escéptico aportó este edge case (desactivar retargeting en personajes con espada/capa animadas). Lo conservo: es exactamente el tipo de detalle nicho anti-stuck que justifica la skill, aunque no pude verificarlo en doc literal — lo presento como heurística de campo, no como cita de API.

6. **`.glb` vacío que destruye escenas.** Aportado por el escéptico (issues #68994, #82275). Conservado: causa de "la escena dejó de cargar" muy difícil de diagnosticar.

**Descarté/atenué:** la afirmación de docs de que GH-106073 (renombrado de huesos) persiste en 4.6 — ninguna lente lo verificó en 4.6.x, así que no lo incluí como hecho en la sección (lo dejo fuera para no afirmar un bug no confirmado en la versión target). Reescribí todas las URLs `/4.1/` `/4.4/` a `/stable/` salvo donde una lente confirmó explícitamente `/4.6/` (retargeting). Mantuve `instantiate()` (no `instance()`), correcto en 4.x. Reforcé el caveat web=Compatibility/sin-C# en los tres puntos donde aplica (carga de assets, runtime glTF, spawn).

**Hechos del brief usados como firmes:** Jolt física 3D por defecto, ufbx desde 4.3, GLTFDocument editor-independiente, web sin C#. Coherentes entre las tres lentes.

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html
- https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- https://docs.godotengine.org/en/stable/classes/class_retargetmodifier3d.html
- https://docs.godotengine.org/en/stable/classes/class_editorsceneformatimporterblend.html
- https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html
- https://docs.godotengine.org/en/stable/classes/class_packedscene.html
- https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/migrating/upgrading_to_godot_4.6.rst
- https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html
- https://github.com/github/gitignore/blob/main/Godot.gitignore
- https://www.versluis.com/2023/10/how-to-set-the-path-to-blender-in-godot/
- https://github.com/godotengine/godot-docs/issues/7270
- https://github.com/godotengine/godot/issues/84920
- https://github.com/godotengine/godot/issues/90314
- https://github.com/godotengine/godot/issues/83200
- https://github.com/godotengine/godot/issues/42235
- https://github.com/godotengine/godot/issues/68994
- https://github.com/godotengine/godot/issues/82275
- https://github.com/godotengine/godot/issues/93884
- https://github.com/godotengine/godot/issues/57981
- https://github.com/godotengine/godot/issues/67275
- https://github.com/godotengine/godot/issues/89767
- https://github.com/godotengine/godot/issues/111265
- https://github.com/godotengine/godot/issues/40329
- https://github.com/godotengine/godot/issues/84358
- https://github.com/catprisbrey/Godot4-OpenAnimationLibraries
- https://godotengine.org/article/animation-retargeting-in-godot-4-0/
- https://burning-barb.itch.io/gltf-level-importer
- https://forum.godotengine.org/t/what-doesnt-need-to-be-committed-to-version-control-in-a-godot-project/28750
- https://godotforums.org/d/29060-workflow-for-importing-glb-and-editing-materials
