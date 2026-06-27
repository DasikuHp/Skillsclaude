## 34. Arquitectura técnica (jun 2026)

Verdad accionable consolidada tras el debate Architect/Critic. Foco: decisiones FIRMES de arquitectura para un RPG 3D en Godot 4.6, cómo la skill `godot-46-rpg` las impone, y cómo Claude las aplica bajo PONYTAIL ("lazy, no negligente"). No son opciones: son defaults con triggers explícitos para desviarse. Todo verificado en runtime (PR #103403 y manifiesto de Summer confirmados via fetch).

### Estado jun-2026 (viable AHORA)

**Godot 4.6 (ene-2026) — el terreno.**
- **Jolt es la física 3D por defecto** en proyectos nuevos, ya no experimental. Es la decisión arquitectónica de mayor peso del año para un RPG 3D. Matiz crítico que se sostiene: Jolt internamente es multihilo, pero Godot **adapta sus tareas de vuelta al WorkerThreadPool genérico**, así que no se obtiene el paralelismo nativo total de Jolt; y **el physics server NO es thread-safe**. Regla dura: tocar física solo en `_physics_process` o vía `call_deferred`. ([releases/4.6](https://godotengine.org/releases/4.6/), [using_jolt_physics](https://docs.godotengine.org/en/4.6/tutorials/physics/using_jolt_physics.html), [godot-jolt #356](https://github.com/godot-jolt/godot-jolt/issues/356), [using_multiple_threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html))
- **LibGodot** (embeber el engine como librería) es lo que hace posible el patrón "engine vivo" de los MCP. **Patch PCK delta encoding** para updates pequeños, **SSR reescrito**. ([gamedeveloper.com — 4.6](https://www.gamedeveloper.com/programming/godot-4-6-is-here-with-a-fresh-look-and-a-promise-to-prioritize-workflow), [alternativeto.net — 4.6](https://alternativeto.net/news/2026/1/godot-4-6-debuts-modern-theme-jolt-physics-node-ids-and-libgodot-embed/))
- **IK vuelve como FAMILIA `IKModifier3D` sobre `SkeletonModifier3D`** — 7 solvers: `TwoBoneIK3D`, `ChainIK3D`, `SplineIK3D`, `IterateIK3D`, `FABRIK3D`, `CCDIK3D`, `JacobianIK3D` (corrección: el dossier original solo nombró 2). La pieza arquitectónica reusable nativa NO es "qué solver" sino que **IK es un stack de modifiers ordenado y determinista**: solve piernas (foot-IK terreno: `TwoBoneIK3D`, analítico) → look-at cabeza → jiggle de colas/tentáculos (`SplineIK3D`) → cadenas largas (`CCDIK3D`/`FABRIK3D`), cada modifier leyendo al anterior. Documentar el stack, no nombres sueltos. ([IK returns to 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/), [StraySpark — IK guide](https://www.strayspark.studio/blog/godot-46-inverse-kinematics-procedural-animation))

**Lenguaje (firme).** GDScript **tipado** es el default: gana en el bucle de iteración, editor, y **web export (C# sigue sin web export en 4.6 stable)**. Tipado estático da hasta ~59% en operaciones Vector2. C# solo por trigger duro (equipo con C# existente / port de Unity / dependencia .NET; edición .NET distinta de la standard). GDExtension/C++ solo para **hotspots medidos** (pathfinding masivo, simulación). Pitfall que se sostiene: **GDExtension no es invocable desde C# sin wrapper GDScript**. ([strayspark — GDScript vs C#](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language), [knightli.com — std vs .NET](https://knightli.com/en/2026/06/19/godot-standard-vs-dotnet-edition/), [dev.to — GDExtension](https://dev.to/gustavolr548/programming-with-gdextension-high-performance-c-in-godot-4-part-1-3c19))

**ECS vs nodos (firme, ponytail).** Postura oficial: Godot no tiene ECS nativo y es **deliberado** (los nodos ya favorecen composición). Adoptar ECS = renunciar al sistema de nodos y crear uno paralelo. Default de la skill: **patrón Entity-Component sobre nodos** (composición de hijos + Resources de datos). GECS (Asset Library 3481, queries O(1) cacheadas, serialización built-in) **solo** con miles de entidades homogéneas medidas (bullet-hell, swarm, simulación de aldea). Nunca como arquitectura de arranque. ([Why isn't Godot ECS](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/), [GECS asset 3481](https://godotengine.org/asset-library/asset/3481), [csprance — gecs](https://csprance.com/blog/gecs), [gdquest — entity-component-pattern](https://www.gdquest.com/tutorial/godot/design-patterns/entity-component-pattern/))

**Datos y save (firme — el borde de seguridad más importante del foco).** Custom Resources son óptimos para stats/items/skills/loot por type-safety. PERO los Resources **pueden ejecutar código embebido** (scenes/scripts son Resources): cargar un `.tres`/`.res` de save editado por el jugador con `ResourceLoader.load()` es **RCE real** (contexto GodLoader). Regla dura:
- **Definiciones de diseño → Resources** (vienen del PCK, confiables).
- **Save runtime → `FileAccess.store_var()`** (binario nativo, soporta Vector3/Color) **o JSON** (no ejecuta nada).
- **NUNCA `ResourceLoader.load()` sobre `user://`** (input del jugador). Si hay que cargar Resources de fuente no confiable: **Godot Safe Resource Loader / WCSafeResourceFormat con whitelist**.
([uhiyama-lab — save/load](https://uhiyama-lab.com/en/notes/godot/save-load-system/), [gdquest — save_game_godot4](https://www.gdquest.com/library/save_game_godot4/), [proposal #10968](https://github.com/godotengine/godot-proposals/issues/10968), [GodLoader statement](https://godotengine.org/article/statement-on-godloader-malware-loader/))

**Autoloads / señales (firme, anti-over-engineering).** Presupuesto **5-10 autoloads máx**; no guardar estado de escena en autoloads (persisten → leaks; resetear en `_ready()`); **nunca dependencias circulares** (deadlock de init → usar señales/DI). Event bus solo como último recurso (antes: grupos, conexión directa). ([gdquest — event-bus-singleton](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/), [singletons_autoload](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html))

**Accesibilidad (firme, INVARIANTE de primer nivel — no era opcional y faltaba por completo).** El mandato ponytail prohíbe recortarla. Lo nativo reusable:
- **AccessKit integrado en Godot 4.x** (lectores de pantalla en UI). Todo `Control` interactivo generado por MCP debe tener `accessibility_name`/rol.
- **InputMap remapeable runtime** (en Summer: tool `summer_input_map_bind`), escala de fuente UI, subtítulos/captions para diálogo y SFX, **no codificar estado solo por color** en el HUD de combate (daltonismo), opción de reducir flashing/screen-shake.
- **Invariante ejecutable** (mismo nivel que el save seguro): "ningún `Control` interactivo sin nombre accesible; ninguna acción sin entrada `InputMap` remapeable" → falla la verificación, igual que un `ResourceLoader.load` sobre `user://`.

**Red / single-vs-multi (firme — supuesto que debe declararse).** Un RPG sin esta decisión está incompleto de raíz. Default: **single-player declarado explícitamente en GameSoul**. Si hay trigger de co-op/MMO-lite, lo nativo (`MultiplayerSynchronizer`/`MultiplayerSpawner`/RPC) cambia TODO: autoridad de servidor sobre stats (anti-cheat), el save deja de ser local-trust, las definiciones-Resource deben ser idénticas cliente/servidor (hash check), y "física solo en `_physics_process`" se cruza con determinismo de red. Omitir la decisión = drift garantizado.

**Los dos MCP — estado real verificado.**
- **Summer Engine** (`SummerEngine/summer-engine-agent`, MIT): drop-in de Godot 4, MCP en **`localhost:6550`** con **44 tools `summer_*`** (verificado en el README via fetch; el "30+" era dato viejo). Tools relevantes: `summer_add_node`, `summer_set_prop`, `summer_instantiate_scene`, `summer_get_scene_tree`, `summer_inspect_node`, `summer_batch`, `summer_get_script_errors`, `summer_get_diagnostics`, `summer_get_debugger_errors`, `summer_play`/`summer_stop`/`summer_is_running`, `summer_input_map_bind`, `summer_generate_3d/_image/_audio`. **Health-check: `summer doctor --json`** (verifica Node, CLI, login, engine, MCP). Memoria en `.summer/GameSoul.md` + `.summer/memory/`. ([github — summer-engine-agent](https://github.com/SummerEngine/summer-engine-agent), [README](https://github.com/SummerEngine/summer-engine-agent/blob/main/README.md), [summerengine.com/godot-ai-mcp](https://www.summerengine.com/godot-ai-mcp))
- **Godot MCP HTTP**: `Coding-Solo/godot-mcp` (lanzar/run/debug), `Dokujaa/Godot-MCP` (crear scenes/scripts, leer errores), GDAI (`gdaimcp.com`), StraySpark (comercial). Requisitos típicos: Godot 4.4+, Node 18+. ([Coding-Solo](https://github.com/Coding-Solo/godot-mcp), [Dokujaa](https://github.com/Dokujaa/Godot-MCP), [gdaimcp.com](https://gdaimcp.com/), [strayspark — MCP setup](https://www.strayspark.studio/blog/godot-mcp-setup-claude-code-2026))

**Verificación headless — racional CORREGIDO.** El bug "`--headless --import --quit` siempre emite errores / exit 1" (#103398) **YA fue arreglado por PR #103403, merge mar-2025, en 4.5 y cherry-pick a 4.4.1** (verificado via fetch). En 4.6 ese falso-fallo NO existe. Consecuencia: el lazo de verificación de 2 fases **sigue siendo buena práctica** (idempotencia, separar registro de validación) pero **por un racional distinto**: fase 1 (`import`) puebla clases/recursos; fase 2 (`--headless --validate`) valida con el grafo ya poblado. **NO tragarse exit 1 a ciegas** — en 4.6 un exit 1 probablemente SÍ es fallo real: capturar stderr y distinguir errores de parser/load del ruido. Tragar el exit code a ciegas es ahora el comportamiento negligente. Pitfall que se sostiene: `ResourceLoader.load_threaded_request()` puede devolver scenes incompletas (nodos sin props de script) → no asumir éxito. ([PR #103403](https://github.com/godotengine/godot/pull/103403), [4.4.1 release](https://godotengine.org/article/maintenance-release-godot-4-4-1/), [#103398](https://github.com/godotengine/godot/issues/103398), [#108054](https://github.com/godotengine/godot/issues/108054))

### Simbiosis con el flujo de la skill (pasos accionables)

Flujo: `SKILL.md` (dispatcher + workflow + lazo) → `references/` → `scripts/` → `hooks/` → `commands/` → `agents/`.

1. **Dispatcher (SKILL.md):** una **matriz de decisión de una pantalla** que enruta las preguntas de arranque (lenguaje, nodos-vs-ECS, datos/save, presupuesto autoloads, hilos, single-vs-multi) a la ref `34`. **Separar este eje del de detección de backend** (corrección del Critic C2): el backend NO se pregunta al usuario, se detecta por **probe de capacidad (`summer doctor --json`)**. Mezclar enrutado-de-conocimiento con detección-de-runtime acopla ejes ortogonales.

2. **Lazo de verificación (`verify_loop.sh` + `validate_all.gd`):** verificación **en engine vivo como PRIMARIA** cuando el backend existe (`summer_play` + `summer_get_diagnostics`/`summer_get_script_errors` dan estado de runtime real, no solo compilación, y evitan reimportar cada ronda → coste mucho menor). **Headless 2-fases como FALLBACK degradado** (invierte la jerarquía del dossier original). El convergence loop usa el conteo de errores como métrica.

3. **`validate_all.gd` es la FUENTE DE VERDAD ejecutable** (inversión vs prosa duplicada): parse de todos los `.gd`; scan de `ResourceLoader.load` sobre `user://`; conteo de autoloads bajo presupuesto; sin dependencias circulares entre autoloads; sin acceso a physics server fuera de `_physics_process`; **invariante de accesibilidad** (Control con `accessibility_name`/rol; acciones en `InputMap`); carga de definiciones-Resource. Las refs CITAN estos asserts en vez de re-describir las reglas (evita drift entre `34`/`99`/prosa).

4. **Contrato de capacidades MCP (ref 30):** mapear cada acción de arquitectura a tool real (`summer_add_node`/`summer_set_prop` para construir; `summer_get_scene_tree`/`summer_inspect_node` para verificar invariantes; `summer_play`+`summer_get_diagnostics` como verificación viva). El backend NO es binario sino **estado degradable**: `summer doctor --json` antes de cada ronda; si el engine vivo (`:6550`) muere/timeout/devuelve árbol stale → **fallback EN CALIENTE a headless**. Sin esto, "engine vivo" es punto único de fallo silencioso.

5. **GameSoul.md / `.summer/memory/` como ancla anti-drift:** escribir las decisiones firmes (lenguaje, save format, presupuesto autoloads, ECS-sí/no, **single/multi**) para que no driften entre sesiones. Mejor palanca simbiótica con Summer.

6. **Convergence loop con recuperación (corrige hueco del dossier):** tras cada ronda de mutaciones → verificar → si error-count baja, continuar; si **sube**, **rollback al último estado verde** (checkpoint git automático antes de cada ronda, o snapshot de Summer). Tope de iteraciones. **Detección de OSCILACIÓN**: mismo error-set visto 2 veces = está orbitando (arregla A rompe B, arregla B rompe A) → distinto de "no baja en N". Escalar a humano **SOLO tras revertir al último verde** (escalar con el proyecto roto no sirve).

7. **Hooks (PostToolUse) — corrección estructural:** NO usar `--check-only` por archivo. Issue #78587 (PR #110295 sin merge confirmado) hace que `--check-only` dé **falso error cuando el script referencia un autoload o `class_name` global** (la validación corre antes del registro de globales). Un RPG referencia autoloads en casi todos los `.gd` → falsos positivos masivos que entrenan a Claude a "arreglar" código correcto. El hook solo marca un **"dirty set"** (qué `.gd` cambió, parse léxico barato); la resolución de símbolos va en `/godot-verify` sobre el proyecto importado entero (un import vs N check-only). ([#78587](https://github.com/godotengine/godot/issues/78587), [PR #110295](https://github.com/godotengine/godot/pull/110295), [#89399](https://github.com/godotengine/godot/issues/89399))

8. **Commands:** `/godot-verify` corre el lazo (vivo o headless 2-fases); `/godot-mcp` detecta backend por probe + emite contrato + health-check; `/godot-add` respeta la matriz y escribe la decisión a `.summer/memory/`.

### Cómo se adapta Claude

Claude decide en este orden firme:
1. **Backend** por probe (`summer doctor --json`): Summer vivo → tools `summer_*` + verificación viva. Solo HTTP → run+read-errors. Ninguno → CLI headless 2-fases. Tratar como estado degradable, con fallback en caliente.
2. **Lenguaje**: GDScript tipado salvo trigger explícito de C#/GDExtension.
3. **Estructura**: nodos + Entity-Component + Resources de datos. ECS (GECS) solo con escala medida. Escribir el porqué en GameSoul.
4. **Datos/Save**: definiciones en Resources del PCK; save en `store_var`/JSON; **jamás `ResourceLoader.load()` sobre input del jugador**.
5. **Concurrencia**: `WorkerThreadPool` para CPU puro; física solo en `_physics_process`/`call_deferred`.
6. **Autoloads**: contar antes de añadir; refactor si pasa de ~8.
7. **Single/multi y accesibilidad**: declarar el supuesto y aplicar invariantes desde el arranque, no como extra.

**Tools/comandos:** `summer_get_scene_tree`/`summer_inspect_node` (inspección de invariantes), `summer_set_prop`/`summer_add_node` (mutación), `summer_play`+`summer_get_diagnostics`/`summer_get_script_errors` o `/godot-verify` (verificación), `summer_input_map_bind` (accesibilidad de input), `errors.json` (feedback del lazo).

**Qué verifica (ponytail "no negligente"):** compilación de todos los `.gd`; sin `ResourceLoader.load` sobre `user://`; autoloads bajo presupuesto; nada toca physics server fuera de `_physics_process`; definiciones-Resource cargan; sin dependencias circulares; **accesibilidad (Control con nombre, acciones remapeables)**; supuesto single/multi presente en GameSoul.

**Ponytail aplicado:** reusar `Node`/`Resource`/`SkeletonModifier3D`(stack IK)/`NavigationServer`/`WorkerThreadPool`/`MultiplayerSynchronizer`/AccessKit nativos antes que cualquier framework. "Lazy" = no construir ECS para 30 enemigos, no event bus si basta una señal, GDScript tipado por defecto, una sola ref en vez de tres. "No negligente" = nunca recortar save seguro, thread-safety de física, accesibilidad, ni el rollback antes de escalar.

### Acciones concretas

- Crear `references/34-arquitectura-tecnica.md` (una sola ref consolidada con secciones; reglas duras como invariantes en `validate_all.gd` citados, no duplicados).
- Editar `SKILL.md`: matriz de decisión + separación del eje de detección de backend (probe, no pregunta).
- Editar `references/30-enrutado-mcp.md`: contrato con tools reales + puerto 6550 + `summer doctor --json` + fallback en caliente + verificación viva primaria + convergence loop con rollback/oscilación.
- Editar `references/99-filosofia.md`: codificar los NUNCA del foco + IK como stack reusable.
- Reescribir `scripts/verify_loop.sh`: 2 fases con racional correcto; distinguir errores reales de ruido (no tragar exit 1 a ciegas).
- Editar `scripts/validate_all.gd`: añadir invariantes (RCE-scan, autoloads, física, **accesibilidad**, circular deps).
- Cambiar `hooks/` PostToolUse: dirty-set, no `--check-only` por archivo.
- Editar `commands/` `/godot-verify`, `/godot-mcp`, `/godot-add`.
- Editar `agents/godot-reviewer` (checklist = invariantes incl. accesibilidad y RCE) y `godot-scripter` (GDScript tipado por defecto).

### Qué añadir/cambiar en la skill (resumen de archivos)

NUEVO: `references/34-arquitectura-tecnica.md`. EDITAR: `SKILL.md`, `references/30-enrutado-mcp.md`, `references/99-filosofia.md`, `scripts/verify_loop.sh`, `scripts/validate_all.gd`, `hooks/` (PostToolUse), `commands/godot-verify`, `commands/godot-mcp`, `commands/godot-add`, `agents/godot-reviewer`, `agents/godot-scripter`.

### Pitfalls y límite lazy-not-negligent

**Pitfalls verificados (jun-2026):**
- `--check-only` por archivo → falso error con autoloads/`class_name` (#78587 ABIERTO, PR #110295 sin merge). NO usar en hook. ([#78587](https://github.com/godotengine/godot/issues/78587))
- El bug exit-1-falso de `--import --quit` está **OBSOLETO** (arreglado PR #103403, 4.5/4.4.1). NO justificar el lazo con él; en 4.6 exit 1 probablemente es fallo real → distinguir errores de ruido. ([PR #103403](https://github.com/godotengine/godot/pull/103403))
- `ResourceLoader.load_threaded_request()` → scenes incompletas. No asumir éxito. ([#108054](https://github.com/godotengine/godot/issues/108054))
- Physics server fuera de `_physics_process` → crash/UB; Jolt no lo arregla. ([godot-jolt #356](https://github.com/godot-jolt/godot-jolt/issues/356))
- GDExtension no invocable desde C# sin wrapper. Autoloads con estado de escena → leaks; circulares → deadlock.
- Convergence loop sin rollback ni detección de oscilación → corrompe el proyecto o orbita; engine vivo sin health-check/fallback → punto único de fallo silencioso.

**El límite (este foco):**
- **Lazy (correcto):** reusar nodos/Resources/IK-stack/Nav/WorkerThreadPool/Multiplayer/AccessKit nativos; no ECS hasta escala medida; no event bus si basta una señal; GDScript tipado por defecto; una ref consolidada, no tres.
- **NEGLIGENTE (prohibido):** (1) `ResourceLoader.load` sobre save del jugador → RCE; (2) `--check-only` por archivo en el hook → falsos positivos masivos; (3) tragar exit 1 a ciegas / justificar el lazo con un bug muerto; (4) acceder a física fuera de `_physics_process`; (5) convergence loop sin rollback al verde / sin detección de oscilación / escalar con el proyecto roto; (6) recortar accesibilidad (es invariante, no extra); (7) no declarar single-vs-multi → drift; (8) decisiones no persistidas en GameSoul.

### Fuentes
- [godotengine.org/releases/4.6](https://godotengine.org/releases/4.6/)
- [docs — using_jolt_physics 4.6](https://docs.godotengine.org/en/4.6/tutorials/physics/using_jolt_physics.html)
- [docs — using_multiple_threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)
- [docs — singletons_autoload](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- [godot-jolt issue #356](https://github.com/godot-jolt/godot-jolt/issues/356)
- [alternativeto.net — Godot 4.6 Jolt/LibGodot](https://alternativeto.net/news/2026/1/godot-4-6-debuts-modern-theme-jolt-physics-node-ids-and-libgodot-embed/)
- [gamedeveloper.com — Godot 4.6](https://www.gamedeveloper.com/programming/godot-4-6-is-here-with-a-fresh-look-and-a-promise-to-prioritize-workflow)
- [Inverse Kinematics returns to Godot 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)
- [StraySpark — Godot 4.6 IK guide](https://www.strayspark.studio/blog/godot-46-inverse-kinematics-procedural-animation)
- [strayspark — GDScript vs C# 2026](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language)
- [knightli.com — Standard vs .NET](https://knightli.com/en/2026/06/19/godot-standard-vs-dotnet-edition/)
- [dev.to — GDExtension Part 1](https://dev.to/gustavolr548/programming-with-gdextension-high-performance-c-in-godot-4-part-1-3c19)
- [Why isn't Godot ECS-based](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/)
- [GECS — Asset Library 3481](https://godotengine.org/asset-library/asset/3481)
- [csprance.com/blog/gecs](https://csprance.com/blog/gecs)
- [gdquest — entity-component-pattern](https://www.gdquest.com/tutorial/godot/design-patterns/entity-component-pattern/)
- [gdquest — save_game_godot4](https://www.gdquest.com/library/save_game_godot4/)
- [uhiyama-lab — save/load](https://uhiyama-lab.com/en/notes/godot/save-load-system/)
- [godot-proposals #10968 — untrusted resources](https://github.com/godotengine/godot-proposals/issues/10968)
- [Statement on GodLoader malware](https://godotengine.org/article/statement-on-godloader-malware-loader/)
- [gdquest — event-bus-singleton](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/)
- [github — SummerEngine/summer-engine-agent](https://github.com/SummerEngine/summer-engine-agent)
- [Summer engine-agent README (port 6550, 44 tools, summer doctor)](https://github.com/SummerEngine/summer-engine-agent/blob/main/README.md)
- [summerengine.com/godot-ai-mcp](https://www.summerengine.com/godot-ai-mcp)
- [github — Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)
- [github — Dokujaa/Godot-MCP](https://github.com/Dokujaa/Godot-MCP)
- [gdaimcp.com](https://gdaimcp.com/)
- [strayspark — MCP setup Claude Code 2026](https://www.strayspark.studio/blog/godot-mcp-setup-claude-code-2026)
- [PR #103403 — fix headless import errors (merged, 4.5/4.4.1)](https://github.com/godotengine/godot/pull/103403)
- [Maintenance release Godot 4.4.1](https://godotengine.org/article/maintenance-release-godot-4-4-1/)
- [Issue #103398 — headless import errors](https://github.com/godotengine/godot/issues/103398)
- [Issue #108054 — load_threaded incomplete scenes](https://github.com/godotengine/godot/issues/108054)
- [Issue #78587 — --check-only false error with autoloads](https://github.com/godotengine/godot/issues/78587)
- [PR #110295 — fix --check-only autoload errors](https://github.com/godotengine/godot/pull/110295)
- [Issue #89399 — autoload/global class errors](https://github.com/godotengine/godot/issues/89399)
