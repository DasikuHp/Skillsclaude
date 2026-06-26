## Adjudicación del Juez (Tema #16)

Los tres lentes coinciden en lo esencial (las 3-4 fases, el pipeline, los pitfalls de exit code e import cache). Coincidencias y contradicciones resueltas:

**Acuerdo total (alta confianza, verificado por WebSearch):**
- Exit code de `--check-only` NO fiable → parsear stdout/stderr. Confirmado: GH-33895 (siempre 0), GH-54087 (siempre 1), GH-78587 (falso positivo). WebSearch confirmó la regresión bidireccional.
- `--import --quit` / `--quit-after 1` rompen import; usar `--quit-after 2`. Confirmado por WebSearch (GH-77508, reportado en 4.0.3, vigente).
- `.godot/` en `.gitignore` → checkout limpio sin caché → errores que no son de código. Los tres lo dicen.
- GUT `-gexit` y gdUnit4 son el único exit code fiable. Los tres coinciden.

**Contradicción 1 — `--import` pelado vs `--quit-after 2`.** El lente *field* dice que en muchas builds 4.x `--import` solo ya sale y basta, y que `|| true` mitiga warnings de UID. *docs* y *skeptic* insisten en `--quit-after 2`. **Adjudicación:** prioricé lo verificable (GH-77508 documenta que `--quit`/`--quit-after 1` salen antes de tiempo; `--quit-after 2` es el patrón seguro). Recomiendo `--quit-after 2` como canónico y menciono que un import pelado a veces basta, más la doble pasada para UIDs. Esto preserva lo nicho de los tres sin contradicción.

**Contradicción 2 — tool de validación: `EditorScript` (skeptic) vs `extends SceneTree` (field).** El *skeptic* usa `EditorScript._run()` + `GDScript.new().reload()` y requiere `--editor`; el *field* usa `extends SceneTree._initialize()` + `load()` sin `--editor`. **Adjudicación:** preferí `extends SceneTree` porque NO requiere el subsistema de editor (más ligero, menos superficie de fallo headless, y el propio dossier docs advierte en P7 que EditorScript no corre 100% headless sin `-e`). Mantuve `load()` como forzador de parseo. Ambos controlan `quit(N)`, que es el punto clave. El ejemplo entregado es `extends SceneTree`, compile-ready en 4.6 (typed `Array[String]`, `DirAccess`, `path_join`).

**Contradicción 3 — el debugger interactivo invisible.** Solo el *skeptic* lo desarrolla a fondo (P3/ATASCO #3), aunque *docs* lo menciona de pasada (P2). **Adjudicación:** lo elevé a pitfall de primer nivel porque es exactamente el modo de fallo de "IA que no ve el editor" y es verificable (GH-51387, GH-42465, GH-85699). `timeout` + `</dev/null` + `--quit-after` como obligatorio.

**Descartado por dudoso:**
- La URL de descarga directa `4.6-stable` del YAML del lente *field*: el propio dossier admite no haberla verificado. No la incluí como hardcoded; recomiendo imagen `barichello/godot-ci` (verificada en los tres) en su lugar.
- `--disable-render-loop` y forzar `--display-driver headless --audio-driver Dummy`: redundante, `--headless` ya implica drivers dummy (lo dice *docs*). No lo puse como necesario.
- gdUnit4 repo bajo `godot-gdunit-labs` vs `MikeSchulze`: los dossiers mezclan ambos orgs. Mantuve ambas URLs reales que aparecieron en búsquedas sin afirmar cuál es canónica hoy; la Asset Store (`store.godotengine.org/asset/mikeschulze/gdunit4/`) es la referencia estable.

**Nicho preservado:** `GODOT_DISABLE_LEAK_CHECKS=1`, exit 1 espurio tras import (GH-83449), tool scripts de editor en runtime (GH-91713), `--check-only` sin warnings, export sin propagar error + `test -s`, falta de templates.

## Fuentes
- https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html
- https://github.com/godotengine/godot/issues/33895
- https://github.com/godotengine/godot/issues/54087
- https://github.com/godotengine/godot/issues/78587
- https://github.com/godotengine/godot/issues/85062
- https://github.com/godotengine/godot/issues/77508
- https://github.com/godotengine/godot/issues/83449
- https://github.com/godotengine/godot/issues/71521
- https://github.com/godotengine/godot/issues/93424
- https://github.com/godotengine/godot/issues/91713
- https://github.com/godotengine/godot/issues/95287
- https://github.com/godotengine/godot/issues/83042
- https://github.com/godotengine/godot/issues/51387
- https://github.com/godotengine/godot/issues/42465
- https://github.com/godotengine/godot/issues/85699
- https://github.com/godotengine/godot/issues/115205
- https://github.com/godotengine/godot/issues/73782
- https://github.com/godotengine/godot-proposals/issues/13048
- https://godotengine.org/article/uid-changes-coming-to-godot-4-4/
- https://gut.readthedocs.io/en/latest/Command-Line.html
- https://github.com/bitwes/Gut
- https://github.com/bitwes/Gut/issues/491
- https://store.godotengine.org/asset/mikeschulze/gdunit4/
- https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/
- https://github.com/godot-gdunit-labs/gdUnit4/issues/345
- https://github.com/godot-gdunit-labs/gdUnit4/issues/487
- https://medium.com/@kpicaza/ci-tested-gut-for-godot-4-fast-green-and-reliable-c56f16cde73d
- https://helpmetest.com/blog/godot-ci-cd-testing/
- https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
- https://github.com/abarichello/godot-ci
- https://forum.godotengine.org/t/cli-showing-gdscript-warnings/132160
- https://forum.godotengine.org/t/getting-gdscript-warnings-through-the-command-line/124343
