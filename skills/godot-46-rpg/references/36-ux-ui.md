## 36. UX / UI (jun 2026)

Foco consolidado tras debate Architect/Critic. Estado: Godot 4.6 (release ene-2026). Filosofia PONYTAIL: reusar Control/Theme/Tween/InputMap/SubViewport/AccessKit del engine y plugins maduros; NUNCA arquitectura UI propia. "Lazy, no negligente": jamas recortar tr() de accesibilidad, opt-out de animacion, navegacion por mando, mouse_filter tactil, escala de fuente, espejo accesible diegetico ni subtitulos. Esta ref incorpora la correccion critica de un anti-patron grave (TTS-en-focus sobre AccessKit) y descarta dos capacidades MCP fantasma del primer dossier.

### Estado jun-2026 (tools/motores/modelos/tecnicas viables AHORA)

**Core UI 4.6 (VERIFICADO):**
- **Foco mouse/touch separado de teclado/gamepad.** En 4.6 el foco de raton/tactil se maneja aparte del de teclado/mando: clickar un boton NO dibuja el rectangulo de foco que aparece al navegar con mando. Confirmado en https://www.gdquest.com/library/godot_4_6_workflow_changes/ y proposal https://github.com/godotengine/godot-proposals/issues/6577 . Consecuencia: los menus RPG ya NO necesitan los hacks historicos de grab_focus/suprimir-rectangulo. PONYTAIL exige apoyarse en el comportamiento nativo.
- **Control.pivot_offset_ratio** (PR https://github.com/godotengine/godot/pull/70646 ): pivote normalizado 0..1; Vector2(0.5,0.5) mantiene pivote centrado sin recalcular en _ready/resized. Base correcta para juice de escala. PITFALL: bug abierto de inconsistencia pivot vs ratio https://github.com/godotengine/godot/issues/115977 y en TextureButton https://github.com/godotengine/godot/issues/111914 ; citar, no asumir perfecto.
- **Theme type variations** (https://docs.godotengine.org/en/4.6/tutorials/ui/gui_theme_type_variations.html ): variantes de un control (ButtonPrimary, ButtonDanger) sin subclasear. Regla PONYTAIL reforzada: **un recurso .theme central + type variations; PROHIBIDO theme_override_* disperso salvo excepcion justificada** (lint WARN, ver gates).
- **Tema "Modern"** del editor (grayscale, mejor contraste): https://www.cgchannel.com/2026/01/discover-5-key-features-for-cg-artists-in-godot-4-6/ . Es tema de EDITOR. PENDIENTE-VERIFICAR si el default theme de runtime tambien cambio en 4.6 (no afirmar "solo editor" con certeza; el unico soporte era un post de forum de usuario confundido: https://forum.godotengine.org/t/godot-4-6-1-how-to-use-the-new-theme-in-a-project/134158 ). Aclarar editor-vs-runtime al usuario.
- **RichTextLabel + BBCode**: un RPG es ~90% texto (dialogos, descripciones de items, tooltips, logs de combate). Usar RichTextLabel/BBCode nativo, no labels manuales.
- **Escala de texto / zoom de UI**: el ajuste de accesibilidad #1 en baja vision (mas que screen readers). DEBE existir un setting de escala de fuente/UI (theme_override_font_sizes o escala global del theme). Un dialogo a 11px fijo sin agrandar es negligente aunque el accessibility_name sea perfecto.
- **RTL / CJK**: RPG = candidato a localizacion. Soportar layout_direction (arabe/hebreo se espejan) y fuentes CJK. Incoherente exigir tr() y omitir direccion de layout.

**Accesibilidad nativa AccessKit (VERIFICADO, el gran cambio):**
- AccessKit integrado desde 4.5 y consolidado en 4.6 (PR https://github.com/godotengine/godot/pull/76829 , https://godotengine.org/releases/4.5/ ). NO es un lector embebido: es un **adaptador** entre el OS y los lectores reales (NVDA/VoiceOver/Narrator). Quien anuncia es el lector del OS.
- Todos los Control ganaron pestana Accessibility: **accessibility_name / accessibility_role / accessibility_description** (https://caniplaythat.com/2025/04/29/godot-4-5-improves-accessibility-support-including-screen-readers/ ).
- **System prefs expuestas: 4 reales** (no 2): high-contrast, reduce-animation, reduce-transparency, screen-reader-active. La capa de juice DEBE leer reduce-animation; high-contrast/reduce-transparency informan el theme antes de meter plugins de filtro.
- **tr() OBLIGATORIO**: accessibility_name/description NO entran en la generacion de .POT (issue https://github.com/godotengine/godot/issues/115366 ) -> quedan sin traducir si se ponen como literal. SIEMPRE tr("KEY"). Este es el unico gate de lint que merece ser FAIL.
- Demo de referencia 4.6: https://github.com/aefren/godot-accessibility-demo .
- CAVEATS reales: sigue experimental, editor solo parcialmente cubierto; warnings de accesibilidad enganosos en algunos controles (https://github.com/godotengine/godot/issues/117159 ). La prueba manual con NVDA es OBLIGATORIA; headless no la sustituye.

**CORRECCION CRITICA — NO usar TTS en focus_entered sobre AccessKit:**
- DisplayServer.tts_* (https://docs.godotengine.org/en/stable/classes/class_displayserver.html ) y AccessKit son **caminos mutuamente excluyentes, no complementarios**. Conectar focus_entered -> tts_speak() SOBRE AccessKit produce **doble lectura** (NVDA lee el arbol AccessKit + tu TTS), y peor: tu tts usa la voz de Godot, no la voz/velocidad de NVDA que el usuario ciego configuro. Es activamente hostil.
- Default PONYTAIL = **AccessKit puro**: rellenar name/role/description y dejar que el OS lea. DisplayServer.tts_* se reserva para (a) plataformas sin lector OS, (b) narrativa diegetica hablada, (c) opt-in explicito. El lint NO debe exigir focus_entered->tts; si acaso, avisar de TTS manual redundante junto a AccessKit.

**Matriz de plugins (depurada):**
- **AccessKit nativo** = roles/nombres/foco/screen-reader/system-prefs. Primera y unica capa para lectura.
- **Godot Accessibility Suite (HauntedBees)** https://github.com/HauntedBees/Godot-Accessibility-Suite = subtitulos/captions con import .srt, CaptionedAudioStreamPlayer (sync audio+caption), remap UI, alternativas a hold, cooldowns de input. Tapa lo que AccessKit NO da. UNICO de los tres que se sostiene limpio.
- **godot-accessibility (lightsoutgames)** https://github.com/lightsoutgames/godot-accessibility : screen reader legacy pre-AccessKit. En 4.6 con AccessKit es **incompatible/perjudicial** (compite por la lectura, origen del patron TTS-en-focus). DESACONSEJAR activamente, no listar como fallback.
- **ColorBlind Tool (asset #3460)** https://godotengine.org/asset-library/asset/3460 : post-process daltonismo. Compat Forward+/Compatibility 4.6 NO verificada. ANTES de meterlo, respetar la system pref high-contrast/reduce-transparency de AccessKit.

**Input / mando / tactil (VERIFICADO):**
- InputMap es el mecanismo nativo de remap runtime (https://docs.godotengine.org/en/stable/classes/class_inputmap.html , tutorial https://gamedevartisan.com/tutorials/godot-fundamentals/input-remapping ): action_erase_events + action_add_event, persistir.
- Controllers nativos en todas las plataformas: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html .
- PITFALL: MarginContainer/PanelContainer/ColorRect/Panel consumen el touch por defecto y matan el joystick virtual -> mouse_filter = IGNORE/PASS correcto (https://dredyson.com/fix-virtual-joystick-input-blocking-in-godot-4-6-a-proptech-developers-step-by-step-debug-guide-for-custom-touch-controls-in-real-estate-mobile-apps/ ).
- Virtual Input Device System (proposal https://github.com/godotengine/godot-proposals/issues/13943 ) NO esta en 4.6 = FUTURO, no construir sobre ello.
- Glyphs de mando por dispositivo = NO-VERIFICADO (sin API nativa). Resolver por Input.get_joy_name() + atlas propio minimo o asset externo. No prometer API inexistente.
- Caso limite: split-screen co-op local. El foco de Control es single-focus por viewport -> multiples SubViewport con foco independiente; AccessKit + varios jugadores con distintos lectores es terreno sin definir. Documentar como caso limite.

**Juice / feedback (VERIFICADO + corregido):**
- Tween (one-shot, encadenable, con kill() al interrumpir para no dejar estados a medias) + AnimationPlayer en paralelo; flechas JRPG con tween ~0.1s easing cubic (https://school.gdquest.com/courses/godot_2d_secrets_godot_3/jrpg_combat_UI/the_action_menu , https://toxigon.com/creating-interactive-ui-in-godot ).
- Assets opcionales (referencia, no dependencia): Juicy Navigation Overlay https://minaristudio.itch.io/juicy-navigation-overlay .
- ARQUITECTURA CORREGIDA: en vez de "cada tween consulta el flag" (N puntos, grep fragil), un **autoload AccessibilityState** que lee las system prefs de AccessKit al inicio + en cambio, expone senal reduce_motion_changed, y un **helper juice_tween(node)** que internamente respeta el estado. Un punto de control: o usas el helper (correcto por construccion) o no hay juice. Asi el grep de reduce-motion es innecesario.

**UI diegetica 3D (VERIFICADO):**
- Tecnica estandar: SubViewport -> Sprite3D.texture = $SubViewport.get_texture(), Billboard=Enabled, tamano SubViewport = tamano textura (https://kidscancode.org/godot_recipes/4.x/3d/healthbars/ ).
- Limite: Control interactivo en 3D no es directo (proposal https://github.com/godotengine/godot-proposals/issues/8679 ) -> raycast->coords de SubViewport manual.
- Conflicto real (buen catch): AccessKit lee arbol de Control; un Control dentro de SubViewport-en-Sprite3D puede NO exponerse al lector. REGLA: todo UI diegetico lleva un **espejo accesible** (HUD 2D oculto pero leible, o anuncios por evento). "UI bonita pero invisible al lector" = negligente.

**MCP (VERIFICADO, depurado de fantasmas):**
- Summer Engine = engine-level, localhost:6550, ~44 tools summer_*, GameSoul.md, skills auto-fire (https://github.com/SummerEngine/summer-engine-agent , https://docs.summerengine.com/mcp/cli-reference , https://www.summerengine.com/blog/godot-mcp-servers-guide ). Tools VERIFICADOS relevantes: summer_get_scene_tree, summer_inspect_node, summer_get_debugger_errors/warnings, summer_get_console.
- DESCARTADO (capacidades fantasma del primer dossier): runtime_focus_probe y screenshot_ui NO existen ni estan verificados. AccessKit publica su arbol al OS/lector, no a un endpoint MCP. No hay evidencia de focus-probe ni de captura de contraste WCAG via MCP.
- Distincion real para el contrato de capacidades: MCP file-level (edita archivos) vs engine-level (nodos vivos, run, debugger). Solo construir routing sobre tools verificados.

### Simbiosis con el flujo de la skill (pasos accionables)

**Dispatcher (SKILL.md):** dividir el monolito 36 en sub-refs (4-5, fusionar onboarding dentro de core):
- "theme|container|control|layout|texto|fuente|richtext|rtl" -> references/36-ux-ui-core.md
- "accesibilidad|screen reader|accesskit|tts|subtitulos" -> references/36b-accessibility.md
- "juice|feedback|tween|animacion|reduce motion" -> references/36c-juice.md
- "diegetic|ui 3d|mundo|billboard|subviewport" -> references/36d-diegetic-ui.md
- "input|remap|mando|tactil|gamepad|splitscreen" -> references/36e-input.md

**Generacion POR CONSTRUCCION (jugada PONYTAIL central, invierte el lazo):** godot-scripter y los generadores de /godot-add ui-* producen escenas correctas por construccion: cada control nace con tr() name, dentro del theme central, con focus_mode correcto, juice via helper juice_tween. Si el generador es correcto, el lint pesado sobra. El lint queda como red de seguridad minima.

**Lazo de verificacion (validate_all.gd / verify_loop.sh) — SOLO gates deterministas:**
- FAIL: accessibility_name/description con string literal NO envuelto en tr() (ataca #115366, parseable).
- FAIL: mouse_filter no-IGNORE/PASS en contenedor sobre zona tactil (determinista, pitfall virtual joystick).
- WARN: theme_override_* disperso fuera del .theme central (deuda de UI, determinista).
- ELIMINADOS / degradados a WARN informativo (jamas FAIL): "accessibility_name vacio en BaseButton" (un Button con text deriva su nombre accesible -> falsos positivos masivos, replicaria el bug #117159), "vecinos de foco resolubles" (el foco automatico por geometria solo existe tras layout en runtime; exigir vecinos explicitos empuja al cableado a mano que 4.6 elimino = anti-PONYTAIL), "grep de reduce_motion en tweens" (innecesario si se usa el helper juice_tween). Razon: FAIL con falsos positivos -> el usuario desactiva el hook -> pierde TODA la accesibilidad. El exceso de celo mata la feature.
- Resultados a errors.json (ref 30) como el resto del lazo.

**MCP routing (ref 30):** NO inventar capacidades. Engine-level (Summer vivo) usa summer_get_scene_tree + summer_inspect_node para verificar, tras correr la escena, que los nodos tienen props de accesibilidad pobladas y el theme aplicado (estado REAL, honesto). File-level (Godot AI HTTP) cae a lint estatico. En AMBOS casos, "¿NVDA realmente lo lee?" es prueba MANUAL con NVDA (referenciar aefren demo); no se finge automatizacion. Descubrir capacidades por handshake, no hardcodear endpoints.

**Commands:** /godot-add con subtipos ui-menu|ui-hud|ui-diegetic|accessibility|input-remap (genera escena + script por senales + accesibilidad rellenada, no como TODO). /godot-verify muestra reporte UX separando FAIL deterministas de WARN. /godot-mcp documenta la degradacion engine-level vs file-level con honestidad.

**Hooks (PostToolUse):** al tocar .tscn/UI .gd, ejecutar solo los 2 gates FAIL + WARN de theme; escribir a errors.json. El "lazy-not-negligent" mecanico se limita a checks que NO producen falsos positivos.

### Como se adapta Claude (decisiones, tools, verificacion, ponytail)

1. **Nativo primero, firme.** Foco mouse/touch separado -> no escribir manejo de rectangulos. Theme type variations + .theme central -> no subclasear ni regar overrides. pivot_offset_ratio -> no recalcular pivote (citando bugs #115977/#111914).
2. **Accesibilidad por construccion, no opcional, AccessKit puro.** Cada control nace con accessibility_name via tr("KEY"). NO conectar TTS a focus_entered (anti-patron de doble lectura). DisplayServer.tts_* solo para narrativa hablada o plataformas sin lector OS. Leer reduce-animation antes de cualquier juice (via helper).
3. **Texto y escala primero.** RichTextLabel/BBCode para dialogos; setting de escala de fuente/UI; layout_direction para RTL; fuentes CJK.
4. **Matriz de plugins depurada:** AccessKit (lectura) + Accessibility Suite (subtitulos/.srt, hold-toggle, remap). DESACONSEJAR lightsoutgames godot-accessibility en 4.6. ColorBlind Tool solo tras respetar system prefs.
5. **Diegetico con espejo accesible** siempre.
6. **Tools:** backend Summer vivo -> crear nodos en arbol vivo, correr escena, inspeccionar props de accesibilidad/theme con summer_get_scene_tree/summer_inspect_node, leer debugger; coherencia de art-direction via GameSoul.md. Backend file-level -> editar + lint estatico headless + marcar prueba manual NVDA pendiente.
7. **Verificacion honesta:** headless valida tr() + mouse_filter + theme central. Runtime (Summer) valida props pobladas reales. Screen reader real = SIEMPRE manual con NVDA; no se finge.

PONYTAIL aplicado: reusar Control/Theme/Tween/InputMap/SubViewport/AccessKit + 2 plugins maduros, NUNCA UI propia. Lazy != negligente: jamas recortar tr() en cada control, opt-out de animacion (helper), navegacion por mando, mouse_filter tactil, escala de fuente, espejo accesible diegetico, subtitulos con audio narrativo.

### Acciones concretas

- Crear references/36-ux-ui-core.md, 36b-accessibility.md, 36c-juice.md, 36d-diegetic-ui.md, 36e-input.md (onboarding fusionado en core).
- Anadir entradas de dispatcher en SKILL.md.
- validate_all.gd: implementar _lint_ux(node) con SOLO los 2 gates FAIL (tr() en name/desc; mouse_filter tactil) + 1 WARN (theme_override disperso). Eliminar los checks fragiles.
- godot-scripter: generar controles correctos por construccion (tr() name, theme central, focus_mode, helper de juice).
- AccessibilityState autoload + helper juice_tween(node) como plantilla generada.
- godot-reviewer: checklist UX corregido (incluye no-TTS-redundante, escala de fuente, RTL, espejo diegetico).
- ref 30: routing sobre tools Summer verificados; eliminar runtime_focus_probe/screenshot_ui; documentar prueba manual NVDA.
- output-styles: render PASS/WARN/FAIL separando severidades.

### Que anadir/cambiar en la skill

Ver skill_changes. Resumen: 5 sub-refs nuevas, dispatcher actualizado, lint reducido a gates deterministas, generacion por construccion como motor de calidad, autoload+helper de accesibilidad/juice, MCP routing sin capacidades fantasma, agents/output-styles alineados.

### Pitfalls y limite lazy-not-negligent

PITFALLS VERIFICADOS:
- POT no captura accessibility name/desc (#115366) -> siempre tr(). Unico gate FAIL solido.
- TTS manual en focus_entered SOBRE AccessKit = doble lectura + voz equivocada. Anti-patron, NO hacerlo.
- Lint de "name vacio / vecinos de foco / grep reduce-motion" como FAIL = falsos positivos (replica #117159), empuja a cableado de foco a mano (anti-4.6/PONYTAIL), grep fragil. Degradar o eliminar.
- runtime_focus_probe / screenshot_ui = capacidades MCP inexistentes. No disenar arquitectura sobre ellas.
- AccessKit experimental, editor parcial, warnings enganosos (#117159) -> NVDA manual obligatorio, headless no sustituye.
- Contenedores comen el touch en 4.6.x -> mouse_filter explicito.
- UI diegetica invisible al lector -> espejo accesible.
- Confundir tema Modern de editor con runtime (PENDIENTE-VERIFICAR).
- Tween sin kill() deja estados a medias.
- pivot_offset_ratio con bugs abiertos #115977/#111914.

LIMITE LAZY-NOT-NEGLIGENT (linea roja): se PERMITE reusar engine + 2 plugins maduros y no escribir UI propia. NO se permite recortar: (1) accessibility_name traducible via tr() en cada control interactivo, (2) opt-out de animacion leyendo reduce-animation (via helper), (3) navegacion de foco con mando funcional, (4) mouse_filter correcto en tactil, (5) escala de fuente/UI para baja vision, (6) espejo accesible del UI diegetico, (7) subtitulos cuando hay audio narrativo, (8) layout_direction RTL si hay localizacion. Un menu "bonito y con juice" no navegable a ciegas, sin mando, o con texto a tamano fijo es NEGLIGENTE y debe fallar el lazo (en los puntos que sean deterministas) o avisarse explicitamente (en los que requieren juicio).

### Fuentes (URLs reales)

- https://godotengine.org/releases/4.6/
- https://www.gamedeveloper.com/programming/godot-4-6-is-here-with-a-fresh-look-and-a-promise-to-prioritize-workflow
- https://www.gdquest.com/library/godot_4_6_workflow_changes/
- https://www.cgchannel.com/2026/01/discover-5-key-features-for-cg-artists-in-godot-4-6/
- https://forum.godotengine.org/t/godot-4-6-1-how-to-use-the-new-theme-in-a-project/134158
- https://docs.godotengine.org/en/4.6/tutorials/ui/gui_theme_type_variations.html
- https://github.com/godotengine/godot/pull/70646
- https://github.com/godotengine/godot/issues/115977
- https://github.com/godotengine/godot/issues/111914
- https://github.com/godotengine/godot-proposals/issues/6577
- https://godotengine.org/releases/4.5/
- https://github.com/godotengine/godot/pull/76829
- https://caniplaythat.com/2025/04/29/godot-4-5-improves-accessibility-support-including-screen-readers/
- https://www.gamedeveloper.com/programming/godot-4-5-ushers-in-accessibility-features-including-screen-reader-support
- https://github.com/godotengine/godot/issues/117159
- https://github.com/godotengine/godot/issues/115366
- https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html
- https://docs.godotengine.org/en/stable/classes/class_displayserver.html
- https://github.com/aefren/godot-accessibility-demo
- https://forum.godotengine.org/t/godot4-screen-reader-accessibility/55671
- https://github.com/HauntedBees/Godot-Accessibility-Suite
- https://github.com/lightsoutgames/godot-accessibility
- https://godotengine.org/asset-library/asset/3460
- https://docs.godotengine.org/en/stable/classes/class_inputmap.html
- https://gamedevartisan.com/tutorials/godot-fundamentals/input-remapping
- https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html
- https://dredyson.com/fix-virtual-joystick-input-blocking-in-godot-4-6-a-proptech-developers-step-by-step-debug-guide-for-custom-touch-controls-in-real-estate-mobile-apps/
- https://github.com/godotengine/godot-proposals/issues/13943
- https://school.gdquest.com/courses/godot_2d_secrets_godot_3/jrpg_combat_UI/the_action_menu
- https://toxigon.com/creating-interactive-ui-in-godot
- https://minaristudio.itch.io/juicy-navigation-overlay
- https://kidscancode.org/godot_recipes/4.x/3d/healthbars/
- https://github.com/godotengine/godot-proposals/issues/8679
- https://github.com/godotengine/godot-proposals/discussions/4093
- https://www.yamii.shop/2026/04/04/diegetic-ui-guide/
- https://github.com/SummerEngine/summer-engine-agent
- https://github.com/SummerEngine/summer-engine-agent/blob/main/README.md
- https://docs.summerengine.com/mcp/cli-reference
- https://www.summerengine.com/blog/godot-mcp-servers-guide
- https://www.summerengine.com/godot-ai-mcp
- https://www.summerengine.com/blog/godot-ai-agent-guide
- https://www.summerengine.com/blog/what-is-godot-mcp
