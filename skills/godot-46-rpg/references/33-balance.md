## 33. Balance (jun 2026)

Balance del RPG: economía (source/sink), combate (TTK, math), progresión (curvas de poder vs dificultad) y tuning data-driven. El sustrato es nativo (Custom Resources + `Curve`), el lazo de balance vive DENTRO de Godot headless, y las métricas son de género RPG, no de juego competitivo. Síntesis del debate: el Architect aportó el sustrato verificado; el Critic corrigió cuatro errores de ensamblaje que aquí quedan resueltos como verdad accionable.

### Estado jun-2026 (tools/motores/modelos/técnicas viables AHORA)

- Godot 4.6.3 stable vivo y 4.7 en RC. La skill se llama godot-46-rpg pero DEBE registrar y verificar la versión exacta del motor junto a cualquier resultado de balance: un balance es válido solo para la versión en que se computó (drift 4.6 -> 4.6.3 -> 4.7). https://godotengine.org/releases/4.6/
- **Sustrato data-driven (PONYTAIL puro)**: toda curva/coste/recompensa va a un Custom `Resource` con `@export` y `Curve`/`Gradient`/`Expression` nativos en `.tres`. Cero motor de tuning propio, cero formato de datos propio. La verdad de los datos son los `.tres` en `data/balance/`. https://godotlearning.com/blog/godot-resources-explained · https://medium.com/@sfmayke/resource-based-architecture-for-godot-4-25bd4b2d9018
- **Reproducibilidad — NO determinismo bit-exact (corrección crítica del Critic, verificada)**: la doc oficial de Godot dice que el algoritmo de `RandomNumberGenerator` (PCG32) es un detalle de implementación y NO debe dependerse para streams reproducibles entre versiones; además FP no es determinista cross-platform. https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html · https://github.com/godotengine/godot/issues/27856 . Implicación: el harness de balance implementa su PROPIO PRNG versionado en GDScript (xorshift/PCG sembrado explícito), NUNCA `randi()` global. El gate no es "misma seed -> mismo resultado" sino reproducibilidad estadística: intervalo de confianza 95% sobre N seeds dentro de banda. Para determinismo fuerte (no requerido por defecto) existe fixed-point: https://github.com/xpTURN/Klotho · https://godot.rapier.rs/docs/documentation/determinism/
- **Ejecutor del lazo**: `godot --headless --display-driver headless --audio-driver Dummy` corre sims/tests en CI. https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/ . Tests: gdUnit4 con su action oficial (elegir UNO, no acumular GUT+gdUnit4). https://github.com/godot-gdunit-labs/gdUnit4 · https://github.com/MikeSchulze/gdUnit4-action
- **Auto-playtest opcional**: godot-ai-playtest 0.4.0 (TCP/JSON-RPC, pre-1.0, API inestable) y godot-mcp. Riesgo de seguridad real: servidor TCP sin auth -> invariante obligatorio = bind 127.0.0.1 + token + strip del plugin en release. https://libraries.io/pypi/godot-ai-playtest · https://github.com/Coding-Solo/godot-mcp
- **Telemetría (SOLO post-launch)**: GameAnalytics SDK oficial (Asset 5162). No existe pre-launch; no puede cerrar el lazo antes de publicar. https://godotengine.org/asset-library/asset/5162
- **Auto-balanceo asistido por IA (referencia, no default)**: RuleSmith (arXiv 2602.06232, submitido 5-feb-2026; corrección de fecha del Critic) acopla self-play LLM multi-agente + opt bayesiana adaptativa; converge a 50%±5% win-rate, pero validado en CivMini (4X competitivo), NO en RPG. https://github.com/Adonis-galaxy/RuleSmith
- **Búsqueda (OPCIONAL/avanzado)**: Optuna (TPE) solo si el espacio es grande/caro. https://optuna.org/
- **Diseño de economía (referencia para el humano, NO integrable)**: Machinations.io es un editor visual SaaS propietario sin puente automatizable a la skill; lectura conceptual de source/sink, no herramienta del lazo. https://machinations.io/articles/what-is-game-economy-design
- **MCP de la skill (modelo corregido)**: Summer Engine NO es un servidor MCP externo en :6550 que orquestas; es un MCP server DENTRO del motor (~44 engine tools), paquete MIT CLI+MCP+skills+hooks. https://github.com/SummerEngine/summer-engine-agent . "Godot AI" (hi-godot) es un MCP server de producción, no solo HTTP. https://github.com/hi-godot/godot-ai . El puerto 6550 y `summer_*` siguen NO verificados: tratarlos como probe en runtime + fallback, no como capacidad de primera clase.

### Simbiosis con el flujo de la skill (pasos accionables)

Patrón núcleo — **Balance Loop, 100% in-engine (cero Python por defecto)**:
1. `data/balance/*.tres` (Resources con `Curve`/`@export`).
2. `scripts/sim_balance.gd` (harness GDScript headless): muta Resources en memoria, corre N seeds con PRNG propio versionado, emite JSON de métricas con IC95%, registra versión del motor. Guarda mejor set con `ResourceSaver`. Búsqueda interna ligera (grid/random/TPE casero); Optuna/Python solo si el espacio lo exige (mismo criterio de "coste mínimo" que se aplica a RL).
3. Métricas -> propuesta de ajuste interpretable -> reescritura de `.tres` -> re-sim hasta que las métricas entran en banda (IC95%) o se agota el presupuesto.

- **Dispatcher (SKILL.md)**: tema balance/tuning/economía/curvas/playtest/telemetría -> `references/31_balance.md`. Distinguir balance estático (curvas/Resources) de dinámico (sim).
- **Lazo (verify_loop.sh + ref 30)**: modo `--balance` extiende el lazo auto-correctivo: no termina cuando el `.gd` compila, sino cuando las métricas de balance entran en banda con IC95% o se agota el presupuesto de trials.
- **MCP routing (ref 30)**: capacidades `playtest.headless`/`state.read`/`input.inject` por PROBE en runtime + fallback. El harness DEBE funcionar solo con `--headless`; MCP (Summer in-engine / godot-ai / godot-mcp) solo lo mejora. Degradación elegante.
- **Commands**: `/godot-balance` con SOLO dos modos core en MVP: `--static` (invariantes) y `--sim` (headless). `--selfplay` (RuleSmith-style) y `--telemetry` -> avanzado/futuro. `/godot-verify --balance` como gate.
- **Hooks (PostToolUse)**: al editar `data/balance/*.tres`, validar invariantes baratos -> `errors.json`. Guardarraíl rápido antes de la sim cara.

### Cómo se adapta Claude (decisiones, tools, verificación, ponytail)

**Decisiones:**
- Modela datos, no código de motor: cada curva/coste/recompensa a un Custom `Resource`. Cero singletons de tuning propios.
- **Métricas de género RPG (corrección de género del Critic)**: el gate por defecto NO es win-rate 50%. Para RPG single-player: TTK por encuentro dentro de banda; gap controlado entre curva de poder del jugador y curva de dificultad; ratio source/sink ≈ 1.0; deltas de XP suaves (sin muros) salvo mesetas declaradas; varianza de efectividad entre clases/builds ≤ umbral (detección de builds dominantes). El 50% win-rate SOLO si hay PvP/arena.
- Escala al coste mínimo: (a) estático (invariantes) -> (b) sim determinista-estadística headless -> (c) self-play LLM solo ante asimetría real (clases/facciones) -> (d) RL solo si el usuario lo pide. Default = (a)+(b).
- Define objetivo numérico explícito ANTES de optimizar (banda TTK, ratio economía, tolerancia de curva, umbral de dominancia). Sin objetivo, no se optimiza.
- **Pre-launch sin jugadores reales (corrección B6)**: no optimizar a un punto falso; explorar el espacio y reportar sensibilidad/robustez y detección de estrategias dominantes/degenerate. Un mapa de sensibilidad es más honesto que un óptimo contra un bot tonto.
- **Accesibilidad como restricción, no guiño**: exponer multiplicadores de asistencia (daño recibido, velocidad, economía) como Resource derivado de las mismas curvas; el optimizador los respeta como restricción y valida que existe banda jugable para perfiles de baja destreza, no solo el jugador medio.

**Tools:** `/godot-balance` -> edita `data/balance/*.tres`, usa `scripts/sim_balance.gd`. Auto-playtest opcional vía godot-ai-playtest o godot-mcp/Summer si el probe los detecta. Telemetría (GameAnalytics 5162) solo para validar post-launch.

**Verifica (gates):** carga `.tres` sin error; invariantes en verde; métricas en banda con IC95% sobre N seeds (nunca escalar puntual); PRNG propio versionado sembrado; versión del motor registrada y verificada; banda de accesibilidad cumplida; (si playtest server) bind localhost+token+strip-release.

**PONYTAIL:** reusar `Curve`/`Resource`/`Expression`/PRNG propio/`ResourceSaver`/`--headless`. "Lazy" = no reinventar motor de sim ni formato de datos, escalar al coste mínimo (esto incluye NO meter Python/Optuna ni cuatro sub-modos el día uno). "No negligente" = nunca recortar PRNG versionado, IC95%, banda explícita pre-optimización, manejo de div/0 y NaN en ratios/curvas, accesibilidad derivada de las mismas curvas, seguridad del playtest server, pin de versión, registro a `errors.json`.

### Acciones concretas

1. Definir el contrato de métricas RPG (TTK, power-gap, source/sink, deltas XP, dominancia) con bandas e IC95%.
2. Implementar PRNG versionado en GDScript; prohibir `randi()` global en el harness.
3. Escribir `sim_balance.gd` (headless, N seeds, JSON con IC95%, versión del motor).
4. Convención `data/balance/` con `.tres` nativos.
5. Hook + `validate_all.gd`: invariantes baratos (no-negativos donde toca, loot suma 1.0, source/sink declarados, monotonicidad SOLO donde el Resource la declara por metadato).
6. `verify_loop.sh --balance` con criterio de parada por banda+IC95%.
7. Probe MCP en runtime + fallback a headless puro.

### Qué añadir/cambiar en la skill

- Crear `references/31_balance.md` (este documento).
- Crear `scripts/sim_balance.gd` (harness GDScript, cero Python).
- Crear `data/balance/` (enemy_stats, xp_curve, economy, loot_tables `.tres`).
- Crear `commands/godot-balance.md` (MVP: `--static`, `--sim`; avanzado: `--selfplay`, `--telemetry`).
- SKILL.md: ruta dispatcher -> 31; Balance Loop en workflow.
- `scripts/verify_loop.sh`: modo `--balance`.
- `scripts/validate_all.gd` + `hooks/PostToolUse`: invariantes de `data/balance/*.tres`.
- `references/30` (MCP routing): capacidades por probe+fallback; corregir modelo Summer (MCP in-engine) y godot-ai (MCP).
- `commands/godot-verify.md`: flag `--balance`.
- `agents/godot-reviewer`: checklist de balance (objetivo, PRNG versionado, IC95%, invariantes, accesibilidad, pin de versión, seguridad playtest).

### Pitfalls y límite lazy-not-negligent

- **Determinismo falso**: no prometer bit-exact; Godot no lo da. Usar PRNG propio + reproducibilidad estadística (IC95%). Reportar banda, nunca escalar.
- **Win-rate 50% en género equivocado**: es métrica de competitivo asimétrico (RuleSmith/CivMini), no de RPG single-player. Usar métricas de género.
- **Over-engineering (anti-PONYTAIL)**: Python/Optuna + cuatro sub-modos como default viola "coste mínimo". Core = invariantes + harness GDScript. Optuna/self-play/telemetría = opcional.
- **Modelo Summer mal dibujado**: MCP in-engine, no servidor externo en :6550 que orquestas. Probe+fallback, no capacidad de primera clase.
- **Seguridad del playtest server**: TCP sin auth en 9876 es agujero -> bind localhost+token+strip-release.
- **Drift de versión**: 4.6.3 vivo + 4.7 RC; registrar y verificar versión exacta junto al resultado.
- **Monotonicidad global como invariante**: bloquea diseño legítimo (dientes de sierra, soft-caps, mesetas); validar solo donde el Resource lo declara.
- **Overfit al bot pre-launch**: sin jugadores reales, explorar sensibilidad y detectar estrategias dominantes en vez de afinar a un óptimo falso; validar con telemetría post-launch.
- **Machinations no integrable**: referencia conceptual para el humano, no herramienta del lazo automático.

Límite lazy-not-negligent: es "lazy" reusar primitivas nativas y escalar al coste mínimo; es negligente recortar PRNG versionado, IC95%, banda explícita, manejo numérico, accesibilidad, seguridad del playtest server, pin de versión o el registro de errores. Un balance "que parece bien" sin objetivo numérico, sin reproducibilidad estadística y sin invariantes es negligente aunque compile.

### Fuentes (URLs reales)

- https://godotengine.org/releases/4.6/
- https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html
- https://github.com/godotengine/godot/issues/27856
- https://github.com/xpTURN/Klotho
- https://godot.rapier.rs/docs/documentation/determinism/
- https://godotlearning.com/blog/godot-resources-explained
- https://medium.com/@sfmayke/resource-based-architecture-for-godot-4-25bd4b2d9018
- https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
- https://github.com/godot-gdunit-labs/gdUnit4
- https://github.com/MikeSchulze/gdUnit4-action
- https://libraries.io/pypi/godot-ai-playtest
- https://github.com/Coding-Solo/godot-mcp
- https://github.com/SummerEngine/summer-engine-agent
- https://github.com/hi-godot/godot-ai
- https://godotengine.org/asset-library/asset/5162
- https://github.com/Adonis-galaxy/RuleSmith
- https://arxiv.org/abs/2602.06232
- https://optuna.org/
- https://machinations.io/articles/what-is-game-economy-design
