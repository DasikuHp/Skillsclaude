## 40. Publicación (jun 2026)

Llevar un RPG 3D Godot 4.6 de "jugable" a "publicado" en Steam / itch.io / escritorio / móvil / web / consolas: builds, CI, tienda/wishlist/Next Fest, age ratings, compliance de stores y export Summer. Encaja como **fase terminal con su propio lazo de convergencia (release-gate)**, no como un tema más del dispatcher. Decisiones firmes, ponytail (reusar herramientas oficiales; lazy pero nunca negligente: jamás recortar validación de build, manifests, ratings, accesibilidad in-game ni compliance legal).

**Regla de oro de este foco (anti-obsolescencia):** este reference contiene **mecánica estable**, nunca **cifras con caducidad**. Toda fecha, porcentaje, requisito de store o estado de navegador se **busca en runtime** (la skill ya tiene WebSearch en el loop auto-correctivo de ref 30) en el momento de publicar. Hornear "31-ago-2026" o "68% wishlists" en un archivo estático garantiza que la skill mienta en el trimestre siguiente.

### Estado jun-2026 (tools/motores/modelos/técnicas viables AHORA)

- **Godot 4.6** (27-ene-2026) es la base. El export se dispara **headless por CLI**: `godot --headless --export-release "<preset>" <salida>`, gobernado por **`export_presets.cfg`** por plataforma y **export templates de la versión EXACTA** (4.6). Mismatch templates↔engine = export roto silencioso (causa #1). Trae **LibGodot** (engine como librería embebible) — útil para embebido/launchers, **NO** para consolas (W4 usa SDK privado, no LibGodot). Doc: https://godotengine.org/article/release-candidate-godot-4-6-rc-1/ · https://www.strayspark.studio/blog/godot-46-export-web-android-ios-guide
- **Targets oficiales 4.6 automatizables por nosotros**: Windows/macOS/Linux, Web (HTML5/WASM/WebGL2 vía Emscripten), Android. iOS exporta pero genera un proyecto Xcode → el SDK lo fija el **Xcode del dev en macOS**, no Godot.
- **Steam**: tienda + wishlist + Next Fest (tres ediciones/año). Elegibilidad Next Fest: cuenta Steamworks en regla, **store page pública**, **demo jugable pública**, fecha de lanzamiento posterior al cierre, **una sola participación por juego**. Steam está **FUERA de IARC**: usa su **content survey propio de Steamworks**. Doc: https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest · https://presskit.gg/field-guides/steam-next-fest-guide
- **Age ratings**: **IARC** (un cuestionario → ESRB/PEGI/USK) lo usan Microsoft/Xbox, Nintendo eShop, PlayStation Store, Google Play; **Steam** survey propio; **itch.io** flags manuales del dev. Depende del **contenido real** del RPG (violencia/gore, microtransacciones/loot boxes, chat/UGC). Doc: https://globalratings.com/ · https://en.wikipedia.org/wiki/International_Age_Rating_Coalition
- **Móvil**: Google Play exige **AAB** y target API alta (Android 16/API 36; verificar deadline vigente en runtime), y **closed testing con testers reales/días continuos** para cuentas personales nuevas. Apple exige **`PrivacyInfo.xcprivacy`** y build con SDK iOS reciente. Doc: https://support.google.com/googleplay/android-developer/answer/11926878 · https://developer.apple.com/app-store/submitting/
- **Web (pitfall real)**: Godot 4 web con threads necesita **SharedArrayBuffer** → exige **cross-origin isolation** (COOP `same-origin` + COEP `require-corp`/`credentialless`). El estado de itch.io+Firefox es **inestable**: itch usa COEP `credentialless`, su habilitación en Firefox depende de un **token de Origin Trial que ya caducó (fin 2023)** y el fallo se da dentro del iframe (el pop-out a ventana nueva suele arreglarlo). **No afirmar compatibilidad de navegador como hecho estático.** Doc: https://itch.io/blog/456223/godot-cross-origin-isolation-and-sharedarraybuffers · https://github.com/nisovin/godot-coi-serviceworker
- **CI/CD**: Godot Linux headless + templates → export por preset → **butler** (itch, `BUTLER_API_KEY`) y **steamcmd/SteamPipe** (Steam). Imagen reusable **abarichello/godot-ci**. Doc: https://github.com/abarichello/godot-ci · http://mreliptik.dev/godot-auto-export/
- **Consolas**: **W4 Consoles** (Switch/Switch2 beta/Xbox Series/PS5) para Godot 4.3+. NDA + SDK privados + dev-kits + paquete comercial → **handoff, NO automatizable headless por nosotros**. Doc: https://www.w4games.com/w4consoles · https://godotengine.org/consoles/
- **Summer Engine**: motor AI-native compatible con Godot 4; exporta a Steam/desktop/móvil/web (consolas "con licencia adecuada"). **VERIFICADO jun-2026**: el export va por el **CLI de Summer** (`npx -y summer-engine@latest`), **NO** hay un tool MCP `summer_export`/`summer_publish` confirmado — los ~44 tools MCP operan el **engine vivo** (escenas, props, run, errores, assets), no publican. Doc: https://github.com/SummerEngine/summer-engine-agent · https://www.summerengine.com/cli · https://docs.summerengine.com/

### Simbiosis con el flujo de la skill

1. **Dispatcher (SKILL.md)**: una entrada `publicar|export|steam|itch|wishlist|rating|store|ci|build|consola|movil|web|publish → references/31_publishing.md`. **Sin** sub-archivos 31a-31g (taxonomía burocrática que viola ponytail y caduca).
2. **Detección de motor PRIMERO, routing después**: ¿Godot stock o Summer? Si **Summer**, el export canónico es **el CLI de Summer** (puede producir runtime/formato propio; no asumir intercambiabilidad con `godot --headless`). Si **Godot stock**, el build de release canónico es **CLI headless de Godot** (determinista, reproducible, CI-able). MCP (Summer vivo :6550 o Godot AI HTTP) es **conveniencia interactiva**; el artefacto de release nunca depende de un editor vivo.
3. **Introspección MCP obligatoria** antes de enrutar: listar tools reales. Como el export **no** es tool MCP, el path de publish es **CLI** (Summer o Godot según motor). Nunca inventar `summer_export`.
4. **Release-gate loop** (extiende verify_loop.sh con el mismo patrón auto-correctivo de ref 30):
   - `export_presets.cfg` tiene preset por target solicitado.
   - Export templates de la versión **exacta 4.6** instalados.
   - Export headless real por preset → exit 0 + artefacto no vacío.
   - Smoke-run: desktop `--headless --quit-after N`; web → Playwright headless (Chromium+Firefox) carga el `.html`, asserta `crossOriginIsolated===true` y arranque; android `bundletool`/`aapt2` valida el AAB.
   - Checklist compliance por target (privacy manifest, target API, COOP/COEP, rating draft).
   - Fallo → diagnóstico → corrección → re-export hasta converger o reportar bloqueante.
5. **Hook PostToolUse** sobre `export_presets.cfg` + manifests → valida sintaxis, paths, match versión-templates, coherencia COOP/COEP → escribe `errors.json` (mismo patrón que el hook `.gd`).
6. **Commands**: `/godot-publish <target...>`; `--release` en `/godot-verify`; `/godot-summer` delega al CLI Summer; `/godot-flow` añade la secuencia jugable→publicado (Next Fest checklist, store page, demo, ratings).

### Cómo se adapta Claude (decisiones, tools, verificación, ponytail)

- **Targets**: infiere/pregunta el set {Steam, itch, desktop, web, Android, iOS, consola}; por target elige pipeline (Summer CLI si el proyecto es Summer; Godot CLI headless si stock).
- **Web threading**: para RPG 3D → **threaded + service-worker COI (nisovin) por defecto**, justificado por **independencia de hosting** (no depende del token caducable de itch), no por Firefox. El artefacto se **prueba con browser headless real** como oráculo; reporta el estado **observado hoy**, no citas de blogs viejos. Demo ligera → ofrece no-threads.
- **Rating**: genera **borrador** (Steam survey + IARC) a partir de señales detectadas (combate letal, gore, microtransacciones, chat/UGC, loot boxes); **nunca lo declara final** — el dev confirma.
- **Next Fest**: si hay fecha de lanzamiento, decide edición, calcula ventana de pitch a prensa/streamers, exige store page + demo pública antes de registrar, y advierte **una-sola-participación**.
- **Consolas**: **no automatizar el port**; produce dossier de portabilidad (filesystem no asumido, input abstracto, sin APIs no portables) + handoff W4.
- **Tools**: Bash (`godot --headless`, instalación de templates, `butler push`, `steamcmd`, `bundletool`/`aapt2`, generación PWA), Playwright headless para web, GitHub MCP para el workflow de Actions (reusando abarichello/godot-ci) cuando el dev lo pida.
- **Verifica SIEMPRE**: versión Godot↔templates idénticas; export exit 0 + artefacto no vacío + smoke-run; web COOP/COEP observado en runtime; móvil target API y AAB; checklist anti-rechazo (crashes/placeholders/metadata/privacy/demo-account).
- **Ponytail**: reusar `export_presets.cfg` + templates + butler + steamcmd + abarichello/godot-ci + service-worker nisovin + cuestionario IARC/Steam. **NO** construir export manager/uploader/CI-generator propios. Si la solución necesita 8 references y 5 scripts, está mal segmentada.

### Acciones concretas

- Confirmar motor (Godot stock vs Summer) antes de elegir CLI de export.
- Introspeccionar MCP vivo; confirmar que export es CLI (no tool MCP) → fallback CLI.
- Correr el release-gate por target; para web, oráculo browser headless.
- Buscar en runtime: deadlines móviles vigentes, fechas/elegibilidad de la edición de Next Fest aplicable, estado actual de itch+SAB+Firefox, requisitos de manifest. No leerlos de este archivo.
- Generar drafts (rating, store copy, manifests, workflow CI) con guardas; subir solo si el gate pasó.

### Qué añadir/cambiar en la skill

- **references/**: UN `31_publishing.md` (este). NO crear 31a-31g.
- **scripts/**: extender `verify_loop.sh` + un único `release_gate.sh` (thin-wrapper sobre godot/summer export + butler + steamcmd). NO export_all.sh/upload.sh/gen_ci.sh/gen_privacy_manifest.sh separados.
- **hooks/**: PostToolUse para `export_presets.cfg` + manifests → `errors.json`.
- **commands/**: `/godot-publish`; `--release` en `/godot-verify`; `/godot-summer` (export CLI Summer); `/godot-flow` (jugable→publicado).
- **agents/**: `godot-reviewer` modo "release-review" (compliance + anti-rechazo + accesibilidad **in-game** verificable: remapeo input, subtítulos, escala UI, daltonismo — NO accesibilidad de store page, que es checklist humano sin superficie técnica).
- **SKILL.md**: entrada dispatcher + gate de dos niveles.

### Pitfalls y límite lazy-not-negligent

**Pitfalls técnicos:**
- **Mismatch templates↔4.6** = export roto silencioso. Verificar versión exacta siempre.
- **Web threaded + itch + Firefox** = estado inestable dependiente de token caducable. Por eso default = service-worker COI (independiente del host), y **probar el artefacto**, no afirmar compatibilidad.
- **Deadlines móviles duros** (Play API alta, Apple SDK): **buscar el deadline vigente en runtime**, no hornearlo.
- **Closed-testing Play** para cuentas nuevas bloquea releases — planificar con semanas de antelación.
- **Next Fest: una sola vez por juego** — no quemarla con store page/demo a medias.
- **`PrivacyInfo.xcprivacy` ausente/incoherente** = rechazo Apple casi seguro.
- **iOS SDK** solo es verificable con **macOS + Xcode en el loop**; en CI Linux/Godot headless es **handoff humano**, NO un "check no negociable" teatral.

**Pitfalls de inventar (regla WEB):**
- **NO asumir** `summer_export`/`summer_publish` como tool MCP — el export es **CLI**. No asumir intercambiabilidad de artefacto Godot↔Summer (supuesto load-bearing sin fuente).
- No inventar endpoints Steamworks/IARC; usar portales oficiales.

**Límite lazy-not-negligent (decisión firme):**
- **SÍ automatizar**: export, smoke-run, generación de manifests/CI, drafts de rating y store copy, subida con guardas.
- **Gate de dos niveles**: `--channel test` advierte y **permite** placeholders/builds incompletos (playtest, demo privada — workflow legítimo de iteración); `--channel production-store` aplica **gate duro + compliance**.
- **NUNCA automatizar sin confirmación humana**: declaración final de age rating (riesgo legal), botón de publicar a producción (Steam/Apple/Play), claim de privacidad (qué datos recoges de verdad), port a consola (NDA/SDK). Claude **prepara y verifica**; el dev **declara y publica**. Recortar validación de build, manifests, accesibilidad in-game o compliance legal = negligente, prohibido.

### Fuentes

- https://godotengine.org/article/release-candidate-godot-4-6-rc-1/
- https://www.strayspark.studio/blog/godot-46-export-web-android-ios-guide
- https://en.wikipedia.org/wiki/Godot_(game_engine)
- https://www.w4games.com/w4consoles · https://godotengine.org/consoles/
- https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest · https://presskit.gg/field-guides/steam-next-fest-guide
- https://globalratings.com/ · https://en.wikipedia.org/wiki/International_Age_Rating_Coalition
- https://support.google.com/googleplay/android-developer/answer/11926878 · https://developer.apple.com/app-store/submitting/
- https://itch.io/blog/456223/godot-cross-origin-isolation-and-sharedarraybuffers · https://github.com/nisovin/godot-coi-serviceworker · https://godotengine.org/article/progress-report-web-export-in-4-3/
- https://github.com/abarichello/godot-ci · http://mreliptik.dev/godot-auto-export/
- https://github.com/SummerEngine/summer-engine-agent · https://www.summerengine.com/cli · https://docs.summerengine.com/
