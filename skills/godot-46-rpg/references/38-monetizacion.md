## 38. Monetización (jun 2026)

Veredicto de arranque (firme, conservador): para un RPG 3D en Godot 4.6 el default es **premium pay-once ($15-25 en Steam) + DLC/expansiones significativas**. F2P/IAP/battlepass/suscripción solo si el diseño es genuinamente live-service (loop social/competitivo + liveops). "Monetization follows the design, it doesn't lead it." La monetización es **un sistema RPG más** dentro de la skill, no un add-on: tiene su Resource nativo, su validación headless y su enrutado MCP. Pero el foco se **reenfoca de "compliance auditor" a "billing correctness + disclosure"**: lo único que una skill de scaffolding puede verificar honestamente es lo estructural (existe handler de cada error path, existe pantalla de confirmación pre-compra, si hay aleatoriedad hay odds enlazados a UI). Todo lo demás (dark patterns, DMA, DFA) va al reference como guía para el humano, jamás como bloqueador de convergencia.

### Estado jun-2026 (tools/motores/modelos/técnicas viables AHORA)

**Reglas de plataforma (load-bearing — deciden la arquitectura):**

- **Steam (canal primario del RPG):** las microtransacciones pasan obligatoriamente por **Steam Wallet vía Steam Microtransaction Web API (ISteamMicroTxn/InitTxn)**. CORRECCIÓN CRÍTICA al supuesto "wallet-only client-side": `InitTxn/v3/` se llama desde un **servidor intermedio tuyo**, que provee OrderID (64-bit único), SteamID, AppID, language (ISO 639-1) y currency (ISO 4217). No es client-side puro. Generar una arquitectura sin servicio intermedio es generar una arquitectura imposible. Steam no restringe *qué* vendes pero exige que la compra pase por su wallet; prohíbe incrustar un procesador de pago tercero en cliente. Soporta premium, DLC, MTX y recurring billing. ([implementation guide](https://partner.steamgames.com/doc/features/microtransactions/implementation), [ISteamMicroTxn](https://partner.steamgames.com/doc/webapi/isteammicrotxn), [recurring billing](https://partner.steamgames.com/doc/features/microtransactions/recurring_billing), [pricing](https://partner.steamgames.com/doc/store/pricing))
- **Mods Steam: prohibido venderlos o ponerles paywall.** Donaciones sí, paywall no. Regla de diseño documentada en este reference (NO un check de regex; ver "Pitfalls"). ([Workshop docs](https://partner.steamgames.com/doc/features/workshop))
- **Móvil — disclosure de odds de loot boxes OBLIGATORIO** antes de la compra: Apple App Store (Guideline 3.1.1, desde dic-2017) y Google Play (Developer Policy, desde may-2019). **UK CAP** emitió enforcement notice (feb-2026) exigiendo disclosure prominente en fichas de tienda y anuncios; CAP **monitoriza activamente desde 26-may-2026** tras un periodo de 3 meses. Cambio de age-rating **PEGI binding desde jun-2026**. Esta es la única regla verdaderamente dura y vigente, y merece su aserción headless. ([Fenwick Apple](https://www.fenwick.com/insights/publications/apple-now-requires-disclosure-of-loot-box-odds), [Fenwick Google](https://www.fenwick.com/insights/publications/google-play-now-requires-disclosure-of-loot-box-odds), [games.gg](https://games.gg/news/loot-box-transparency-rules-for-app-store-and-google-play/))

**Fees (jun 2026):** Small Business Program de Apple y Google = **15%** si <$1M USD proceeds el año previo o developer nuevo. Lo normal para un indie. EU DMA (Apple) tiene estructura troceada (initial-acquisition + Store Services + Core Technology Commission con sunset 2026), compleja y relevante solo si distribuyes en EU con link externo — fuera del alcance habitual de esta skill. ([Apple SBP](https://developer.apple.com/app-store/small-business-program/), [Apple DMA](https://developer.apple.com/support/dma-and-apps-in-the-eu/))

**Modelos que funcionan indie 2026:** premium domina (~60% ingresos indie son pay-once); DLC >> microtransacciones para audiencia indie (DLC ~77% del gasto in-game continuado vs ~23% MTX). Subscription/season-pass crece pero es minoritario y solo para live-service. F2P en RPG narrativo single-player = **elección equivocada** (mata retención y reputación).

**Plugins Godot 4.6 reales (la base PONYTAIL — reusar, no construir):**

- **GodotSteam GDExtension 4.4+** (v4.19.x, Steamworks SDK 1.64): MTX/DLC/wallet en PC. Win/Linux/Mac + **Android ARM64. NO iOS.** ([asset 2445](https://godotengine.org/asset-library/asset/2445), [godotsteam.com](https://godotsteam.com/))
- **Godot IAP** — API unificada iOS StoreKit 2 + Android Billing 8, GDScript type-safe, consumables/non-consumables/subscriptions. ([asset 4627](https://godotengine.org/asset-library/asset/4627))
- **GodotGooglePlayBilling** (first-party) + **AndroidIAPP** (Billing v8.x, Godot 4.6+). ([asset 3068](https://godotengine.org/asset-library/asset/3068), [Godot Android IAP docs](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html))
- **Ads:** Unity LevelPlay mediation (ironSource/AdMob), rewarded ads user-initiated, tags COPPA.

**Caso límite cross-store (el Critic acierta, el Architect lo omitió):** GodotSteam no soporta iOS. Un juego **Steam + iOS** necesita DOS sistemas de billing con DOS modelos de entitlement que hay que **reconciliar** (¿el DLC comprado en Steam se honra en iOS?). El reference debe forzar un path de re-verificación de entitlements al arranque, no solo en compra.

**Coste de IA generativa en runtime (decide F2P-con-LLM, principio NO cifras):** LLM en runtime es un **coste marginal por sesión**. Pay-once + LLM ilimitado es **insostenible**: o diseñas un *AI token budget* por jugador, o cap on-device, o el modelo es premium-con-coste-cubierto. CORRECCIÓN: NO hardcodear precios spot de API en este reference (caducan en semanas). El reference declara el principio; las cifras se consultan en runtime cuando se decide la arquitectura, no se fijan aquí.

### Simbiosis con el flujo de la skill (pasos accionables)

**Dispatcher (SKILL.md):** entrada de tema `monetización | monetization | IAP | DLC | battlepass | ads | store` -> `references/31-monetization.md`. Enrutar sub-tema por plataforma (`store=steam|mobile|cross`) porque las reglas divergen.

**Lazo de verificación headless (`verify_loop.sh` + `validate_all.gd`):** monetización entra al lazo, pero con aserciones **ejecutables de verdad**, no teatro de cumplimiento. Solo DOS checks automáticos y UN bloqueador:
- `MON_LOOTBOX_NO_ODDS` (**BLOQUEANTE de convergencia**): si un `MonetizationOffer` tiene `is_randomized = true`, entonces `disclosed_odds` debe estar **no vacío Y enlazado a un nodo de UI mostrado pre-compra**. CORRECCIÓN al Architect: NO exigir que los odds "sumen ~1.0" (loot reales usan drops independientes, tablas anidadas, pity timers -> falsos positivos garantizados). El check correcto es presencia + visibilidad pre-compra, no aritmética de suma.
- `MON_PRICE_HARDCODED` (**warning, no bloqueante**): detectar precios numéricos hardcodeados en UI de tienda. Esto SÍ es regex-detectable y SÍ es un bug real: el juego debe leer precios de la store API (precio regional/impuestos los maneja la plataforma). Único uso honesto de detección estática.
- **Verificación estructural** (parte del "hecho", verificable headless porque es existencia, no intención): existe handler para CADA error path de compra (cancelada, red caída, pendiente, refund); existe pantalla de confirmación pre-compra ("qué compras y por cuánto"); la suscripción tiene UI de cancelación accesible.

CORRECCIÓN CRÍTICA (el Critic acierta): **eliminar del lazo** `MON_DARK_PATTERN`, `MON_EU_DUAL_PAYMENT`, `MON_ADS_MINORS` y `MON_STEAM_MOD_PAYWALL`. Un "timer de presión sin opción de desactivar" es una propiedad semántica de UX no detectable por regex (un `Timer.gd` puede ser un cooldown de habilidad); detectar dual-payment EU es imposible desde GDScript (vive en la cuenta de developer y addendums de Apple, no en el código); "es un mod" no tiene marcador canónico en un `.tres`. Un check verde mientras el dark pattern existe es el **peor resultado posible** (el dev confía en el check) y viola lazy-not-negligent al revés: promete una salvaguarda que no puede cumplir.

**Estos temas pasan a `agents/godot-reviewer` como rúbrica ADVISORY (no blocking):** dark patterns, suscripción cancelable, tags de menores, espíritu DFA. Un agente reviewer que lee intención > regex que finge juzgar ética.

**MCP Summer / Godot AI (ref 30):** CORRECCIÓN CRÍTICA al Architect. Summer Engine `:6550` es un **producto cerrado de un solo proveedor** (afirmaciones ~44 tools `summer_*`, ~27 agent skills, GameSoul.md son marketing del vendor, sin fuente independiente) y es un fork/drop-in de Godot 4, NO Godot upstream nativo. PONYTAIL dice "reusar nativo" — Summer NO es nativo. Por tanto: **el MCP NUNCA genera billing.** El billing SIEMPRE se genera contra el plugin nativo (GodotSteam/Godot IAP), que es el **único camino garantizado**. El MCP solo orquesta editor/escena. Summer Engine se degrada de "backend de primera clase" a "adaptador opcional best-effort". Test del lazo: si `:6550` no responde o el vendor desaparece, la skill sigue generando un RPG monetizado 100% funcional. El único bloqueador de convergencia añadido es `MON_LOOTBOX_NO_ODDS`.

**Commands:** NO crear `/godot-monetize` ni `audit_monetization.gd` separados. El foco cabe en 1 reference + 2 aserciones en `validate_all.gd` + rúbrica advisory en `godot-reviewer`. El resto es ceremonia anti-PONYTAIL. `/godot-verify` ya corre el lazo headless e incluirá el reporte de odds.

### Cómo se adapta Claude (decisiones, tools, verificación, ponytail)

**Árbol de decisión firme:**
1. **Modelo según diseño, no al revés.** Single-player narrativo -> premium + DLC. Solo con loop social/competitivo + liveops considera F2P/battlepass/suscripción.
2. **Plataforma -> API correcta.** PC -> GodotSteam (wallet vía Web API con servidor intermedio). Android -> GodotGooglePlayBilling/AndroidIAPP. iOS+Android cross -> Godot IAP. Steam + iOS -> dos sistemas + reconciliación de entitlements. Nunca procesador tercero en cliente Steam.
3. **¿LLM en runtime?** Si el RPG usa IA viva, Claude exige un **presupuesto de tokens por sesión** y decide on-device vs API por volumen; sin presupuesto no firma una arquitectura pay-once con LLM ilimitado.
4. **Modo conservador siempre.** Activa disclosure de odds (bloqueante). El resto del cumplimiento (EU/menores/DFA) lo trata como guía advisory para el humano, NO como freno del build.

**Qué verifica antes de declarar hecho (headless):** odds presentes + enlazados a UI pre-compra; existencia de handler para todos los error paths; pantalla de confirmación pre-compra; UI de cancelación de suscripción; degradación grácil offline; ausencia de precios hardcodeados (warning).

**PONYTAIL aquí:** `Resource` nativo para `MonetizationOffer`/`StoreCatalog`; señales nativas para callbacks de compra; `user://` + `ConfigFile` para cache de entitlements; plugins oficiales para billing. "Lazy" = no reimplementar billing/store. "No negligente" = jamás recortar disclosure de odds y precio real, validación de receipt, manejo de TODOS los error paths, accesibilidad de la UI de tienda, ni protección de menores.

### Acciones concretas

- Crear `references/31-monetization.md` con el contenido de este reference.
- `SKILL.md`: registrar el tema en el dispatcher; añadir `MON_LOOTBOX_NO_ODDS` (bloqueante) y `MON_PRICE_HARDCODED` (warning) al lazo.
- `scripts/validate_all.gd`: implementar las DOS aserciones + la verificación estructural de error paths / pantalla de confirmación / cancelación de suscripción.
- `references/30-mcp-routing.md`: regla de degradación (MCP nunca genera billing; Summer = adaptador opcional; plugin nativo = camino garantizado); único bloqueador de convergencia = `MON_LOOTBOX_NO_ODDS`.
- `references/28-premium-flows.md`: enlazar flujo "ship con monetización honesta" (premium+DLC default).
- `references/99-philosophy.md`: cláusula lazy-not-negligent de monetización.
- `agents/godot-reviewer`: rúbrica advisory (dark patterns, cancelación, menores, DFA-spirit, sync de entitlements, offline).

### Qué añadir/cambiar en la skill (resumen de archivos)

Nuevos: `references/31-monetization.md`. Editar: `SKILL.md` (dispatcher + 2 códigos en el lazo), `scripts/validate_all.gd` (2 aserciones + checks estructurales), `references/30-mcp-routing.md` (degradación + 1 bloqueador), `references/28-premium-flows.md`, `references/99-philosophy.md`, `agents/godot-reviewer` (rúbrica advisory). NO crear: `/godot-monetize`, `audit_monetization.gd` (over-engineering descartado).

### Pitfalls y límite lazy-not-negligent

**Pitfalls (decididos):**
- **Loot boxes sin odds = rechazo de tienda hoy mismo** (Apple/Google + UK CAP monitorizado desde 26-may-2026 + PEGI jun-2026). No es opinable. Modelado correcto: presencia + visibilidad pre-compra, NO suma=1.0.
- **Asumir Steam MTX client-side** = arquitectura imposible. Requiere servicio intermedio (ISteamMicroTxn/InitTxn server-side).
- **Mods con paywall en Steam = violación de ToS.** Regla documentada en el reference, NO check de regex.
- **LLM-en-runtime en pay-once = bomba de coste.** Presupuesto de tokens + caché + routing + on-device a volumen.
- **F2P por defecto en RPG narrativo = error de modelo.**
- **Confiar en que el MCP "lo hará":** Summer es vendor cerrado; el billing va siempre al plugin nativo.
- **Compliance como bloqueador de build:** el DFA NO es ley (propuesta Q3/Q4 2026, aplicación obligatoria **no antes de 2029**). Bloquear convergencia por una heurística de dark-pattern es paternalismo no fiable, negligente al revés. Va a reviewer advisory.
- **Casos límite ignorados por el Architect (el Critic acierta):** sync de entitlements cross-store; **refund/revocación** (un DLC desbloqueado cuyo pago se revierte -> re-verificar entitlements al arranque, no solo en compra); **degradación grácil offline** (un single-player premium se piratea; jamás bloquear al jugador legítimo sin red por fallo de verificación); **regional pricing/impuestos** (leer de store API, nunca hardcodear).

**Límite lazy-not-negligent (regla dura):**
> Es **lazy (correcto)** no reimplementar billing/store: usar GodotSteam, Godot IAP, GodotGooglePlayBilling, LevelPlay. Es **negligente (prohibido)** recortar: (1) disclosure de odds y de precio real antes de comprar; (2) validación de receipt y manejo de TODOS los error paths (cancelada, red caída, pendiente, refund, revocación); (3) accesibilidad de la UI de tienda (teclado/lector, contraste, sin dependencia de color); (4) protección de menores (tags COPPA, sin ads/IAP manipulativos); (5) cancelación de suscripción accesible; (6) degradación grácil offline. La conveniencia nunca justifica saltarse seguridad, validación o accesibilidad de la transacción. SIMÉTRICAMENTE: es negligente al revés prometer un check de compliance (regex que juzga ética) que no se puede cumplir, o bloquear el build por una sospecha no fiable.

### Fuentes (URLs reales)

- https://partner.steamgames.com/doc/features/microtransactions
- https://partner.steamgames.com/doc/features/microtransactions/implementation
- https://partner.steamgames.com/doc/webapi/isteammicrotxn
- https://partner.steamgames.com/doc/features/microtransactions/recurring_billing
- https://partner.steamgames.com/doc/store/pricing
- https://partner.steamgames.com/doc/features/workshop
- https://github.com/jasielmacedo/steam-microtransaction-api
- https://godotengine.org/asset-library/asset/2445
- https://godotsteam.com/
- https://godotengine.org/asset-library/asset/4627
- https://godotengine.org/asset-library/asset/3068
- https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html
- https://www.fenwick.com/insights/publications/apple-now-requires-disclosure-of-loot-box-odds
- https://www.fenwick.com/insights/publications/google-play-now-requires-disclosure-of-loot-box-odds
- https://games.gg/news/loot-box-transparency-rules-for-app-store-and-google-play/
- https://developer.apple.com/app-store/small-business-program/
- https://developer.apple.com/support/dma-and-apps-in-the-eu/
- https://www.europarl.europa.eu/legislative-train/theme-protecting-our-democracy-upholding-our-values/file-digital-fairness-act
- https://godotengine.org/article/maintenance-release-godot-4-6-2/
- https://www.summerengine.com/godot-ai-mcp
