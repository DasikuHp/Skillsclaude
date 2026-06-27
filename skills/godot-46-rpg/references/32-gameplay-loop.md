## 32. Gameplay loop (jun 2026)

El gameplay loop es el **invariante de aceptacion** de un RPG: el conjunto minimo de verbos que el jugador repite y que da sentido a todo lo demas. Filosofia del foco: un loop no esta "hecho" porque el `.gd` compile, sino cuando su **condicion de cierre esta verificada de forma determinista**. La leccion del debate Architect/Critic: el medio determinista de verdad es el **test headless (GUT)**, no "jugar contra un MCP"; jugar es enriquecimiento valioso pero opcional.

### Estado jun-2026 (tools/motores/modelos/tecnicas viables AHORA)

**Motor base — Godot 4.6 (final, ene 2026).** Verificado en docs/release:
- **Jolt es el motor 3D por defecto en proyectos NUEVOS** (matiz importante: los proyectos existentes conservan su config; no migra solo). El core del loop (mover/golpear/colisiones/triggers de zona) se construye sobre Jolt + `CharacterBody3D` + `Area3D`, sin addons (PONYTAIL).
- **IKModifier3D** sobre el `SkeletonModifier3D` revisado, con solvers **TwoBoneIK3D, SplineIK3D, FABRIK3D, CCDIK3D, JacobianIK3D**; nuevas constraints de twist/velocidad angular y la posibilidad de fijar el target a nodos 3D (p.ej. brazo que se ancla a un arma). Util para feedback procedural del verbo de combate, PERO no sustituye animacion base: sigue requiriendo animacion + tuning; no venderlo como "ahorro de pipeline".
- LibGodot (embeber el engine) habilita arneses de test mas integrados.
- Fuente: https://godotengine.org/releases/4.6/ · https://blog.desdelinux.net/en/Godot-4.6-release-Jolt-Physics-IK-modern-theme/ · https://gamefromscratch.com/godot-4-6-released/ · https://80.lv/articles/godot-4-6-is-out
- ANTES de generar codigo que dependa de firmas exactas de IKModifier3D/SSR, confirmar en docs.godotengine.org.

**Verificacion determinista (RED DE SEGURIDAD = INVARIANTE DURO).**
- **GUT 9.6**: `godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit` (exit 0 = pasa, 1 = falla; `.gutconfig.json` para defaults). Sin editor vivo, sin timeout ajeno, CI-able, sin dependencia de MCP de tercero. GdUnit4 es alternativa equivalente. Fuente: https://gut.readthedocs.io/en/latest/Command-Line.html · https://github.com/bitwes/Gut · https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
- Esta es la capa que decide "aceptado/no aceptado". Aqui vive la **matematica del loop** (curvas de XP, drop rates, daño, condiciones de cierre de zona).

**Playtest "jugando" (ENRIQUECIMIENTO OPCIONAL, no invariante).**
- **satelliteoflove/godot-mcp** (npm `@satelliteoflove/godot-mcp`): freeze-clock + step N slices + **entity-state como JSON** (posiciones, velocidades, animacion, datos custom). Permite aseverar "tras 3 ticks de input X, loot_count subio" sin gastar tokens de vision en screenshot. Arquitectura cliente MCP ⇄ stdio ⇄ Node ⇄ WebSocket ⇄ addon bridge ⇄ debugger del juego. **Importante (verificado jun-2026): el issue #276 (timeout global de 30s que recortaba en silencio los step largos) esta CERRADO, resuelto por PR #278 con timeouts per-request.** Aun asi, por prudencia y bus-factor, mantener acotada la duracion in-game de cada step. Fuente: https://github.com/satelliteoflove/godot-mcp · https://github.com/satelliteoflove/godot-mcp/issues/276 · https://www.npmjs.com/package/@satelliteoflove/godot-mcp
- **Erodenn/godot-mcp-runtime** ("Playwright MCP for Godot"): run/screenshot/simulate-input/read-scene-tree, secuencias de input batched, background/off-screen mode. Fallback cuando no hay freeze-clock; su verificacion es "blanda" (race posible observacion↔juego). Fuente: https://github.com/Erodenn/godot-mcp-runtime
- **godot-ai-playtest** (PyPI): control TCP externo (send/hold input, click, screenshot). Arnes CI alternativo sin editor vivo. Fuente: https://libraries.io/pypi/godot-ai-playtest

**Summer Engine — capa de agente.** `SummerEngine/summer-engine-agent` es **MIT, open source** (la capa de agente: CLI + MCP server + skills + hooks). MCP en **localhost:6550**, ~44 tools en la version actual (DETECTAR EN RUNTIME; el conteo cambia entre versiones). `summer:brainstorm-game` escribe `.summer/GameSoul.md`, fuente del meta-loop/vision. Advertencia "no negligente": la capa de agente es MIT, pero el **engine subyacente puede tener fuente mas restringida** que Godot vanilla; los proyectos siguen siendo `.godot` estandar (sin lock-in de archivos), pero documentarlo al usuario. Fuente: https://github.com/SummerEngine/summer-engine-agent · https://github.com/SummerEngine/summer-engine-agent/blob/main/README.md · https://www.summerengine.com/godot-ai-mcp

**Teoria de loops viable (para guiar el diseño).** Jerarquia en RPG: *core* (segundos: golpear/esquivar/mover) → *meta* (minutos: entrar zona→combatir→loot→salir) → *macro* (horas: nivel→habilidad→backtracking). Core corto para momentum; el meta da sentido. Onboarding: meter al jugador al core en poco tiempo, tutorial emergente. Reward schedule intermitente (refuerzo variable) clave de retencion. Pitfall canonico: loop estancado (sin variacion / recompensa sin significado matematico / reto que no escala con la skill). Fuente: https://www.gameanalytics.com/blog/how-to-perfect-your-games-core-loop · https://gamedesignskills.com/game-design/core-loops-in-gameplay/ · https://developers.meta.com/horizon-worlds/learn/videos/core-loop-design-for-retention/

### Simbiosis con el flujo de la skill

**Dispatcher (SKILL.md).** Mapear "loop / gameplay loop / pacing / retencion / core-meta loop" → la seccion de gameplay loop (en un reference existente; ver mas abajo) + obligar lectura de principios (00) + enrutado MCP (30). El loop es transversal: cualquier `/godot-add <verbo>` pasa por el.

**Lazo de verificacion — 2 estratos duros + 1 opcional (corregido tras el debate):**
1. **Estrato 1 estatico** (ya existe): parse `.gd`, `--check-only`, validate_all.gd.
2. **Estrato 2 headless — INVARIANTE DURO** (ya existe, se refuerza): GUT/GdUnit4 sobre la matematica del loop. **La condicion de cierre de cada nivel del loop se escribe como un test GUT**, no como subsistema nuevo. Aqui se decide "aceptado". Para RNG, ver abajo (property-based).
3. **Estrato 3 playtest — ENRIQUECIMIENTO OPCIONAL Y BLANDO**: si hay un MCP de playtest disponible con freeze-clock + entity-state JSON (deteccion BINARIA si/no), cargar escena del loop, freeze, inyectar input del verbo, step N, leer entity-state JSON, aseverar la transicion. Screenshot solo si la asercion estructural no basta (ahorro de tokens). Si el backend no soporta freeze-clock/entity-state, **degradar a screenshot+input batched y declararlo "verificacion blanda" en el reporte** (no negligente). Si no hay MCP, el estrato 2 ya es suficiente para aceptar.

El **lazo auto-correctivo de convergencia (ref 30)** se reusa tal cual cuando una asercion falla: diagnostico → correccion → re-run.

**Enrutado MCP (ref 30) — deteccion perezosa, no router especulativo.** PONYTAIL: no construir una matriz de 8 flags x 4 backends antes de que exista un usuario con dos backends a la vez (YAGNI). Deteccion binaria: "hay MCP de playtest con freeze-clock+entity-state-json? si/no". Si si, ofrecer estrato 3. Si no, GUT. Summer (:6550) aporta build/diagnostics/scene-mutation/asset-gen y GameSoul; satelliteoflove aporta freeze-clock+step+entity-state; runtime/TCP son fallbacks de input/vision.

**Commands.** Extender `/godot-verify` con `--loop <nombre>` (corre estratos 1-2 siempre, 3 si hay backend). **NO** crear `/godot-loop` ni `loop_status.json` ni hook de estado: el estado del verbo vive en git via "el test GUT de su condicion de cierre pasa o no". Una fuente de verdad (los tests), no un JSON paralelo que un hook tiene que mantener sincronizado.

**Flujos premium.** `/godot-flow` y `/godot-summer` invocan `summer:brainstorm-game`/leen `.summer/GameSoul.md` como fuente del meta-loop antes de generar el core.

### Como se adapta Claude

**Decide:**
1. **Primero el verbo, no el sistema.** Ante "haz el gameplay loop", construir UN verbo nuclear (p.ej. "atacar") end-to-end hasta que cierra y se puede jugar. No combate+inventario+progresion de golpe. Lectura PONYTAIL del incrementalismo.
2. **Jerarquia explicita + condicion de cierre como TEST.** Declarar core/meta/macro y escribir la condicion de cierre de cada nivel **como un test GUT** ANTES de codificar (TDD aplicado al diseño de loop). Sin test de cierre, no empieza.
3. **Reusar nativo (PONYTAIL):** `CharacterBody3D`, `Area3D`, `AnimationTree`+`IKModifier3D`, `Timer`, señales, `Resource` custom para loot/curvas — antes de cualquier "LoopManager". Solo crear arquitectura propia cuando dos verbos comparten estado que ningun nodo nativo modela bien.

**Tools/orden:** `summer:brainstorm-game`→GameSoul → escribir test de condicion de cierre (GUT) → `/godot-add <verbo>` reusando nativo → hook valida sintaxis → `/godot-verify --loop <verbo>` (estrato 2 siempre; estrato 3 si hay MCP) → si falla, lazo auto-correctivo (ref 30) → verbo verde → siguiente verbo; cada 2-3 verbos, test de integracion del meta-loop completo.

**Verifica (aserciones, no vibes):**
- Core: tras input del verbo, el estado cambia como se predijo (hp/posicion/flag) — test GUT.
- Meta: la secuencia entrar→combatir→loot→salir deja la zona `cleared` y otorga la recompensa esperada — test de integracion.
- RNG (loot/crits/daño variable): NO fijar una sola seed y verificar un camino (eso verifica un camino, no el loop). Usar **property-based**: aseverar invariantes sobre la distribucion (drop_rate ∈ [min,max] sobre N tiradas, monotonia de la curva de XP, que toda recompensa cae dentro del ciclo). Esto SI verifica el reward schedule intermitente real y detecta "recompensa sin significado matematico". Complementar con seed fija para tests de un camino concreto.
- Pacing: medir via step-count que el core cabe en su ventana objetivo y que la recompensa llega dentro del ciclo.
- Onboarding: aseverar que desde boot existe un verbo jugable sin pantallas intermedias (boot→primer input efectivo). HONESTIDAD: esto verifica que hay verbo temprano, NO que el onboarding "dure <60s" para un humano (el step de game-time no mide segundos de reloj de pared). No prometer lo que el test no mide.
- Accesibilidad TESTEABLE: aseverar que todo evento de recompensa emite una señal no-visual (audio/haptic/texto) ademas del VFX. Accesibilidad como asercion, no de boquilla.

**PONYTAIL aplicado:**
- *Lazy*: reusar nodos/Resources/señales/Timer; entity-state JSON antes que screenshots; verificar el verbo minimo, no el juego entero, en cada paso; deteccion binaria de MCP en vez de router especulativo.
- *No negligente*: nunca declarar un loop hecho sin su test de condicion de cierre en verde; nunca recortar la estrategia RNG (seed o property-based); declarar cuando una verificacion es "blanda" por backend limitado; aseverar el canal no-visual del feedback de recompensa; advertir al usuario que el engine de Summer puede tener fuente mas restringida que Godot vanilla.

### Acciones concretas
- Anadir al dispatcher el tema gameplay loop → seccion de loop + lectura obligada de 00 y 30.
- Reforzar `verify_loop.sh`: estrato 2 (GUT) como gate de aceptacion; estrato 3 opcional y declarado blando.
- Escribir las condiciones de cierre como tests GUT, no como JSON/subsistema.
- Property-based tests para todo lo RNG.
- Asercion de accesibilidad (señal no-visual de recompensa) en validate_all.gd.
- Documentar la naturaleza MIT del agente Summer y la posible restriccion de fuente del engine.

### Que añadir/cambiar en la skill
- EDIT `references/30-mcp-routing.md`: deteccion binaria de capacidad de playtest; estrato 3 como opcional/blando; nota issue #276 cerrado por PR #278; lazo auto-correctivo reusado.
- EDIT un reference existente para añadir la SECCION "gameplay loop" (jerarquia, loop-spec, antipatrones-como-aserciones, onboarding checklist). Crear `references/31-gameplay-loop.md` SOLO si el host crece demasiado — preferir reusar (PONYTAIL).
- EDIT `scripts/verify_loop.sh` y `scripts/validate_all.gd` (gate GUT + asercion de accesibilidad + escena-loop tiene test).
- EDIT `commands/godot-verify.md` (flag `--loop`). NO crear `/godot-loop` ni `loop_status.json` ni hook de estado.
- EDIT `agents/godot-reviewer.md` y `agents/godot-scripter.md` (checklist de loop; un verbo a la vez; test antes que implementacion).
- EDIT `SKILL.md` (dispatcher + lazo GUT-invariante / playtest-opcional + advertencia fuente Summer).

### Pitfalls y limite lazy-not-negligent
**Tecnicos:**
- Screenshot-driven verification: caro y no determinista → entity-state JSON primero, screenshot ultimo recurso.
- Race observacion↔juego: solo freeze-clock+step lo elimina; con run+screenshot la verificacion es BLANDA, declararlo.
- Bus-factor: NO anclar el criterio de aceptacion de toda la skill a un MCP de un solo mantenedor. Por eso GUT (no MCP) es el invariante duro. El estrato 3 es enriquecimiento.
- RNG: ver property-based arriba; sin estrategia explicita las aserciones de loot son flaky.
- Loops async/multi-frame (`await`, tween, fisica que tarda en asentar): `step N` asume tick sincrono; con señales diferidas la condicion de cierre puede no haberse cumplido al medir → step hasta condicion, no N fijo, y await en el test.
- Loops con red/multiplayer: freeze-clock no aplica con peer remoto → fuera de alcance del estrato 3, verificar logica en estrato 2.
- Loops por audio/ritmo: el step de game-time desincroniza el bus de audio; entity-state JSON no captura fase de audio → declarar fuera de alcance del playtest determinista.
- Save/load mid-loop: aseverar que la condicion de cierre sobrevive a serializar/deserializar (bug RPG clasico).
- Conteos de tools (44 Summer, 149 otros MCP): DETECTAR EN RUNTIME, no hardcodear; cambian entre versiones.
- Firmas Godot 4.6 (IKModifier3D/SSR): confirmar en docs.godotengine.org antes de generar codigo.

**Limite (regla dura del foco):**
- *Lazy permitido*: reusar nativo; no construir LoopManager ni subsistema de estado de verificacion; JSON antes que vision; verbo minimo por paso; deteccion binaria de backend.
- *Negligente PROHIBIDO*: declarar un loop hecho sin test de cierre en verde; recortar la estrategia RNG; ocultar que la verificacion fue blanda; ignorar la accesibilidad del feedback (debe tener asercion); avanzar al siguiente verbo con tests rojos; anclar la aceptacion a un MCP de tercero en vez de a GUT headless.

### Fuentes
- https://godotengine.org/releases/4.6/
- https://blog.desdelinux.net/en/Godot-4.6-release-Jolt-Physics-IK-modern-theme/
- https://gamefromscratch.com/godot-4-6-released/
- https://80.lv/articles/godot-4-6-is-out
- https://github.com/satelliteoflove/godot-mcp
- https://github.com/satelliteoflove/godot-mcp/issues/276
- https://www.npmjs.com/package/@satelliteoflove/godot-mcp
- https://github.com/Erodenn/godot-mcp-runtime
- https://libraries.io/pypi/godot-ai-playtest
- https://github.com/SummerEngine/summer-engine-agent
- https://github.com/SummerEngine/summer-engine-agent/blob/main/README.md
- https://www.summerengine.com/godot-ai-mcp
- https://gut.readthedocs.io/en/latest/Command-Line.html
- https://github.com/bitwes/Gut
- https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
- https://www.gameanalytics.com/blog/how-to-perfect-your-games-core-loop
- https://gamedesignskills.com/game-design/core-loops-in-gameplay/
- https://developers.meta.com/horizon-worlds/learn/videos/core-loop-design-for-retention/
