## 37. Narrativa (jun 2026)

Verdad accionable consolidada para el foco narrativo del skill `godot-46-rpg` (recomendado renombrar; ver §Estado). Alcance: dialogo y quests ramificados, sistemas Dialogic 2 / Ink / Yarn Spinner / Dialogue Manager, NPCs con LLM en runtime, worldbuilding y localizacion. Filosofia PONYTAIL: reusar nodos/Resources/addons maduros antes que arquitectura propia; "lazy, no negligente" = nunca recortar validacion, errores, seguridad ni accesibilidad.

### Estado jun-2026 (tools/motores/modelos/tecnicas viables AHORA)

**Premisa de version corregida (bloqueante).** **Godot 4.7 es stable desde el 18-19 jun-2026** (HDR output, AreaLight3D, 2D Scene Paint, export templates por plataforma, Steam Frame / Android XR production-ready; >1.265 fixes desde 4.6). Lo mas importante para narrativa: **el nuevo Asset Store (`store.godotengine.org`) reemplaza la Asset Library legacy** (`godotengine.org/asset-library/asset/NNN` queda en deprecacion, nueva API con threading y seleccion de version). Decision firme: **el skill NO debe anclarse a 4.6 en su propio nombre.** Renombrar a `godot-rpg` / `godot-4x-rpg` y que el dispatcher **detecte la version del engine en runtime (`--version`)** y soporte 4.6 y 4.7. Esto es ademas mas PONYTAIL: no hardcodear lo que el engine ya reporta. `add_context.sh` debe resolver addons contra el nuevo Asset Store.

**Backends de dialogo — matriz REDUCIDA (correccion anti-over-engineering).** Codificar cuatro backends en dispatcher + hooks + reviewer viola PONYTAIL: cada uno tiene su parser, su modelo de estado y su formato de grafo, y el lazo de verificacion tendria que reimplementarse cuatro veces. Decision: **DOS backends core, dos escape hatches.**

- **DEFAULT: Dialogue Manager 4 (Nathan Hoad)** — `github.com/nathanhoad/godot_dialogue_manager`, docs `dialogue.nathanhoad.net`. Confirmado: addon para Godot 4.6+, runtime **stateless** (tu juego es la autoridad del estado; las "mutations" comunican dialogo<->juego), **GDScript Y C#**, notificacion de errores de sintaxis en vivo, efectos de texto. **Localizacion nativa: soporta CSV Y gettext/PO, y todos los `.dialogue` se anaden automaticamente a la Template Generation list en Project Settings > Localization** (POT automatico). Es el mas alineado con PONYTAIL: no impone maquina de estado paralela, reusa el pipeline de traduccion nativo, ambos lenguajes. Este es el default del skill.
- **ALTERNATIVA CORE: Dialogic 2** — `github.com/dialogic-godot/dialogic`, docs `docs.dialogic.pro`. Requiere Godot >=4.3 (OK en 4.6/4.7). Editor de **timeline visual drag-and-drop**, portraits, save states. Default para perfil "visual novel / RPG con mucho retrato y cinematica conversacional". Trae su propio sistema de variables/guardado (roza "arquitectura propia"): si se elige, **aislar su estado tras una capa fina** para no duplicar la autoridad del juego.
- **ESCAPE HATCH (fuera del lazo): Ink + inkgd / godot-ink.** inkgd (GDScript puro): `github.com/ephread/inkgd` — feature-complete pero **sin releases oficiales** (instalar por rama godot4; **fijar commit**, riesgo en upgrade de engine). godot-ink (C#) mas rapido. Brilla en arboles literarios masivos (weave/tunnels/knots). Ofrecido solo como escape hatch documentado, **sin soporte del lazo de verificacion**.
- **ESCAPE HATCH (degradado): Yarn Spinner.** Confirmado en `docs.yarnspinner.dev`: el port **GDScript es ALPHA, "not recommended for use to ship a game just yet"** (requiere Godot 4.6.x+). Solo **C# bindings (Yarn Spinner 3.1, estable)** es shippable. Decision: si se ofrece Yarn, por C#; **Yarn-GDScript va etiquetado "experimental/alpha, NO para produccion"**, jamas como opcion de primera clase en el dispatcher.

**NPCs con LLM en runtime (viabilidad/coste/latencia/seguridad).**
- *Latencia:* ~500 ms es la **heuristica de UX** para conversacion (presentar como heuristica, no como dato duro). El dato duro de arXiv 2604.07385 (DOOM 1.3M params) es sobre **control en bucle de frame** (presupuesto ~100 ms; LLM generalistas lo exceden 6-133x; modelos pequenos especializados ~31 ms). Conclusion: LLM sirve para **conversacion**, jamas para **logica en bucle de frame**.
- *Coste:* inferencia GPU cloud ~$0.10-0.30/M tokens (se acumula en NPCs de alto volumen). Modelos pequenos locales: gratis en CPU de laptop.
- *On-device viable:* Phi-4-mini, Qwen 3, Mistral Small 3, Llama 3.3; persona fija + memoria modular (memoria conversacional + de mundo) sin reentrenar en gameplay (arXiv 2511.10277, "Fixed-Persona SLMs with Modular Memory"); sub-100 ms con cuantizacion/pruning/distilacion (ARM Developer Labs).
- *Plataformas:* Inworld (Agent Runtime gratis, pagas solo consumo de modelo; **TTS-1.5 Mini $5/M chars, TTS-1.5 Max $10/M, Realtime TTS-2 ~$25->$10/M por volumen** — naming actualizado). On-device: GladeCore (dialogo+voz local).
- *Seguridad (recalibrada, correccion clave).* arXiv 2504.11168 ("Bypassing LLM Guardrails", v3 jul-2025) confirma **hasta 100% de evasion** contra seis sistemas, incluyendo **Meta Prompt Guard y Azure Prompt Shield**. Apilar cinco guardrails evadibles (Presidio + Prompt Guard 2 + NeMo + Llama Guard 4 + validador) es teatro de seguridad anti-PONYTAIL: multiplica latencia, coste, dependencias y falsa confianza, y un indie lo desactivara entero. **La garantia real es ARQUITECTURAL, no por filtro.** Jerarquia correcta: (1) **contencion arquitectural PRIMARIA e innegociable** — el LLM produce texto de flavor por un canal que *no puede tocar estado* (sin tools, sin function-calling con efecto, salida tratada como string puro renderizado); si el LLM es fisicamente incapaz de mutar quest flags/combate/economia/navegacion, la prompt injection es irrelevante para la integridad del juego. (2) **Capa de contenido LIGERA y opcional** — un clasificador de salida (p.ej. Llama Guard) + filtro de PII (Presidio) para contenido toxico, documentando que es evadible.

**Worldbuilding y localizacion.**
- *Worldbuilding:* Claude genera lore estructurado como Resources `.tres` (biblia de mundo = datos canonicos versionables) que alimentan tanto el dialogo escrito como, si se usa, el contexto/memoria del LLM. No hay magia: datos + validacion.
- *Localizacion (Godot 4.6/4.7):* gettext **.po/.mo** y CSV. **El skill estandariza en gettext/PO** (plurales + contexto de traduccion que CSV no tiene, mejor con git: un archivo por locale, Poedit/Weblate/Transifex). DM4 ya genera POT automaticamente -> camino coherente de extremo a extremo. Migracion CSV->PO con `csv-to-gettext-converter`.

### Simbiosis con el flujo de la skill (pasos accionables)

**Dispatcher (SKILL.md):** tema `"narrativa" | "dialogo" | "quest" | "npc"` -> `references/13_narrativa.md`. Decide backend por la matriz reducida (default DM4; Dialogic 2 si visual/VN). Detecta version del engine (4.6/4.7) y elige Asset Store correcto. Registra la decision en el log del proyecto / `errors.json` para que el lazo la conozca.

**Lazo de verificacion headless (verify_loop.sh / validate_all.gd):** checks narrativos:
1. **Claves de traduccion:** toda clave `tr()` existe en el `.pot` y en cada `.po` (ningun locale falta) -> error que dispara auto-correccion.
2. **Formas plurales/contexto por locale** donde aplica (gettext lo soporta; CSV no).
3. **Grafo de dialogo:** sin nodos huerfanos ni ramas sin salida (parsear `.dialogue` / timeline Dialogic).
4. **Mutations — TEST DE HUMO HEADLESS, no analisis estatico (correccion bloqueante):** cargar cada `.dialogue`, recorrer todas las ramas en `--headless` con un stub/mock del game state, fallar si una mutation lanza. NUNCA verificar estaticamente "esta mutation existe en el estado del juego": GDScript es dinamico (Callable, call(), autoloads, duck typing) y produce falsos positivos masivos que un lazo auto-correctivo podria "corregir" **borrando dialogo valido**. Cualquier heuristica estatica = warning no bloqueante.
5. **Quests:** cada objetivo con estado alcanzable y de cierre (no "incompletable").
6. **Si hay LLM:** wiring de contencion presente (LLM sin tools con efecto) + captions presentes si hay TTS.

**MCP Summer Engine / Godot AI (ref 30):** principio nuclear: **contenido narrativo = dato git** (`.dialogue`, `.ink`, `.yarn`, `lore/*.tres`, `locale/*.po`); el MCP solo instancia nodos, cablea senales y corre verificacion headless en el engine vivo. Matiz resuelto: si **Summer genera GDScript real** en el proyecto (es drop-in de Godot 4, confirmado: **44 engine tools MCP**, genera `.gd` en archivos reales), ese `.gd` *es* dato git generado por el MCP -> **validarlo con el MISMO hook PostToolUse que el codigo escrito a mano.** Las constantes de Summer (puerto :6550, naming `summer_*`, GameSoul.md, ~27 agent skills, MCP stdio) **NO confirmadas: descubrirlas por handshake/list-tools del MCP vivo** (eso ES el "contrato de capacidades" que la ref 30 nombra) en vez de hardcodear; robusto a cambios de version. Si Summer expone un tool de generacion de dialogo, tratarlo como **acelerador opcional, no fuente de verdad**.

**Commands:** `/godot-add narrative [--backend dm4|dialogic]` (default dm4; ink/yarn-cs solo con flag explicito + aviso de escape-hatch) instala backend + configura gettext + crea arbol de dialogo de ejemplo validado. `/godot-add llm-npc` -> andamiaje con **contencion arquitectural por defecto** (LLM = string puro), on-device por defecto, captions si TTS. `/godot-verify` corre el lazo con subchecks narrativos.

**Hooks (PostToolUse):** validar `.dialogue` / timeline Dialogic / `.po` (sintaxis + claves + grafo) y el GDScript generado por MCP, ademas de `.gd` escrito a mano; anexar a `errors.json`.

### Como se adapta Claude (decisiones, tools, verificacion, ponytail)

**Decide:** (a) Backend por matriz reducida (default DM4; lo justifica en una linea en el log). (b) **LLM-en-runtime: NO por defecto.** Narrativa guionizada (deterministas, localizables, testeables) es first-class y ademas **fallback de accesibilidad cognitiva** (NPCs open-ended aumentan carga cognitiva; barrera para jugadores neurodivergentes). LLM solo cuando el diseno exige conversacion abierta no guionizable Y se acepta coste/latencia/seguridad; entonces: on-device SLM o Inworld Agent Runtime, ~500 ms (heuristica), persona fija + memoria modular, y **el LLM produce SOLO texto de flavor sin autoridad de estado**.

**Tools/comandos:** `Write` para contenido narrativo (`.dialogue`, `lore/*.tres`, `locale/*.po`); MCP Summer/Godot AI solo para instanciar/cablear y disparar verificacion headless (capacidades descubiertas, no hardcodeadas); `/godot-verify` para cerrar el lazo.

**Verifica antes de declarar hecho:** los 6 checks del lazo + arranque headless sin errores narrativos en `errors.json`.

**PONYTAIL aplicado:** *Reusar:* DM4/Dialogic + gettext nativo + `.tres` para lore. Cero parser de dialogo propio, cero i18n propio. *Lazy-not-negligent:* aunque DM4 sea stateless y "facil", Claude NO salta validacion de grafo, claves i18n faltantes, plurales por locale, contencion del LLM, ni accesibilidad (velocidad de texto configurable, skip de animacion, tamano de fuente, lectores de pantalla, **captions obligatorios si hay TTS**).

### Acciones concretas

- Renombrar el plugin a no-versionado y detectar version del engine en runtime; soportar 4.6 y 4.7; resolver addons via nuevo Asset Store.
- Crear `references/13_narrativa.md` y `references/31_llm_runtime_npc.md`; editar `references/30`.
- Ampliar `validate_all.gd` con las funciones narrativas y reemplazar el check estatico de mutations por test de humo headless.
- Crear `scripts/setup_gettext.sh` (o paso en `add_context.sh`).
- Anadir comandos `/godot-add narrative`, `/godot-add llm-npc`, subchecks en `/godot-verify`.
- Extender hooks PostToolUse y agents (`godot-reviewer`, `godot-scripter`).

### Que anadir/cambiar en la skill (archivos/refs/commands)

Ver lista `skill_changes`. Resumen: (1) decoplar de la version del engine; (2) matriz de dialogo reducida a 2 core + 2 escape hatches; (3) ref 31 con contencion arquitectural primaria + guardrails ligeros; (4) test de humo headless en vez de check estatico; (5) descubrir capacidades de Summer, no hardcodear; (6) validar GDScript generado por MCP igual que el escrito a mano; (7) accesibilidad: captions con TTS + plurales por locale.

### Pitfalls y limite lazy-not-negligent

1. **Ancla a 4.6 en el nombre / URLs de Asset Library legacy** -> deuda de mantenimiento desde el dia 1. Solucion: version-decoupling + nuevo Asset Store.
2. **Yarn-GDScript alpha tratado como opcion de primera clase** -> induce a construir sobre runtime no-shippable. Solucion: degradar a experimental; Yarn solo por C#.
3. **inkgd sin release oficial** -> fijar commit, marcar riesgo de upgrade.
4. **Over-engineering de cuatro backends y cinco guardrails** -> traiciona PONYTAIL. Menos es mas: 2 backends, contencion arquitectural + capa ligera.
5. **Check estatico "mutation existe"** -> falsos positivos que el lazo auto-correctivo convierte en **destructor de contenido**. Solucion: test de humo headless ejecutable.
6. **Guardrails como garantia** -> evadibles hasta 100% (2504.11168). La garantia es arquitectural.
7. **CSV en vez de gettext** -> pierdes plurales/contexto, sufres en git. Ir a PO desde el inicio.
8. **Claves de traduccion huerfanas / ramas muertas** -> invisibles hasta runtime en el idioma equivocado. El lazo DEBE atraparlas.
9. **Dialogic 2 imponiendo su estado/guardado** -> aislar tras capa fina.
10. **Accesibilidad como recorte silencioso** -> velocidad de texto, skip, fuente, plurales/genero por locale, **captions con TTS**, modo guionizado como fallback cognitivo.

**El limite lazy-not-negligent de este foco:** Claude puede ser perezoso en *arquitectura* (reusa DM4 + gettext + `.tres`, no inventa nada) pero JAMAS en *grafo valido, claves i18n completas, alcanzabilidad de quests, contencion arquitectural del LLM y accesibilidad del texto (incluidos captions con TTS)*. Esos cinco son innegociables y los fuerza el lazo de verificacion headless.

### Fuentes

- https://github.com/nathanhoad/godot_dialogue_manager
- https://dialogue.nathanhoad.net/
- https://github.com/nathanhoad/godot_dialogue_manager/blob/main/docs/Translations.md
- https://github.com/nathanhoad/godot_dialogue_manager/blob/main/docs/CSharp.md
- https://github.com/dialogic-godot/dialogic
- https://docs.dialogic.pro/
- https://github.com/ephread/inkgd
- https://github.com/inkle/ink-library
- https://docs.yarnspinner.dev/yarn-spinner-for-godot/godot-gdscript
- https://github.com/YarnSpinnerTool/YarnSpinner-Godot
- https://github.com/YarnSpinnerTool/YarnSpinner-Godot-GDScript
- https://yarnspinner.dev/blog/yarn-spinner-in-2026
- https://godotengine.org/releases/4.7/
- https://www.phoronix.com/news/Godot-4.7-Released
- https://www.gamingonlinux.com/2026/06/godot-engine-4-7-is-out-bringing-a-new-asset-store-hdr-support-steam-frame-support/
- https://docs.godotengine.org/en/4.5/tutorials/i18n/localization_using_gettext.html
- https://github.com/Wiechciu/csv-to-gettext-converter/
- https://arxiv.org/abs/2604.07385
- https://arxiv.org/abs/2511.10277
- https://arxiv.org/abs/2504.11168
- https://arm-university.github.io/Arm-Developer-Labs/2025/08/28/NPC-LLM-Runtime.html
- https://www.sitepoint.com/best-local-llm-models-2026/
- https://inworld.ai/pricing
- https://www.gladecore.com/blog/the-4-best-convai-alternatives-for-ai-npcs
- https://www.summerengine.com/godot-ai-mcp
- https://github.com/SummerEngine/summer-engine-agent
