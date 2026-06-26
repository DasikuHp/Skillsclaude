## 19. Audio: música, SFX y buses

Godot 4.6 (lanzado 2026-01-27, rama ~4.6.x) trae un sistema de audio completo: nada de lo que un RPG open-source necesita (música persistente, pool de SFX, ducking, capas adaptativas) requiere middleware externo. El enrutado es siempre el mismo: **`AudioStreamPlayer*` → bus (por nombre) → cadena de `AudioEffect` → bus padre → … → `Master` → salida**.

### Enfoque nativo recomendado

| Necesidad | Clase / API 4.6 | Tipo |
|---|---|---|
| Música global / UI / 2D no espacial | `AudioStreamPlayer` | Node |
| SFX posicional 3D (RPG) | `AudioStreamPlayer3D` | Node |
| SFX posicional 2D | `AudioStreamPlayer2D` | Node |
| Volumen por categoría / mezcla | Audio Buses + `AudioServer` (singleton) | API |
| Pool de SFX en un solo nodo | `AudioStreamPolyphonic` + `AudioStreamPlaybackPolyphonic` | Resource |
| Música adaptativa por estado (combate↔exploración) | `AudioStreamInteractive` | Resource |
| Playlist secuencial/aleatoria con crossfade | `AudioStreamPlaylist` | Resource |
| Capas sincronizadas (stems) | `AudioStreamSynchronized` | Resource |
| Layout de buses persistido | `AudioBusLayout` (`.tres`) | Resource |

`AudioStreamInteractive/Playlist/Synchronized` viven en el módulo `interactive_music` (presente en builds oficiales desde 4.3). **Son Resources, no Nodes**: se asignan a `player.stream`, NUNCA `add_child(AudioStreamInteractive.new())`.

Arquitectura RPG canónica:
- **Música = autoload con `AudioStreamPlayer`** (sobrevive a `change_scene_to_*`).
- **SFX 3D del mundo = nodos `AudioStreamPlayer3D`** colgando del emisor (mueren con la escena, que es lo correcto).
- **SFX globales/UI = autoload con `AudioStreamPolyphonic`** (un nodo, N voces, sin instanciar nodos por disparo).
- **Buses sugeridos:** `Master → Music`, `Master → SFX`, `Master → UI`, `Master → Ambient`, `Master → Voice`.

#### El modelo de volumen: dB, no lineal (EL pitfall número uno)

`volume_db` y `AudioServer.set_bus_volume_db()` están en **decibelios**, no en [0,1]. `volume_db = 0.0` es ganancia unidad (sin cambio), `-80.0` es silencio efectivo. Conectar un slider lineal [0,1] directo a `volume_db` da basura: `volume_db = 0.5` es +0.5 dB (casi imperceptible), NO "mitad de volumen". Convierte con `linear_to_db()` / `db_to_linear()` (globales de `@GlobalScope`).

En 4.6 existen alternativas lineales verificadas que evitan toda la conversión manual:
- `AudioStreamPlayer*.volume_linear` (propiedad 0..1; Godot la convierte a `volume_db` internamente).
- `AudioServer.set_bus_volume_linear(idx, linear)` / `get_bus_volume_linear(idx)`.

Para una IA que quiera blindar el código, `volume_linear` y `set_bus_volume_linear` son la ruta menos propensa a errores. Si usas dB: piso de silencio en **-80**, NUNCA `linear_to_db(0.0)` (devuelve `-inf` → al tweenear produce `NaN` y silencio permanente).

#### Buses: direccionamiento mixto y fallback silencioso

El nodo direcciona por nombre (`bus: StringName`, def `&"Master"`); la API de servidor usa índice: `AudioServer.get_bus_index("Music")` devuelve **-1** si no existe. **Pitfall crítico y silencioso (verificado en docs):** asignar `player.bus = "Music"` cuando el bus no existe NO lanza error — hace fallback a `"Master"`. Síntoma típico para una IA ciega: "el slider de música también baja los SFX" (ambos cayeron a Master). Sonda diagnóstica:

```gdscript
assert(AudioServer.get_bus_index("Music") != -1, "Bus 'Music' inexistente -> fallback silencioso a Master")
```

El layout es un `AudioBusLayout.tres`, ruta en `project.godot` bajo `[audio] buses/default_bus_layout`. **El `.tres` gana al arrancar**: si creas buses por código y además hay un `.tres`, el archivo manda. Para persistir buses creados por código: `AudioServer.generate_bus_layout()` → `ResourceSaver.save(layout, "res://default_bus_layout.tres")`. En 4.6 los `.tres`/`.tscn` ya **no escriben `load_steps`** y los recursos usan `uid://` + ficheros `.uid` (desde 4.4); tras tocar archivos a mano corre **Project → Tools → Upgrade Project Files** o `godot --headless --import`.

#### SFX: polifonía vs pool

Por defecto `AudioStreamPlayer*.max_polyphony = 1`: un segundo `play()` **corta** el anterior. Dos enfoques para solapar:

- **Solapar UN tipo de sonido (pasos):** sube `max_polyphony` (p.ej. 8) en un solo player. Lo más simple.
- **Pool real con control individual:** `AudioStreamPolyphonic` como `stream`; `play_stream()` devuelve un ID por voz, y controlas `set_stream_volume(id, db)` / `stop_stream(id)`. `play_stream` devuelve `INVALID_ID` si se alcanzó `polyphony` (def 32).

**Cuándo NO usar el polifónico:** si tu lógica necesita "avísame cuando ESTE disparo terminó", `AudioStreamPlaybackPolyphonic` **no emite `finished` por stream** (issue abierto GH-88941). En ese caso usa un pool de `AudioStreamPlayer` reusados (cada uno emite su `finished`). El pool de nodos reusados también evita el churn de `new()`+`add_child()`+`queue_free()` por golpe, que causa stutter con muchas entidades.

#### Música adaptativa / crossfade

- `AudioStreamPlaylist`: clips secuenciales/aleatorios con `fade_time` (crossfade integrado, def 0.3s). Lo más simple para ambiente que rota.
- `AudioStreamInteractive`: tabla de transiciones (immediate / end-of-clip / beat boundary) entre clips por estado. Disparo por código: `player.get_stream_playback().switch_to_clip_by_name(&"Combat")`. La tabla se construye en el editor.
- `AudioStreamSynchronized`: capas (stems) en sync; subes/bajas volumen por capa con `set_sync_stream_volume(idx, db)`.

Para un crossfade simple de 2 temas (lo habitual en un RPG), **no necesitas estas clases ni un addon**: dos `AudioStreamPlayer` + un `Tween` sobre `volume_db` bastan (ver ejemplo). Reserva `AudioStreamInteractive` para cuando el compositor entregue la transition table hecha; anidar `Interactive`+`Synchronized` es frágil y poco documentado (las transiciones por beat se desincronizan si las capas difieren en longitud).

#### Ducking

- **Manual con Tween (recomendado, predecible):** al iniciar diálogo, `Tween` sobre `volume_db` del bus Music a -12 dB; al terminar, vuelve a 0.
- **Sidechain con `AudioEffectCompressor`:** propiedad `sidechain` (verificada como `StringName` = nombre del bus fuente). El compressor baja Music según el nivel de Voice. CAVEAT (GH-16036): el routing del sidechain históricamente tuvo bugs; verifica que el bus fuente exista y NO se envíe a sí mismo. Por eso el Tween manual es la opción "que no se atasca".

#### AudioStreamPlayer3D: atenuación y zonas acústicas

- `attenuation_model`: `INVERSE_DISTANCE` (def) / `INVERSE_SQUARE_DISTANCE` / `LOGARITHMIC` / `DISABLED`.
- `unit_size` (def 10.0): controla la curva de atenuación — el parámetro que la gente no toca ("se oye igual en todo el mapa" o "no se oye nada").
- `max_distance` (def 0.0 = sin límite, audible siempre): corta a cero y, clave para rendimiento, deja de mezclar lejos.
- **Zonas acústicas sin código:** un `Area3D` con `audio_bus_override = true` + `audio_bus_name = "Cave"` redirige todo `AudioStreamPlayer3D` cuyo `area_mask` case con la capa del área (cueva → bus con reverb; agua → bus con `AudioEffectLowPassFilter`). Idiomático.

**Pitfall confusión:** `unit_size` ≠ `max_distance`. Subir `unit_size` hace que llegue más lejos; `max_distance = 0` significa "infinito", no "cero alcance".

### Pitfalls y mensajes de error literales

- **`Condition "p_bus < 0 || p_bus >= buses.size()" is true.`** → pasaste `idx = -1` (de `get_bus_index` con nombre mal escrito) a `set_bus_volume_db`. Fix: chequear `!= -1`. Nombres case-sensitive.
- **`Attempt to call function 'play_stream' in base 'null instance'`** / C# `NullReferenceException` en `GetStreamPlayback` → llamaste `get_stream_playback()` antes de asignar un `AudioStreamPolyphonic` como `stream` y/o antes de `play()`. Fix: asigna stream → `add_child` → `play()` → *después* `get_stream_playback()`.
- **`play_stream(...)` devuelve `INVALID_ID` silenciosamente** → se alcanzó `polyphony`. Fix: sube `polyphony`.
- **`'GD' does not contain a definition for 'Linear2Db'`** (C#) → API 3.x. En 4.x usa `Mathf.LinearToDb` / `Mathf.DbToLinear`.
- **C#: el tween "no hace nada"** → usaste `"VolumeDb"` como property path. El path interno del motor es snake_case: `"volume_db"` (aunque la propiedad C# sea `VolumeDb`).
- **Impreso `-inf` + audio mudo permanente / `nan`** → `linear_to_db(0.0)`. Fix: floor en -80 o clamp el lineal a `0.0001`.
- **Sin error, simplemente silencio/reinicio al cambiar de escena** → el player colgaba de la escena liberada. Fix: autoload.
- **"loop=true en código y el OGG igual se corta"** → el loop de OGG/MP3 vive en `archivo.ogg.import`, NO en el recurso (GH-42671): *"the loop property on AudioStreamOggVorbis is only acknowledged by the editor, and the game uses instead the loop option set when importing"*. Fix: ver siguiente sección.
- **`finished → queue_free` y los nodos se acumulan** → clip marcado como loop en import nunca termina, nunca emite `finished` (GH-102479). Fix: no loopear SFX one-shot, o no atar `queue_free` a `finished` de un loop.
- **Audio 3D suena pero "sin dirección / centrado"** → no hay listener. Por defecto la `Camera3D` activa es el listener; si añades un `AudioListener3D` debes llamar `make_current()`.
- **Web export crash (GH-109728):** pausar el árbol con un player en `playback_type = PLAYBACK_TYPE_SAMPLE` reproduciendo `AudioStreamPlaylist/Interactive/Synchronized` crashea en wasm. Fix: en web usa `PLAYBACK_TYPE_STREAM` para esos streams compuestos.

### Cómo no quedarte atascado

Una IA que no ve el editor se clava sobre todo en metadata invisible (loop de import, listener, fallback de bus). Rutas accionables por CLI/código:

1. **Loop de OGG sin editor:** edita el sidecar `res://music/town.ogg.import`, en `[params]` pon `loop=true` y `loop_offset=0.0` (`loop_offset > 0` puede producir un click/pop al loopear — GH-64775; deja `0.0`). Para WAV: `edit/loop_mode=1` (Forward). Reimporta con `godot --headless --import` (editar el `.import` a mano NO reimporta solo).
2. **Loop garantizado 100% por código** (ignora el `.import`): `var s := AudioStreamOggVorbis.load_from_file("res://music/town.ogg"); s.loop = true; s.loop_offset = 0.0; player.stream = s`. La instancia cargada así no está atada al pipeline de import.
3. **Registrar autoload por código** (la IA no puede usar el botón): en `project.godot`, sección `[autoload]`, `MusicManager="*res://autoload/music_manager.gd"`. El `*` = enabled; sin él, stuck silencioso.
4. **Validación headless:** `godot --headless --import` tras tocar `.import`/bus layout; `godot --headless --check-only --script res://autoload/music_manager.gd` para validar sintaxis GDScript.
5. **Mono vs estéreo:** un OGG/WAV estéreo en `AudioStreamPlayer3D` no se panea bien; el audio posicional quiere fuentes **mono**.
6. **Guardas obligatorias:** "misma pista no reinicia" (`if _active.stream == stream and _active.playing: return`), `get_bus_index != -1` antes de usar el índice, piso de -80 dB en fades.

| Síntoma | Sonda por código/CLI | Causa raíz |
|---|---|---|
| Slider de música mueve los SFX | `AudioServer.get_bus_index("Music") == -1` | Bus mal escrito → fallback a Master |
| No se oye nada en 3D | ¿`Camera3D.current` o `AudioListener3D.make_current()`? ¿`unit_size`/`max_distance` sanos? | Sin listener o atenuación mal |
| Música no loopea pese a loop=true | leer/editar `*.ogg.import`; `godot --headless --import` | Loop vive en import (GH-42671) |
| Slider en 0 no silencia / volumen raro | ¿`linear_to_db`/`volume_linear`? ¿clamp? | Confundir dB con lineal |
| C# no compila: Linear2Db | `Mathf.LinearToDb` | API 3.x obsoleta |
| Nodos de SFX se acumulan / FPS cae | ¿clip loop + `finished→queue_free`? | GH-102479 |
| Música se reinicia al cambiar sala | ¿player en autoload? ¿guard misma pista? | Player en escena liberada |

### Addon vs construirlo

**Construir con nativo (sin addon)** cubre el 100% del RPG open-source: MusicManager persistente, pool de SFX, ducking, buses, atenuación 3D, zonas por `Area3D`, y música adaptativa (`AudioStreamInteractive/Playlist/Synchronized`, nativas desde 4.3). Solo considera **FMOD** (`github.com/utopia-rise/fmod-gdextension`) o **Wwise** vía GDExtension si tu equipo de audio YA trabaja en esas herramientas — coste: binarios nativos por plataforma, **no funcionan en export web**, complican CI/CLI. Para open-source casi nunca compensa.

**Veredicto ponytail:** el mejor código de audio es el que no escribes. Reusa `AudioStreamPlayer` + buses por nombre + `volume_linear` (o `linear_to_db`), deja que `Area3D` con `audio_bus_override` haga las zonas acústicas y que `AudioStreamPlaylist`/`Synchronized` hagan el crossfade y las capas. El único código propio que un RPG realmente necesita es el autoload `MusicManager` (porque la persistencia entre escenas no es nativa) y, opcionalmente, un pool de SFX. Todo lo demás ya está en el motor: no metas middleware ni reinventes la mezcla.



> **Escalera ponytail:** rung 4 (AudioStreamPlayer/buses) · **net propio:** un MusicManager autoload + pool de SFX; el bus layout es un .tres.
