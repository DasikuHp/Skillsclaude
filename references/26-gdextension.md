## 26. GDExtension (C++ y más allá)

GDExtension es la API oficial de Godot 4 (sucesora de GDNative) para registrar clases nativas (C++ via `godot-cpp`, también Rust/Swift/D via bindings de terceros) que el motor carga como `.so/.dll/.dylib`/`.framework` en runtime, **sin recompilar el motor**. No es la herramienta por defecto para gameplay.

### Enfoque nativo recomendado

Para un RPG 3D en 4.6, el ~95% del juego (controlador del jugador, inventario, diálogo, quests, cámara, UI, máquina de estados de combate) está limitado por llamadas a la API del motor, no por la velocidad del lenguaje. En cuanto tocas `get_node()`, `move_and_slide()` o instancias nodos, el overhead del lenguaje desaparece. Por tanto:

**Regla de decisión (orden de preferencia):**
1. **GDScript 2.0 tipado** (default). Las anotaciones de tipo lo aceleran de forma notable y dan autocompletado; cubre casi todo el gameplay sin ciclo de compilación.
2. **C# .NET 8** si ya tienes ecosistema .NET o lógica CPU-bound media. Caveat duro: **C# NO corre en web** (el renderer web es Compatibility).
3. **GDExtension C++** SOLO para: (a) hot loops numéricos *perfilados* (voxel/mesh gen, pathfinding sobre decenas de miles de agentes, fluidos, física custom, generación procedural pesada); (b) **envolver una lib C/C++ existente** (recast/detour, SQLite, FMOD, Steam SDK, un solver propietario); (c) distribuir un `Node`/`Resource` reutilizable como addon binario.

**NO uses GDExtension** para gameplay normal, para "ir más rápido" sin haber perfilado (la mayoría de cuellos en un RPG son draw calls / O(n²) mal escrito, no el lenguaje), ni para iteración rápida (añade ciclo SCons + recarga).

**GDExtension vs módulo custom del motor:**

| | GDExtension (`godot-cpp`) | Módulo custom |
|---|---|---|
| Build | Compilas TU lib aparte; el motor la carga en runtime | **Recompilas TODO el motor** + export templates |
| Distribución | `.so/.dll/.dylib` + `.gdextension`, drop-in en binario stock | Build propio del motor |
| Iteración | Minutos (hot-reload `reloadable=true`, frágil) | Horas |
| Acceso al core | Solo API pública expuesta | Total (internals) |

Si necesitas tocar internals del renderer no expuestos → módulo. En cualquier otro caso → GDExtension.

**Trampa C# ↔ GDExtension:** Godot **no genera bindings C# de una GDExtension**. Si tu proyecto es C#-first, llamar a tu clase C++ exige un puente C# → GDScript → C++. Tenlo presente al decidir arquitectura.

**Versión de `godot-cpp` (atasco #1):** la rama debe casar con tu Godot. Para 4.6 usa la rama/tag `4.6` (en `godot-cpp` v10.x el binding se versiona aparte y puedes targetear con `api_version`). Compatibilidad **hacia adelante, no hacia atrás**: una extensión compilada contra 4.3 corre en 4.4/4.5/4.6; una compilada contra 4.6 **no** carga en 4.5 ("API mismatch"). Fija `compatibility_minimum` lo más bajo que tus APIs permitan. Parte del **template oficial** (`godotengine/godot-cpp-template`), que trae CI multiplataforma, en vez de escribir el `SConstruct` a mano.

```bash
git submodule add -b 4.6 https://github.com/godotengine/godot-cpp
git submodule update --init --recursive
# Si tu Godot 4.6 es un build no oficial, regenera la API:
godot --headless --dump-extension-api    # -> extension_api.json
scons platform=linux custom_api_file=extension_api.json
```

**Los 4 archivos mínimos** (ver bloque de ejemplos para `.gdextension`, `register_types.cpp`, la clase C++ y el uso desde GDScript). Puntos no negociables:
- `entry_symbol` del `.gdextension` **idéntico** al nombre de la función `extern "C"`.
- Macro `GDCLASS(Clase, Base)` como primer miembro; sin ella la clase no se registra.
- `_bind_methods()` con `ClassDB::bind_method(...)` para TODO lo que use GDScript; un método que no se bindea ahí es **invisible** desde GDScript aunque compile.
- Registrar en `MODULE_INITIALIZATION_LEVEL_SCENE` para `Node`/`Resource`; nivel equivocado = clase no aparece en "Create New Node" sin error claro.
- Variantes: `GDREGISTER_CLASS` (instanciable), `GDREGISTER_ABSTRACT_CLASS` (base no instanciable), `GDREGISTER_VIRTUAL_CLASS`.

**Build SCons** (una lib por `platform × target × arch`; no hay binario universal salvo el `.framework` fat de macOS):
```bash
scons platform=linux   target=template_debug   arch=x86_64
scons platform=windows target=template_release arch=x86_64
scons platform=macos   target=template_release           # .framework universal
# use_static_cpp=yes para enlazar libstdc++ estáticamente (ver GLIBCXX abajo)
```
El sufijo del binario producido por SCons **debe** casar letra por letra con los paths del bloque `[libraries]`.

**.uid / migración (4.6):** los `.tscn` ya **no escriben `load_steps`** y los recursos usan `uid://` + ficheros `.uid` (desde 4.4). No inventes UIDs a mano; edita por `res://` path y deja que Godot resuelva. Tras importar un proyecto pre-4.4 corre **Project > Tools > Upgrade Project Files** (en headless, `--headless --import` regenera los `.uid`).

### Pitfalls y mensajes de error literales

- `No GDExtension library found for current OS and architecture (linux.x86_64) in configuration file`
  - **Trampa sutil y verificada (GH godot-docs #7864):** `compatibility_minimum = 4.6` **sin comillas** produce este error de OS/arch *engañoso*. Fix: `compatibility_minimum = "4.6"` (siempre entre comillas).
  - Otras causas: claves con formato viejo `<plat>.<arch>` en vez de `<plat>.<target>.<arch>`; o la lib no existe en `res://bin/` con el nombre exacto (no compilaste ese target/arch).
- `Can't open dynamic library: ...dll. Error: ... is not a valid Win32 application.` → mismatch de arquitectura (compilaste 32-bit, editor 64-bit). Recompila `arch=x86_64`.
- `Can't open dynamic library ... Error 126: The specified module could not be found.` (Windows) → la DLL existe pero le falta una **dependencia** (otra GDExtension, runtime MSVC, la lib C++ que envolviste). Copia las DLLs dependientes al mismo `bin/` y/o decláralas en `[dependencies]`; depura con `dumpbin /dependents`.
- `Can't open dynamic library ... libstdc++.so.6: version 'GLIBCXX_3.4.32' not found` (Linux/Flatpak) → compilaste contra un libstdc++ más nuevo que el destino. Fix: `use_static_cpp=yes`, o compila en toolchain viejo (manylinux / Steam Runtime).
- `Error 5: Access Denied` al abrir la DLL → antivirus o instancia previa de Godot con la lib en uso.
- Clase no aparece en "Create New Node" / `Ejemplo.new()` da "Identifier not found" → falta `GDCLASS`, nivel de init ≠ SCENE, o `entry_symbol` desincronizado.
- Método invisible desde GDScript sin error → falta `ClassDB::bind_method` en `_bind_methods()`.
- `GDExtension library cannot be reloaded while editor is running` / crash al recompilar (GH #66231, #88845, godot-cpp #1589) → hot-reload con `reloadable=true` es frágil. En dev: cerrar editor → rebuild → reabrir.
- Métodos ausentes solo en Release (GH #86206) → compila **ambos** `template_debug` y `template_release`; el export busca la variante release.
- Android: "Missing shared library in export" (godot-cpp #905) → faltan entradas por ABI (`android.debug.arm64`, `android.release.x86_64`, ...) o no compilaste con el NDK para esos ABIs.
- **Pitfall conceptual ABI:** MSVC vs MinGW vs distintas versiones de GCC/Clang dan ABIs incompatibles; binarios de SCons vs CMake/MSVC pueden diferir (godot-cpp #1459). Una toolchain por plataforma. Si el editor es build `precision=double`, la extensión también debe compilarse `precision=double` o no carga.

### Cómo no quedarte atascado

Una IA headless no ve el panel de errores ni el popup "Library not loaded". Fuerza la salida por terminal:
```bash
# Fuerza importar + registrar la extensión y volcar errores de carga
godot --headless --editor --quit-after 2 --verbose --path project/ 2>&1
# Alternativa: solo re-importar (regenera .uid)
godot --headless --import --path project/
# Aísla el error de carga de la lib (path exacto + código de error del SO)
godot --headless --verbose --path project/ 2>&1 | grep -i "dynamic library\|gdextension"
# Valida que un script que usa la clase nativa resuelve la API
godot --headless --check-only --script res://uses_example.gd --path project/
```
- "Edité el `.gdextension` pero no carga la clase" → Godot necesita **abrir el proyecto una vez** para escanear la extensión: `--headless --editor --quit-after 2` o `--headless --import`.
- "Mi cambio C++ no aparece" → no recompilaste; sigue cargando la `.dll` vieja. Rebuild SCons + reinicia (hot-reload no es fiable).
- Sin `--verbose` el fallo de carga de lib es **mudo**; con él ves el path exacto y el código de error.

### Addon vs construirlo

Antes de escribir C++: ¿lo resuelve C# (.NET 8)? Si sí, para. ¿Existe un addon GDExtension maduro? Reúsalo: **Terrain3D** (terreno grande, PC+Android), **GodotSteam** (Steam, doc de build excelente), git plugin, SQLite. Estos resuelven ABI/CI por ti con releases precompiladas — **verifica que traen binarios para TODAS tus plataformas de export**; un addon sin la arch de tu target falla la carga en export. Construye tú solo si: no existe addon, tienes un hot loop *medido*, o envuelves una lib propia/propietaria. En ese caso parte del **template oficial + CI multiplataforma** (Windows/Linux/macOS universal/Android×ABIs, debug y release ≈ decenas de combinaciones), nunca a mano.

**Caveat web (adjudicado):** GDExtension **SÍ funciona en web** en 4.6, pero es frágil. Requiere Emscripten reciente y build con dlink; el modo de threads de la lib (`.wasm` con/sin pthread) **debe coincidir** con el ajuste "Thread Support" del export, o falla con `LinkError` de memoria compartida (GH #95077, #94537). Cambiar el thread mode solo surte efecto **tras recargar el proyecto**; con threads ON el servidor debe servir cabeceras COOP/COEP (cross-origin isolation). El soporte en Firefox es más limitado que en Chromium (GH #105717). Recuerda: web = Compatibility, **C# no corre en web**. Si web es target serio, mantén el hot path en GDScript o detrás de un feature-flag con fallback GDScript.

**Veredicto ponytail:** el mejor GDExtension es el que no escribes. Tipa tu GDScript, perfila, y solo entonces baja a C++ — y solo el hot path o la lib que envuelves, nunca el gameplay. Reusa Terrain3D/GodotSteam antes que compilar nada. Si C# te basta y no apuntas a web, ni siquiera bajes a C++. El coste oculto de GDExtension no es escribir el código: es recompilar y mantener una lib por plataforma×target×arch para siempre.



> **Escalera ponytail:** rung 1 (casi nunca) · **net propio:** GDScript tipado o C# bastan; GDExtension solo para hot-loops nativos o libs C++.
