## 22. Localización (i18n)

Localizar un RPG 3D en Godot 4.6 es, en el 90% de los casos, un problema de **pipeline y fuentes**, no de API. Una IA que no ve el editor se atasca porque `tr()` "no traduce" y empieza a tocar código, cuando casi siempre la causa es que la traducción no está registrada, el `.csv` no se reimportó, el locale de test está vacío, o faltan glyphs (que ni siquiera es i18n). La señal diagnóstica que hay que internalizar:

> **¿`tr()` devuelve la CLAVE o devuelve CUADRITOS (□□□)?**
> Clave → problema de carga/locale/registro. Cuadritos → problema de fuente (fallback de glyphs). Son fallos distintos con fixes distintos.

### Modelo mental

Godot **no traduce strings: traduce claves** vía `TranslationServer`. Flujo real:

1. Escribes **claves** (`START_GAME`, no la frase) en código/escena.
2. `tr("START_GAME")` consulta `TranslationServer` con el locale actual.
3. `TranslationServer` busca en los `*.translation` (binarios) cargados para ese locale.
4. Si no hay match → `tr()` **devuelve la clave tal cual, sin error**. Este silencio es el atasco número uno.

Tres formas de obtener texto traducido:
- `tr()` / `tr_n()` (GDScript), `Tr()` / `TrN()` (C#).
- **auto-translate**: cualquier `Control`/`Window` con texto traduce su propiedad `text`/`title` según `auto_translate_mode`.
- **POT/CSV scanner**: extrae strings de `tr()` y de propiedades de texto de nodos para generar el catálogo.

### Enfoque nativo recomendado

El pipeline CSV/PO + `TranslationServer` + auto-translate es **nativo y suficiente** para un RPG; no necesitas addon para el runtime. La decisión de fondo es la fuente de strings:

- **gettext (PO/POT) — recomendado para un RPG con mucho texto y/o traductores comunitarios.** Un archivo por locale (diffs limpios en Git), soporta `msgctxt` (contexto), `msgid_plural` (plurales reales por idioma con N formas), y comentarios para traductores. Herramientas maduras: Poedit, Lokalize, Weblate (selfhosted, patrón estándar en open-source).
- **CSV — solo para proyectos pequeños o equipos que editan en Sheets.** Genera conflictos de merge feos y el escapado de comas/saltos rompe el parseo.

Pipeline canónico:

1. **Nunca hardcodear** texto visible. Claves en `MAYÚSCULAS_CON_GUION` para distinguirlas de frases (no hay restricción técnica, es convención anti-ambigüedad).
2. Fuente: CSV **o** PO/POT bajo `res://`.
3. Godot **importa automáticamente** y genera `*.translation` binarios en `.godot/imported/`.
4. Registrar esos `.translation` en **Project Settings > Localization > Translations** (persiste en `project.godot` como `locale/translations`).
5. Runtime: `TranslationServer.set_locale(locale)`.

#### APIs exactas (4.6)

`Object`:
- `tr(message: StringName, context: StringName = "") -> String`
- `tr_n(message: StringName, plural_message: StringName, n: int, context: StringName = "") -> String`

`TranslationServer` (singleton global):
- `set_locale(locale: String)` / `get_locale() -> String`
- `translate(message, context = "") -> StringName`
- `translate_plural(message, plural_message, n, context = "") -> StringName`
- `get_loaded_locales() -> PackedStringArray`
- `set_pseudolocalization_enabled(enabled: bool)` (QA: detecta strings sin traducir y overflow de UI)
- `compare_locales(a, b) -> int`, `standardize_locale(locale) -> String`

`Node` (auto-translate, ya unificado en la línea 4.x): propiedad `auto_translate_mode` con enum `AutoTranslateMode`:
- `AUTO_TRANSLATE_MODE_INHERIT` (default — hereda; la raíz equivale a ALWAYS)
- `AUTO_TRANSLATE_MODE_ALWAYS`
- `AUTO_TRANSLATE_MODE_DISABLED`

La antigua `Control.auto_translate` (bool) está **deprecada** — usa `auto_translate_mode`. Esto es exactamente donde la training data y los tutoriales viejos dan API obsoleta.

`OS.get_locale()` (p.ej. `"es_ES"`) / `OS.get_locale_language()` (solo `"es"`) para detectar el idioma del sistema al arrancar.

#### CSV (UTF-8, sin BOM)

```csv
keys,en,es,ja,?context,?plural
START_GAME,Start Game,Iniciar partida,ゲーム開始,,
MENU_OPEN,Open,Abrir,開く,verb,
GREET_PLAYER,"Hello, {0}!","¡Hola, {0}!","こんにちは、{0}！",,
```

Reglas que rompen a la gente:
- La primera columna **debe** llamarse `keys`. Las demás cabeceras son **códigos de locale válidos** (`en`, `es`, `ja`, `pt_BR`…), no nombres descriptivos. Un header como `comment` se interpreta como locale inválido y genera un `.translation` basura.
- **UTF-8 sin BOM**. Con BOM, la primera clave queda como `﻿keys` y toda la columna de claves se inutiliza (todo devuelve la clave). Mojibake (`Ã©`, `æ–‡å­—`) = encoding mal.
- Comas/saltos dentro de celda → entrecomillar con `"`; comilla interna se escapa duplicándola (`""`).
- Delimitador puede ser coma, `;` o tab (`ResourceImporterCSVTranslation`). Excel-ES suele guardar `;` + BOM: revisa ambos.
- **No dejes celdas vacías**: el comportamiento de "vacío" difiere entre CSV y PO (en PO `msgstr ""` devuelve la clave). Repite el texto fuente explícitamente.
- `?context` ya existía; `?plural` se añadió en PR #101471 (línea 4.x previa a 4.6, no es nuevo de 4.6). Solo se respeta la **primera** columna de cada tipo. Ver veredicto de plurales abajo.

#### gettext (PO/POT)

`Project Settings > Localization > POT Generation` → añadir escenas/scripts a escanear → **Generate POT** (botón en el editor). Traducir el `.pot` en Poedit → `es.po`, `ja.po` → añadir los `.po` en **Translations** (Godot los compila a `.translation`).

```po
msgid "%d enemy"
msgid_plural "%d enemies"
msgstr[0] "%d враг"
msgstr[1] "%d врага"
msgstr[2] "%d врагов"
```
Header crítico (CLDR por idioma):
```po
"Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<12 || n%100>14) ? 1 : 2);\n"
```
**El número de `msgstr[N]` DEBE coincidir con `nplurals`** del header, o el plural sale mal/falla. Valida antes de importar: `msgfmt -c es.po -o /dev/null` (si no imprime nada, está bien).

#### Runtime y cambio de idioma (el patrón que sí funciona)

`set_locale()` re-traduce automáticamente los `Control`/`Window` con auto-translate activo (reciben `NOTIFICATION_TRANSLATION_CHANGED`). **Pero el texto que asignaste por código con `tr()` ya es un String resuelto — NO se re-traduce solo.** Hay que re-asignarlo:

```gdscript
func set_language(loc: String) -> void:
    TranslationServer.set_locale(loc)   # "es", "ja", "en_US"...
    _refresh_texts()                     # re-aplica lo seteado por código

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        _refresh_texts()
```
Persiste el locale en `user://settings.cfg` y aplícalo en un autoload `_ready()` **antes** de mostrar la UI.

### Pitfalls y mensajes de error literales

- **`tr("START_GAME")` muestra `START_GAME` literal (sin error en consola).** Causas, por probabilidad: (a) el `.translation` no está en `locale/translations`; (b) el `.csv`/`.po` no se reimportó (`godot --headless --import`); (c) **Localization > Locale > Test** vacío y sin `set_locale()` (GH-80985); (d) locale no coincide (registraste `es_ES` pero pides `es`). El fallback `xx_YY`→`xx` fue arreglado en 4.4+ (PR #98743) y ya funciona en 4.6, pero sigue siendo buena práctica defensiva usar locales sin región salvo necesidad (GH-90677, ya cerrado); (e) la clave contiene `\n` (GH-47883 era `[3.x]`, legacy — aun así usa claves planas por higiene).
- **Texto sale como `□□□` (tofu) o invisible en CJK/árabe.** NO es i18n: la fuente no tiene esos glyphs. Fix en §fuentes.
- **`Error parsing CSV` / primera clave corrupta / mojibake.** CSV no es UTF-8 o tiene BOM. Re-guardar UTF-8 sin BOM.
- **`tr_n` da forma plural incorrecta o falla.** `nplurals` del header ≠ número de `msgstr[]`. Valida con `msgfmt -c`.
- **`ERROR: Cannot open file '...'` cargando recursos remapeados/fuentes en export** con "Convert Text Resources To Binary On Export" activado (GH-63606). Revisar remaps o desactivar esa opción.
- **Cambié locale y la UI no cambia.** Los labels seteados por código no se re-traducen solos: re-aplica en `NOTIFICATION_TRANSLATION_CHANGED`.
- **El nombre del héroe "Cloud" se traduce a "Nube".** auto-translate está ON por defecto y cualquier `text` que coincida con una clave se traduce. Pon `AUTO_TRANSLATE_MODE_DISABLED` en ese Label. Ojo bug GH-95357: `DISABLED` no se hereda más allá del primer hijo → ponlo **directamente** en el nodo problemático, no en un ancestro.
- **El POT tiene claves espurias que no pusiste.** Nodos en modo `Inherit` se cuelan como `msgid` (GH-108744).
- **`LineEdit.placeholder_text` no respeta el locale** (GH-23984): asignar con `tr()` en `_ready()` y re-aplicar al cambiar locale.
- **No hay formateo de números/fechas por locale** (no hay ICU/`Intl`; `TextServer.format_number()` solo mapea dígitos a glyphs alternativos, no cambia `1,000.5` ↔ `1.000,5`; proposals GH-12429, GH-28660 abiertas). Formatea a mano por locale o mete el formato como string traducible. Fechas: `Time.get_datetime_dict_*` + plantilla por idioma; los nombres de mes/día localízalos como claves.

#### Fuentes y glyphs (el pitfall visual que una IA ciega no detecta)

El texto japonés/coreano/árabe sale como `□□□` porque la fuente primaria no tiene esos glyphs. Fixes:
- En **desktop/móvil** Godot usa fuentes del SO como fallback automático (`SystemFont`) → CJK/emoji suelen resolverse solos. En **export web NO se cargan system fonts** → debes empaquetar la fuente.
- Añade **fallbacks Noto** al `FontFile`/`Theme`/`LabelSettings`: `Noto Sans JP`, `Noto Sans SC`, `Noto Sans KR`, `Noto Sans Arabic`. Una sola fuente con cadena de fallbacks que cubra todos los idiomas.
- **NO remapees fuentes por locale**: cambiar de idioma en runtime rompe la fuente remapeada (GH-80130). Usa fuente única + fallbacks.
- **MSDF + CJK = problemas**: atlas gigante; el bug de "cajas grises" en `Label3D` (GH-100726) fue una regresión de 4.4-dev arreglada en PR #100678, pero el punto de fondo sigue en pie: un atlas MSDF con CJK es pesadísimo. Para diálogos 3D usa DynamicFont (TTF/OTF) que rasteriza on-demand.
- Árabe/devanagari requiere **TextServer Advanced** (build por defecto lo trae; builds minimal/web pueden no traerlo → shaping roto, letras inconexas).

### Cómo no quedarte atascado (headless / sin editor)

Pasos que **solo existen en la GUI** pero persisten en `project.godot` editable:

```ini
[internationalization]
locale/translations=PackedStringArray("res://i18n/game.es.translation", "res://i18n/game.ja.translation")
locale/test="es"
locale/translations_pot_files=PackedStringArray("res://main.gd", "res://ui/menu.tscn")
```

- **Regenerar `.translation` sin editor:** `godot --headless --import --path /ruta/proyecto` (genera los binarios en `.godot/imported/` a partir de CSV/PO). Sin esto el `.translation` referenciado no existe.
- **Registrar traducciones sin GUI:** editar `locale/translations` y `locale/test` en `project.godot` a mano. Usa **rutas `res://` explícitas, no UID**, para robustez en CI.
- **Verificar el pipeline:** un `--script` que cargue y haga `TranslationServer.set_locale("es"); print(tr("START_GAME"))`:
  ```
  godot --headless --quit-after 1 --script res://tools/i18n_check.gd --verbose
  ```
- **Trampa de orden:** editar el CSV NO basta. Hay tres pasos: (1) `--import` regenera `.translation`; (2) registrar en `project.godot`; (3) `locale/test` o `set_locale`. Saltarse cualquiera → clave cruda.
- **POT por CLI NO EXISTE** (GH-10986: ningún flag, ninguna API GDScript). Una IA que intente `godot --headless --generate-pot` fracasa. En CI: usa flujo **CSV + `--import`**, o genera/compila PO con **gettext externo** (`xgettext` para extraer, `msgfmt es.po -o es.mo` para compilar) y versiona el catálogo en Git.
- **`.uid` / Upgrade Project Files:** desde 4.4 los recursos usan `uid://` + ficheros `.uid` y 4.6 ya no escribe `load_steps` en `.tscn`. Si editas rutas a mano y rompes los `.uid`, los `.translation` referenciados por UID no cargan → `godot --headless --import` o **Project > Tools > Upgrade Project Files**.

#### C# — avisos de plataforma

- Firmas: `Tr(message, context)`, `TrN(message, pluralMessage, n, context)`, `TranslationServer.SetLocale(...)`. `Tr()` == `tr()`.
- **C# NO corre en export web** (renderer Compatibility, sin .NET). Si el RPG apunta a web, la capa de i18n debe ser GDScript.
- Extracción de strings C# en el POT scanner: el dossier de docs afirma que 4.6 ya extrae `Tr`/`TrN`; el veterano sostiene que seguía sin extraerse a junio 2026. **No confíes en ello**: mantén las claves usadas en C# también referenciadas en una escena escaneable, o añade esos `msgid` al `.pot` a mano.

### Addon vs construirlo

- **Construir (por defecto):** el pipeline nativo (CSV/PO, `tr`/`tr_n`, `TranslationServer`, auto-translate, pseudolocalization) es suficiente. No necesitas addon para el runtime.
- **Edición de catálogo:** *Godot4LocalizationEditor* (`VP-GAMES`, asset #1199) o *Localization Editor* (asset #1555) dan una tabla GUI; útiles para autoría manual, inútiles para flujo headless (son GUI).
- **CSV↔gettext:** `Wiechciu/csv-to-gettext-converter` si autoras en Sheets pero entregas PO a traductores en Git.
- **Traductores:** Weblate (selfhosted) o Poedit/Lokalize. Para open-source comunitario, Weblate + PO es el estándar.
- **Evita** soluciones que reimplementan su `TranslationServer` o cargan JSON propio en runtime: pierdes auto-translate de nodos y el scanner de catálogo.
- Ningún addon resuelve el gap de POT-por-CLI; es del engine (GH-10986).

**Veredicto ponytail:** no escribas tu propio sistema de traducción. Usa claves + `tr()`/`tr_n()` + `TranslationServer` y deja que el auto-translate de los nodos `Control` haga el trabajo gratis; tú solo re-aplicas en `NOTIFICATION_TRANSLATION_CHANGED` los textos que seteaste por código. Para un RPG serio elige **PO/gettext** (plurales reales, contexto, Git, Weblate); el CSV es la opción rápida pero su columna `?plural` (añadida en PR #101471, línea 4.x previa a 4.6) está menos probada que el flujo gettext, así que para plurales robustos sigue siendo más seguro PO. El 90% de tu esfuerzo anti-stuck no está en la API sino en tres cosas: reimportar (`--import`), registrar en `project.godot`, y empaquetar fuentes con fallbacks Noto. Lo que NO existe (formateo de números/fechas por locale, POT por CLI) no lo busques: hazlo con gettext externo o a mano.



> **Escalera ponytail:** rung 4 (tr/TranslationServer) · **net propio:** claves + CSV/PO; el motor traduce nodos Control solo.
