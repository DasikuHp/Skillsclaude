## 16. Auto-verificación headless, CLI y testing

> **Para una IA que NO ve el editor.** El objetivo de este tema es cerrar el lazo **edito → compruebo → corrijo** sin ventana. La pieza central es `godot --headless` + **parseo de stdout/stderr** (no del exit code en la mayoría de los pasos). Versión de referencia: Godot 4.6.x (release 2026-01-27).

### Enfoque nativo recomendado

Pipeline obligatorio de 4 fases, de la más barata a la más cara. **No te saltes la Fase 0**: es la causa #1 de atascos.

```
0. --import --quit-after 2     → puebla .godot/ (caché de import, class_name, uid://)
1. --check-only / tool propio  → parseo de GDScript (fail-fast barato)
2. --headless --quit-after N   → smoke test: ¿arranca el MainLoop de verdad?
3. GUT / gdUnit4               → tests con exit code FIABLE
(4. --export-* )               → el último, el más frágil
```

**Regla de oro:** B, C y 4 dependen de que A haya poblado `.godot/`. La carpeta `.godot/` está en `.gitignore` por defecto, así que **en cualquier checkout limpio (lo que ve la IA al clonar) no existe**. Los errores de "recurso no importado" / "Could not find base class" / "Unrecognized UID" tras un clon limpio son **caché, no código**: no edites el script, reimporta.

#### CLI exacto de Godot 4.6 (flags verificados)

| Flag | Comportamiento |
|---|---|
| `--headless` | Sin ventana/GPU; implica driver dummy de video y audio. Obligatorio en CI. |
| `--path <dir>` | Directorio del proyecto (donde está `project.godot`). |
| `--import` | Reimporta assets y recrea `.godot/imported`, registra `class_name`/`uid://`. |
| `--quit-after <N>` | Sale tras **N** frames. Usa **2** para import (ver pitfall). |
| `--quit` | Sale tras el primer frame idle. **Evítalo para import** (ver pitfall). |
| `--check-only` | Carga y parsea el script y cierra (no ejecuta). Se usa con `--script`. |
| `-s, --script <res://...>` | Ejecuta un script (`SceneTree`/`MainLoop`/`EditorScript`). |
| `-e, --editor` | Modo editor (necesario para `EditorScript`/`EditorInterface`). |
| `--export-release <preset> <out>` / `--export-debug <preset> <out>` | Exporta con preset de `export_presets.cfg`. |
| `--verbose` (`-v`) | Salida detallada; útil para ver qué recurso falla. |
| `--doctool [path]` | Vuelca el XML de doc de clases (verificar APIs disponibles). |

Doc oficial: `https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html`

### Fase 0 — Warm-up de imports

```bash
# Puebla .godot/ : reimporta assets, registra class_name y uid://.
# NUNCA uses --quit aquí; usa --quit-after 2 (un frame importa, el segundo asienta dependencias).
godot --headless --path . --import --quit-after 2 --verbose
# Si persisten warnings de uid://, una SEGUNDA pasada los resuelve:
godot --headless --path . --import --quit-after 2
```

Algunas builds 4.x salen solas con un `--import` "pelado" y bastan; pero `--quit-after 2` es el patrón seguro y portable que no se cuelga ni sale antes de tiempo (GH-77508). Para proyectos migrados desde <4.4: corre **Project > Tools > Upgrade Project Files** una vez en el editor (o `godot --headless --editor --path . --quit-after 2`) para generar los `.uid`. 4.6 ya no escribe `load_steps` en los `.tscn`; no lo edites a mano.

### Fase 1 — Validación de sintaxis

Dos rutas. La primera es trivial; la segunda es **más fiable** y la recomendada para un agente.

```bash
# Ruta A: built-in, un archivo. ¡OJO con el exit code (ver pitfalls)! Decide por TEXTO:
out=$(godot --headless --path . --check-only --script res://scripts/player.gd 2>&1)
echo "$out"
if echo "$out" | grep -qiE 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script'; then
  echo "FAIL: parse error"; exit 1
fi
echo "OK"
```

```bash
# Ruta B (RECOMENDADA): tool script propio que valida TODOS los .gd y controla su PROPIO exit code.
godot --headless --path . --script res://ci/validate_all.gd
echo "exit=$?"   # FIABLE: lo fijamos nosotros con quit(N)
```

La Ruta B esquiva el bug histórico del exit code de `--check-only` porque **tú** controlas `quit(N)`. Ver `examples/validate_all.gd`.

### Fase 2 — Smoke test (¿ARRANCA, no solo compila?)

Compilar no es arrancar: un autoload que peta en `_ready()`, una escena principal con un nodo nulo, etc., solo se ven booteando.

```bash
# Arranca el juego real (autoloads + escena principal), corre N frames y sale.
# timeout + </dev/null son OBLIGATORIOS (ver pitfall del debugger invisible).
out=$(timeout 120 godot --headless --path . --quit-after 90 </dev/null 2>&1)
rc=$?
echo "$out"
if [ "$rc" = "124" ]; then echo "BOOT HANG (timeout)"; exit 1; fi
if echo "$out" | grep -qiE 'SCRIPT ERROR|Cannot call method|Nonexistent function|Invalid (get|set|call)|^ERROR:'; then
  echo "BOOT FAILED"; exit 1
fi
echo "BOOT OK"
```

### Fase 3 — Testing (exit code fiable)

| | **GUT** | **gdUnit4** |
|---|---|---|
| Lenguaje | GDScript | GDScript **+ C#/.NET 8** |
| Runner CLI | `-s res://addons/gut/gut_cmdln.gd ... -gexit` | `addons/gdUnit4/runtest.sh` |
| Exit code | 0 pasan / 1 falla (con `-gexit`) | 0/1 (JUnit XML + HTML) |
| Mocking/scene runner | básico | mocking, spies, fuzzing, scene runner |
| GitHub Action oficial | no | `gdunit4-action` |
| Code coverage | sí (addon comunitario) | no nativo |

```bash
# GUT (GDScript). Exit code FIABLE con -gexit.
timeout 300 godot --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit </dev/null
echo "exit=$?"   # 0 = todos pasan, 1 = algún fallo
```

```bash
# gdUnit4 (GDScript o C#). --ignoreHeadlessMode es OBLIGATORIO en headless.
export GODOT_BIN=/usr/local/bin/godot
chmod +x ./addons/gdUnit4/runtest.sh
./addons/gdUnit4/runtest.sh -a res://test --ignoreHeadlessMode --continue
```

**Recomendación:** GDScript puro + quieres coverage → **GUT**. Mezclas C# (.NET 8) o quieres scene runner/mocks + Action oficial → **gdUnit4**. **No mezcles los dos** en el mismo repo. En todos los casos exporta `GODOT_DISABLE_LEAK_CHECKS=1` para que los "ObjectDB instances leaked" no contaminen el exit code (libera igual tus objetos con `free()`/`autofree()`).

### Pitfalls y mensajes de error literales

**P1 — El exit code de `--check-only` MIENTE (el peor para una IA).** Históricamente devolvió siempre **0** con error de parseo (GH-33895), luego siempre **1** con script válido (GH-54087), y daba falsos positivos por chequear el script antes de registrar los autoloads (GH-78587), corregido por PR #110295. El bug genérico de no propagar exit no-cero está en GH-85062. Aun así no confíes en `$?` de `--check-only`.
→ **Fix:** no uses `$?` con `--check-only`. **Grepea `SCRIPT ERROR` / `Parse Error` en stdout/stderr**, o usa el tool script propio con `quit(N)`. El error literal sí es fiable y trae archivo:línea:
```
SCRIPT ERROR: Parse Error: Identifier "helth" not declared in the current scope.
          at: GDScript::reload (res://scripts/player.gd:42)
```
La IA usa ese `res://...:LINEA` para auto-corregir.

**P2 — Checkout limpio sin `.godot/` → "errores de código" que no lo son.** Mensajes literales:
```
ERROR: Failed loading resource: res://.godot/imported/icon.svg-<hash>.ctex.
       Make sure resources have been imported by opening the project in the editor at least once.
SCRIPT ERROR: Parse Error: Could not find base class "MyBaseClass".
WARNING: Unrecognized UID: "uid://abc123" — using text path instead.
```
→ **Fix:** Fase 0 (`--import --quit-after 2`), a veces **doble pasada**. (GH-71521, GH-93424, GH-115205; UID changes article.)

**P3 — El DEBUGGER INTERACTIVO INVISIBLE cuelga el CI para siempre.** Ante un error de runtime (o incluso sintaxis en carga, GH-85699) headless cae a un prompt esperando stdin:
```
Debugger Break, Reason: 'assertion failed'
debug>
```
La IA, que no ve nada, espera output que nunca llega.
→ **Fix:** SIEMPRE `--quit-after N` + `timeout 120 ...` + `</dev/null`. No es opcional. (GH-51387, GH-42465.)

**P4 — `--import --quit` / `--quit-after 1` salen ANTES de importar, o devuelven exit 1 espurio.** (GH-77508, GH-83449.)
→ **Fix:** usa `--quit-after 2`; en el paso de import **no juzgues por exit code**, verifica por log.

**P5 — Tool scripts con clases de editor revientan headless.** `@tool` que usa `EditorInterface`/`EditorPlugin` en runtime falla con parse error (GH-91713).
→ **Fix:** envuelve esas llamadas en `if Engine.is_editor_hint():` y nunca las invoques en runtime headless.

**P6 — `--check-only` NO muestra warnings.** Solo errores; los warnings del editor (typed dicts mal usados, narrowing) requieren LSP/editor (forum 124343/132160).
→ **Fix:** configura `[debug] gdscript/warnings/...` como errores en `project.godot` y trátalos en tests.

**P7 — Export "verde" con binario roto.** `--export-release` no siempre propaga exit no-cero (GH-83042/85062); se congela si falta `.godot/` (GH-95287, GH-71521); faltan templates:
```
No export template found at the expected path .../export_templates/4.6.stable/...
```
→ **Fix:** importa primero; verifica que el artefacto existe y pesa >0 (`test -s out`) + grep `ERROR` en el log. Templates en `~/.local/share/godot/export_templates/4.6.stable/` o usa imagen `barichello/godot-ci`. C# **NO** exporta a web (web = Compatibility, sin .NET).

**P8 — GUT/gdUnit4 "no encuentra tests" o exit 0 falso.** Falta `-gexit` (GUT) o `--ignoreHeadlessMode` (gdUnit4). GUT desalineado da `Invalid call. Nonexistent function ... GutRunner.gd:112` (GH-Gut 491). gdUnit4 desalineado: `Could not find type GdUnitHtmlReport` (GD-345) / load error en CI (GD-487).
→ **Fix:** añade el flag correcto; alinea la versión del addon con Godot 4.6; haz Fase 0 antes.

### Cómo no quedarte atascado

El bucle de auto-corrección de la IA es:
```
import (--quit-after 2)
  → validate_all.gd (exit code propio FIABLE)
  → leer "res://archivo.gd:LINEA" del SCRIPT ERROR
  → editar esa línea
  → re-validar
  → smoke (--quit-after 90, con timeout + </dev/null)
  → tests (GUT -gexit / gdUnit4 --ignoreHeadlessMode)
```
Tres mandamientos: **(1)** import primero, siempre; **(2)** la verdad está en stdout/stderr, no en `$?`, salvo en GUT/gdUnit4; **(3)** nunca lances headless sin `timeout ... </dev/null`.

### Addon vs construirlo

- **Validación de parseo: built-in + 20 líneas propias.** `--check-only` ya está en el engine; el tool script `validate_all.gd` (que controla su exit code) es más fiable que `--check-only` y trivial de construir → **construir gana aquí**.
- **Testing: usa addon, NO construyas.** GUT o gdUnit4 resuelven exit codes, mocking y scene runner; reinventar un runner es regalar bugs.

**Veredicto ponytail:** el mejor código aquí es el que no escribes en el runner de tests (GUT/gdUnit4 ya existen y dan el único exit code fiable), pero **sí** escribes el tool script de validación de 20 líneas: es más barato y más fiable que pelearte con un exit code de `--check-only` que lleva años mintiendo. Importa primero, lee el texto (no `$?`), y blinda cada invocación con `timeout`+`</dev/null` para no morir en un debugger que no puedes ver.



> **Escalera ponytail:** rung 4–5 (CLI nativa + GUT/gdUnit4) · **net propio:** scripts de verificación (CI); el motor ya valida y arranca headless.
