## 31. Diseño de mecánicas (jun 2026)

Referencia del plugin `godot-46-rpg` (repo `DasikuHp/Skillsclaude`, verificado existente: usa `.mcp.json` con Godot AI, y contiene `hooks/`, `commands/`, `agents/`, `output-styles/` y `skills/godot-46-rpg/{SKILL.md,references/,scripts/,assets/}`). Foco: cómo Claude diseña, simula, implementa y verifica mecánicas de RPG 3D bajo filosofía PONYTAIL ("piensa como el senior más perezoso: el mejor código es el que nunca escribiste"; *lazy* en arquitectura, NUNCA negligente en el contrato de comportamiento).

> Esta referencia consolida un debate MAD. Conserva el grounding correcto del Architect (motor 4.6, Resource=ScriptableObject, supervisión humana, edge-case set de StraySpark) e incorpora las correcciones verificadas del Critic (no hardcodear conteos MCP, puertos reales, balanceo nativo en vez de SaaS, gate por invariantes en vez de KPI tautológico, accesibilidad ejecutable, licencias). Lo que viola PONYTAIL o no se verificó en jun-2026 se descarta explícitamente.

### Estado jun-2026 (qué es viable AHORA)

**Motor base — Godot 4.6 (enero 2026).** [VERIFICADO https://godotengine.org/releases/4.6/]
- **Jolt Physics es first-party y motor 3D por defecto SOLO en proyectos nuevos.** Los proyectos existentes conservan su `physics_engine`. Regla operativa: NO escribas `physics/3d/physics_engine = JoltPhysics3D` si el proyecto nuevo ya lo trae por default (configurar lo que ya es default es anti-PONYTAIL). En proyectos migrados, NO cambies a Jolt silenciosamente: avisa, porque cambia el comportamiento de colisiones.
- **IK modular bajo `IKModifier3D` (subclase de `SkeletonModifier3D`):** familia completa `TwoBoneIK3D`, `FABRIK3D`, `CCDIK3D`, `SplineIK3D`, `JacobianIK3D` + constraints de twist/velocidad angular. Útil para combate cuerpo a cuerpo, foot-IK y apuntado. Advertencia de producción: existe issue abierto `#112964` ("End Bone Ignores Target Rotation") — IK 4.6 tiene bugs conocidos; trátalo como prototipable, no como "listo para shippear sin verificar". [https://github.com/godotengine/godot/issues/112964]
- **LibGodot:** embeber el engine como librería; vía soportada para control headless del lazo de verificación.

**Backends MCP de engine vivo (lo que distingue al foco).**
- **Summer Engine** — motor de escritorio sobre Godot 4; abre proyectos `.godot`, produce escenas y GDScript que posees, y puede "darle al play" y observar el juego corriendo. Bridge en **localhost:6550**, MCP por **stdio** (lo arranca el agente al cargar la config). CLI `summer`: `setup, doctor, install, login, run, create, plan, memory, cloud sync, skills, mcp server`. Skills = guías markdown; `brainstorm-game` escribe `.summer/GameSoul.md`, leído por las demás. [https://www.summerengine.com/mcp · https://docs.summerengine.com/mcp/cli-reference · https://github.com/SummerEngine/summer-engine-agent]
  - **CORRECCIÓN VERIFICADA (no hardcodear conteos):** Summer publica DOS cifras contradictorias — "44 tools que hablan con el engine local en localhost:6550" y "expone 51 tools... arranca por stdio". Probablemente 44 de control de engine + extras de meta/generación = 51, o versiones distintas de doc. La regla es: **NUNCA fijar un número en la skill; enumerar `tools/list` en el handshake MCP en runtime.** El `:6550` SÍ existe (verificado), no es "no confirmado".
- **Godot AI** (`hi-godot/godot-ai`) — conecta clientes MCP a un editor Godot vivo vía plugin. **Python FastMCP en `http://127.0.0.1:8000/mcp` + WebSocket en `:9500`** (el plugin arranca o reusa el server Python y conecta por WS). ~41 tools / 120+ operaciones (escenas, nodos, scripts, señales, UI, materiales, animación, partículas). Instalable desde AssetLib (asset/5050). Ships telemetría anónima. [https://github.com/hi-godot/godot-ai · https://godotengine.org/asset-library/asset/5050 · https://pypi.org/project/godot-ai/2.7.4/]
  - **CORRECCIÓN VERIFICADA:** Godot AI NO es "HTTP genérico". Son dos puertos y dos protocolos (HTTP/MCP `:8000` + WS `:9500`). La detección debe sondear el editor vivo, y la skill debe contemplar **colisión de puertos** si el usuario corre Summer (`:6550`) y Godot AI (`:8000`/`:9500`) a la vez.
- **File-level** (`Coding-Solo/godot-mcp` y otros): launch editor, run project, capturar debug. NO observa runtime profundo. Es el caso de **degradación elegante** a headless.

**IA en diseño de mecánicas — límite verificado.** RPGAgent (CHI 2026), surveys arXiv y UNBOUNDED confirman: los LLM son *multiplicadores de productividad* que prototipan/refactorizan/generan, pero **no diseñan sistemas de juego completos de forma autónoma; la supervisión humana es central.** [https://dl.acm.org/doi/10.1145/3772318.3790326 · https://arxiv.org/html/2410.15644v1] Esto fija el principio rector: **Claude propone e itera; humano y verificación deciden.**

**Plantillas reusables (PONYTAIL).** `gdquest-demos/godot-open-rpg` (combate por turnos+inventario+progresión), StraySpark inventory&crafting (Resources+signals+drag&drop+save/load + edge cases: peso, stacking, slots de equipo, recetas), Wyvernshield (asset/1620), Top-down Action RPG (asset/487). [https://github.com/gdquest-demos/godot-open-rpg · https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide]
- **CORRECCIÓN VERIFICADA (Critic):** antes de envolver una plantilla, **verifica licencia SPDX y versión `compatible` 4.6 en el Asset Library.** Reusar a ciegas puede meter código no-comercial/GPL o un addon que no compila bajo Jolt+IK nuevos. Lazy sin chequear licencia/versión es negligente.

### Simbiosis con el flujo de la skill (pasos accionables)

El foco inyecta una **fase DESIGN previa al código** y un **gate de verificación por invariantes**. Pipeline que orquesta `/godot-flow`:

1. **DESIGN** — Ante "haz un sistema de loot/combate/XP", Claude NO escribe GDScript primero. Produce un modelo declarativo: verbos núcleo → recursos → loops → feedback, plus parámetros candidatos en `design/mechanics/<sistema>.json`. Si el backend es Summer, reusa `.summer/GameSoul.md` como scope; si no, `design/GameSoul.md` propio.
2. **SIMULATE (NATIVO, no SaaS)** — Corre **Monte Carlo en Godot headless** (`scripts/balance_sim.gd` ejecutando miles de combates/drops sobre los `.tres` reales). Salida: KPIs medidos del runtime real (tiempo medio de combate, distribución de drops, curva de XP). Cero dependencias, cero credenciales, cero red. *Machinations es OPCIONAL aquí: solo si un humano quiere explorar una economía visualmente.*
3. **HANDOFF** — Parámetros → Godot Resources `.tres` (el ScriptableObject de Godot). Loot table, stat block, recipe = `Resource`.
4. **PROTOTYPE (MCP)** — Detecta backend por `tools/list`; si hay engine vivo (Summer/Godot AI), instancia escenas, adjunta scripts que *leen el `.tres`* y dale al play (con **gate humano antes de `run`**). Si file-only, prepara para headless.
5. **VERIFY** — `verify_loop.sh`: compila/parsea `.gd`, instancia escena, corre el **gate de invariantes property-based** y compara los KPIs del runtime contra los de la simulación nativa. Divergencias → `errors.json`; Claude ajusta el `.tres` (no el código) y reitera.

**Dispatcher (SKILL.md):** "diseñar mecánica / loop / economía / balanceo / drop rate / curva XP / coste crafting" → `references/31-mechanics-design.md`. Registrar DESIGN como obligatoria antes de PROTOTYPE.

**Commands:** `/godot-flow` orquesta las 5 fases con gate; `/godot-verify --converge`; `/godot-mcp` detecta+enruta por `tools/list`.

**Hooks:** PostToolUse extendido — cambios en `design/balanced/*.tres` disparan re-simulación; check de accesibilidad ejecutable.

### Cómo se adapta Claude (decisiones, tools, verificación, ponytail)

**Decide (firme):**
- **Diseña antes de codear.** Modelo declarativo → simulación nativa → KPIs → recién entonces código.
- **Elige backend por CAPACIDAD leída en `tools/list`, no por marca ni por conteo.** ¿Hay tool tipo `run`/`play`/`get_runtime_errors`? → engine vivo. ¿Solo file ops? → headless. Esto sobrevive a versiones, conteos contradictorios y nuevos backends.
- **Resource nativo sobre clase propia** siempre que el patrón lo permita.
- **No fuerza Jolt** si ya es default; gate de migración con aviso en proyectos viejos.

**Verifica (en orden):** 1) compila/parsea; 2) escena instancia sin error; 3) **invariantes property-based** (el gate honesto): daño clamped, no XP negativa, stacking ≤ max, save→load idempotente, loader robusto ante `.tres` corrupto — reusa el edge-case set de StraySpark como suite; 4) KPIs runtime vs simulación nativa; 5) accesibilidad (gate ejecutable: no color como único canal, `InputMap` action en vez de teclas hardcodeadas, theme scaling en vez de px fijos).

**PONYTAIL aplicado:** *Lazy* = reusar Open-RPG/StraySpark/Wyvernshield, Resources, simulación headless, nodos nativos (GridMap/TileMap/AStarGrid2D) para dungeons. *No negligente* = el contrato de comportamiento (validación, errores, save/load, accesibilidad, convergencia verificada) es innegociable aunque sea "solo un prototipo".

### Acciones concretas
- `scripts/balance_sim.gd`: Monte Carlo headless nativo sobre `.tres` reales.
- `scripts/verify_loop.sh`: gate de invariantes + comparación KPI; anexa a `errors.json`.
- Hook de accesibilidad ejecutable; hook de re-simulación en cambios de `.tres`.
- `/godot-flow` como orquestador de 5 fases con gate humano antes de `run`/play.
- Detección MCP por `tools/list`; documentar puertos `:6550` (Summer stdio), `:8000`/`:9500` (Godot AI) + colisión.
- Verificación de licencia SPDX + versión 4.6 antes de envolver cualquier plantilla.

### Qué añadir/cambiar en la skill
- **Crear** `references/31-mechanics-design.md` (esta).
- **SKILL.md:** dispatcher + DESIGN obligatoria.
- **`references/30` (MCP/lazo):** detección por handshake, NO hardcodear 44/51, puertos reales, colisión de puertos.
- **`references/29` (Summer):** CLI real, `.summer/GameSoul.md`, perfil de datos saliente.
- **`references/28` (premium):** Machinations OPCIONAL fuera del camino crítico (Community: 1 seat/1000 runs/mes, restricción <100k USD + whitelisting manual).
- **`agents/godot-reviewer`:** checklist PONYTAIL del foco.
- NO imponer MAD/SAnR ni reimplementar Phantom Grammar (over-engineering anti-PONYTAIL; usa nodos nativos). Renombrar cualquier métrica PCG para no colisionar con la sigla MAD del debate.

### Pitfalls y límite lazy-not-negligent
1. **Confiar el diseño completo al LLM** — verificado que no diseñan sistemas completos solos. DESIGN propone, humano/verificación deciden.
2. **Números inventados** — sin simulación, NO presentes drop rates "a ojo" como balanceados. Marca "simulación pendiente".
3. **Oráculo tautológico (DESCARTADO del Architect):** el "AI-Balancer de Machinations como gate de convergencia" compara el juego contra un Target que el propio diseñador eligió en un grafo desacoplado del runtime — es un test que se valida a sí mismo. **El gate honesto son invariantes property-based + KPIs medidos del runtime real (simulación nativa).**
4. **SaaS de pago en el camino crítico (DESCARTADO):** Machinations es un tercero comercial con whitelisting manual y muro de pago — lo opuesto a lazy. Demótalo a herramienta opcional de exploración humana.
5. **Hardcodear conteos/protocolos MCP** — enumera `tools/list`; documenta puertos pero deriva capacidad dinámicamente.
6. **Asumir engine vivo con backend file-only** — degrada a headless, no finjas que viste el juego correr.
7. **Romper física por migración 4.6** — no fuerces Jolt en proyectos viejos.
8. **Seguridad/privacidad omitida:** un MCP de engine vivo ejecuta código generado por LLM en la máquina del usuario → **gate humano obligatorio antes de `run`/play.** Declara telemetría (Godot AI), login/cloud (Summer) y whitelisting (Machinations) en la sección de seguridad. "No negligente" sin esto es eslogan vacío.
9. **Accesibilidad como eslogan** — conviértela en gate ejecutable o no cuenta.
10. **Reusar plantilla sin verificar licencia/versión 4.6.**

**Regla de corte:** sé *lazy* en la arquitectura (reusar Resources, plantillas, simulación nativa, nodos PCG existentes); NUNCA seas lazy en el contrato de comportamiento (validación de rangos, manejo de errores al cargar/serializar `.tres`, save/load correcto, accesibilidad ejecutable, gate humano antes de ejecutar código generado, convergencia verificada por invariantes). Un prototipo que crashea al cargar un Resource corrupto, oculta divergencias, codifica daño sin clamping, o ejecuta código LLM sin gate, es **negligente, no lazy.**

### Fuentes (URLs reales)
- https://godotengine.org/releases/4.6/
- https://github.com/godotengine/godot/issues/112964
- https://www.summerengine.com/mcp · https://docs.summerengine.com/mcp/cli-reference · https://github.com/SummerEngine/summer-engine-agent · https://www.summerengine.com/blog/best-godot-mcp-server
- https://github.com/hi-godot/godot-ai · https://godotengine.org/asset-library/asset/5050 · https://pypi.org/project/godot-ai/2.7.4/ · https://github.com/Coding-Solo/godot-mcp
- https://machinations.io/pricing · https://machinations.io/docs/external-json
- https://dl.acm.org/doi/10.1145/3772318.3790326 · https://arxiv.org/html/2410.15644v1
- https://github.com/gdquest-demos/godot-open-rpg · https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide · https://godotengine.org/asset-library/asset/1620 · https://godotengine.org/asset-library/asset/487
- https://github.com/DietrichGebert/ponytail/blob/main/skills/ponytail/SKILL.md
