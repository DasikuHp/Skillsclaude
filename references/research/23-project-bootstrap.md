## Adjudicación del debate — Tema #21

Los tres dossiers (docs / veterano / escéptico) coinciden en lo esencial. Solo hubo matices y un par de contradicciones reales. Cómo las resolví:

**1. `--quit-after 1` vs `--quit-after 2` / `--import` para el import headless (docs ⟂ escéptico).**
- Docs y veterano usan `godot --headless --import --quit-after 1`.
- El escéptico afirma, citando GH-77508 y GH-100465, que `--quit-after 1` aborta el reimport a medias y que hay que usar `--import` en su propio proceso o `--headless --editor --quit-after 2`.
- **Adjudicación:** prioricé al escéptico por ser el caso anti-stuck verificable y más conservador. `--import` es un flag de operación explícita que importa y sale por sí mismo, así que **no necesita** `--quit-after` (combinarlos es donde aparece el riesgo). En la sección recomiendo `godot --headless --import --path .` en proceso aparte, y `--headless --editor --quit-after 2` como fallback cuando el proyecto nunca se abrió. Mantengo `--quit-after 2` para smoke tests (no para reimport). Esto reconcilia las tres lentes sin perder el matiz crítico.

**2. `.import` y `.uid`: ¿commitear o ignorar?** Las tres lentes coinciden con fuerza: **commitear ambos, ignorar solo `.godot/`**. Sin contradicción; lo mantengo como regla de oro.

**3. `export_presets.cfg`: ¿versionar?** Docs lo deja "opcional según secretos". Veterano y escéptico precisan que desde 4.1 los secretos van a **`export_credentials.cfg`** (separado), por lo que `export_presets.cfg` se versiona e `export_credentials.cfg` se ignora. **Adjudiqué a favor del matiz veterano/escéptico** (más preciso y verificable), añadiendo la salvaguarda "si aún tienes secretos inline, ignóralo".

**4. Autoría de addons (corrección de premisa del tema).** Las tres lentes confirman: GLoot es de **`peter-kish`** (no "peter1745"), Beehave de **`bitbrain`**. Lo dejé explícito.

**5. Compatibilidad 4.6 de los addons.** El escéptico hace una nota de calibración honesta: no pudo confirmar un tag de release explícito "4.6" para Phantom Camera / Beehave (resultados muestran `godot-4.x` / 4.4). Docs y veterano sí afirman soporte. **Adjudicación conservadora:** mantengo los addons como curados pero el checklist exige "verifica la página de releases del addon contra 4.6 antes de fijar versión", y marco LimboAI como dependiente de v1.6.0+ para 4.6 (las tres lentes coinciden en que <1.6.0 rompe). No inventé números de versión.

**6. LimboAI naturaleza (GDExtension/módulo C++).** Veterano y escéptico subrayan que NO es un `addons/` puro: necesita binario por plataforma y complica/imposibilita web. Docs lo menciona de pasada. Incorporé el matiz anti-stuck (mensaje de error de carga + recomendación de Beehave para web/CI).

**7. Estructura de carpetas.** Docs propone `src/scenes/assets/data`, veterano y escéptico `autoload/actors/systems/world/ui/data/assets`. Ambas son válidas; sinteticé la **híbrida feature-local + type-global** que las tres avalan, usando el árbol más orientado a RPG del veterano/escéptico por ser más concreto.

**8. GH-110767 (AnimationPlayer String→StringName).** Las tres coinciden: afecta **props de nombre de animación, NO nombres de track**. El escéptico añade la lista exacta de props y la señal/`get_queue()`. Incorporé ese detalle por su valor anti-stuck.

Descarté: nada sustancial. Todo el material era útil; consolidé duplicados (renderer, .gitignore, CLI) y prioricé los mensajes de error literales del escéptico por ser el objetivo declarado (que una IA headless no se atasque).

## Fuentes
- https://godotengine.org/releases/4.6/
- https://godotengine.org/article/maintenance-release-godot-4-6-1/
- https://docs.godotengine.org/en/4.6/tutorials/physics/using_jolt_physics.html
- https://docs.godotengine.org/en/4.6/tutorials/scripting/singletons_autoload.html
- https://docs.godotengine.org/en/4.6/tutorials/best_practices/project_organization.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/best_practices/version_control_systems.rst
- https://github.com/godotengine/godot-docs/blob/master/engine_details/file_formats/tscn.rst
- https://github.com/godotengine/godot-docs/issues/11707
- https://github.com/godotengine/godot-docs/blob/master/tutorials/migrating/upgrading_to_godot_4.6.rst
- https://godotengine.org/article/uid-changes-coming-to-godot-4-4/
- https://dev.to/ziva/godot-44-added-uid-files-everywhere-heres-what-they-actually-do-4e56
- https://forum.godotengine.org/t/should-we-still-include-export-cfg-and-export-presets-cfg-in-the-gitignore-file/96693
- https://forum.godotengine.org/t/project-files-that-can-safely-be-put-in-gitignore/127748
- https://github.com/godotengine/godot-demo-projects/blob/master/.gitignore
- https://github.com/godotengine/godot-demo-projects/issues/329
- https://github.com/godotengine/godot/issues/77508
- https://github.com/godotengine/godot/issues/95287
- https://github.com/godotengine/godot/issues/100465
- https://github.com/godotengine/godot/issues/108441
- https://github.com/godotengine/godot/issues/70796
- https://github.com/godotengine/godot/issues/111729
- https://knightli.com/en/2026/06/19/godot-renderer-forward-mobile-compatibility/
- https://github.com/dialogic-godot/dialogic
- https://github.com/nathanhoad/godot_dialogue_manager
- https://github.com/ramokz/phantom-camera
- https://github.com/limbonaut/limboai
- https://github.com/limbonaut/limboai/releases
- https://github.com/limbonaut/limboai/issues/72
- https://github.com/bitbrain/beehave
- https://github.com/bitbrain/beehave/issues/322
- https://github.com/peter-kish/gloot
- https://godotengine.org/asset-library/asset/1368
- https://github.com/bitwes/Gut
- https://github.com/godot-gdunit-labs/gdUnit4
- https://github.com/MikeSchulze/gdUnit4-action
- https://github.com/abmarnie/godot-architecture-organization-advice
- https://forum.godotengine.org/t/need-help-with-an-unable-to-load-addon-script-from-path-error/112822
- https://forum.godotengine.org/t/animationplayer-play-animation-name-returns-animation-not-found-animation-name-error/37952
