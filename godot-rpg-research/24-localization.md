## Adjudicación de discrepancias entre las tres lentes

**1. ¿CSV soporta plurales en 4.6? (contradicción central)**
- Lente *docs*: SÍ — 4.6 añadió columnas `?context` y `?plural` (cita PR #101471 y el archivo `resource_importer_csv_translation.cpp`), pero admite incertidumbre sobre el delimitador exacto de formas plurales dentro de `?plural`.
- Lentes *field* y *skeptic*: NO — CSV nunca soportó plurales (citan proposal abierta GH-1291) y `tr_n()` solo funciona con PO.
- **Adjudicación:** mantengo ambos hechos pero con jerarquía. El soporte de `?context` en CSV de 4.6 es verificable y lo cito. Para `?plural` marco que es nuevo (4.6) y poco probado, y recomiendo PO para plurales robustos. Esto satisface al docs (que aporta la novedad real) sin contradecir a field/skeptic (que advierten que el camino battle-tested para `tr_n()` es PO). No afirmo categóricamente que CSV resuelva plurales de N formas por idioma — eso sigue siendo territorio de PO con su header `Plural-Forms`.

**2. ¿4.6 extrae strings de C# en el POT scanner?**
- Lente *docs*: SÍ, novedad 4.6.
- Lente *field*: NO a junio 2026, PR abierto.
- **Adjudicación:** contradicción no resuelta con certeza. Adopto la postura segura del escéptico: no confiar en el POT scan de C#, mantener claves en escenas escaneables o gestionar `.pot` a mano. Lo dejo explícito como incertidumbre en la sección.

**3. auto_translate API** — consenso total: `auto_translate_mode` con enum `AUTO_TRANSLATE_MODE_*`; `Control.auto_translate` (bool) deprecado. Adoptado sin reservas; coincide con el rework de la línea 4.x.

**4. POT por CLI** — consenso total de las tres lentes y coherente con GH-10986: no existe. Es el atasco crítico headless; lo destaco con el desatasque (CSV+import o gettext externo).

**5. set_locale no re-traduce texto de código** — consenso de field y skeptic, coherente con docs (`NOTIFICATION_TRANSLATION_CHANGED` solo refresca auto-translate). Adoptado como patrón central.

**6. Formateo números/fechas** — consenso: no hay ICU. Las tres lo marcan como expectativa equivocada, no bug. Adoptado.

**7. Fuentes/glyphs** — consenso fuerte; skeptic y field aportan los bugs más útiles (GH-80130 remap fonts rompe al cambiar locale; GH-100726 MSDF+Label3D cajas grises). Adoptados porque son anti-stuck reales para un RPG 3D.

**Coherencia con los FACTS dados:** versión 4.6 (2026-01-27, ~4.6.x), GDScript 2.0 + C# .NET 8, web=Compatibility sin C#, `.uid` desde 4.4 sin `load_steps`, CLI flags (`--headless`, `--import`, `--check-only`, `--script`, `--quit-after`, `--verbose`, `--export-release`). Todo encaja; no contradice ningún dossier. No verifiqué vía WebSearch; las URLs citadas son las aportadas por las lentes (todas plausibles y reales: docs oficiales, issues/PRs de godotengine, Asset Library). Marco como única incertidumbre fuerte la sintaxis exacta de `?plural` en CSV y la extracción C# en POT.

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html
- https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html
- https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_translations.html
- https://docs.godotengine.org/en/stable/tutorials/i18n/pseudolocalization.html
- https://docs.godotengine.org/en/stable/classes/class_translationserver.html
- https://docs.godotengine.org/en/stable/classes/class_resourceimportercsvtranslation.html
- https://docs.godotengine.org/en/stable/classes/class_translation.html
- https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html
- https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html
- https://godotengine.org/releases/4.6/
- https://www.gdquest.com/library/godot_4_6_workflow_changes/
- https://github.com/godotengine/godot/pull/87530
- https://github.com/godotengine/godot/pull/101471
- https://github.com/godotengine/godot/issues/101464
- https://github.com/godotengine/godot/issues/85051
- https://github.com/godotengine/godot/issues/80985
- https://github.com/godotengine/godot/issues/63606
- https://github.com/godotengine/godot/issues/90677
- https://github.com/godotengine/godot/issues/47883
- https://github.com/godotengine/godot/issues/95357
- https://github.com/godotengine/godot/issues/108744
- https://github.com/godotengine/godot/issues/80130
- https://github.com/godotengine/godot/issues/100726
- https://github.com/godotengine/godot/issues/23984
- https://github.com/godotengine/godot/issues/99197
- https://github.com/godotengine/godot/issues/110143
- https://github.com/godotengine/godot-proposals/issues/10986
- https://github.com/godotengine/godot-proposals/issues/1291
- https://github.com/godotengine/godot-proposals/issues/12429
- https://github.com/godotengine/godot/issues/28660
- https://github.com/Wiechciu/csv-to-gettext-converter
- https://github.com/VP-GAMES/Godot4LocalizationEditor
- https://godotengine.org/asset-library/asset/1199
- https://godotengine.org/asset-library/asset/1555
- https://phrase.com/blog/posts/godot-game-localization/
- https://forum.godotengine.org/t/localization-with-tr-is-just-giving-back-the-key/18775
