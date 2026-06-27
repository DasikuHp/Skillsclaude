## 35. Assets y pipeline (jun 2026)

> Contexto: skill `godot-46-rpg`. Foco: generar y traer a la escena assets 3D/2D/audio para un RPG en Godot, con IA, sin violar PONYTAIL ni "lazy-not-negligent". Esta referencia consolida el debate Architect/Critic: conserva el catalogo y la aplicacion de nodos nativos (lo mejor del Architect), incorpora las correcciones verificadas del Critic (licencia de Meshy, copyrightability, version de Godot, anti-over-engineering) y descarta lo dudoso.

### Estado jun-2026 (tools/motores/modelos/tecnicas viables AHORA)

**Aviso de version (corregido).** Godot **4.7 es stable desde el 18-jun-2026**; los docs en `/en/stable/` ya sirven 4.7. El skill se llama `godot-46-rpg` pero debe **declarar version-target explicita** y tratar **4.7 como canonico con flag de compat 4.6**. Anclar mentalmente a 4.6 "porque lo dice el nombre" es deuda desde el dia uno: el importador GLTF y el sistema de materiales cambian entre minors. `verify_loop.sh` debe leer la version del binario y advertir si hay desajuste con los docs.
- Godot 4.7 download: https://godotengine.org/download/archive/4.7-stable/
- Release policy: https://docs.godotengine.org/en/stable/about/release_policy.html

**Texto/imagen -> malla 3D (geometria + PBR).** Todas las fuentes coinciden en un caveat universal: **lo generado por IA NO es production-ready** (triangulos densos, n-gons, UVs sucias, normales/tangentes incoherentes) -> retopo obligatorio.
- **Meshy** — text/image-to-3D, PBR, auto-rig (Meshy Animate), export nativo a Godot/Unreal/Blender. PBR pulido. https://www.meshy.ai/ · https://www.meshy.ai/features/text-to-3d · https://www.meshy.ai/features/ai-animation-generator
- **Tripo AI** — el mas rapido para el bucle "generate -> reject -> regenerate" (humano-en-el-loop por diseno), auto-rig de 1 clic, retopo en navegador. https://www.tripo3d.ai/features/ai-auto-rigging · https://studio.tripo3d.ai/workspace/retopology/
- **3D AI Studio** — remesh a low-poly limpio + export **GLB Godot-first**. https://www.3daistudio.com/UseCases/Godot · https://www.3daistudio.com/Tools/Remesh
- Meta 3D AssetGen es **research, no producto integrable hoy** — referencia tecnica, no usar en el flujo. https://ai.meta.com/research/publications/meta-3d-assetgen-text-to-mesh-generation-with-high-quality-geometry-texture-and-pbr-materials/

**Textura/PBR/2D.**
- **FLUX.2 Pro via API** — texturas tileables seamless 2048, materiales metal/piedra/tela; **comercial via API** (NO usar los pesos Dev = non-commercial). https://www.teamday.ai/blog/best-ai-image-models-2026
- **PixelLab** — pixel art con grid (16/32/64) y sprite sheets consistentes. https://pixelglow.lol/blog/best-ai-pixel-art-generator
- Midjourney V7 mejor estilo artistico pero **sin API** -> descartado para pipeline automatizado.

**Retopo / LOD (el puente AI-raw -> game-ready).** Quad Remesher (https://github.com/QuadRemesher), InstaLOD (https://instalod.com/), Tripo/3D-AI-Studio remesh. Target real-time: personajes ~5k-20k quads, LODs con topologia optimizada.

**Rigging/animacion.** Tripo (1-clic universal), Meshy Animate (<30s presets), AccuRIG 2, DeepMotion (video->mocap), Rigify, Mixamo (humanoide estandar, estancado). https://www.tripo3d.ai/content/en/guide/the-best-auto-rig-mixamo-alternative-tools

**Audio.**
- **SFX**: ElevenLabs SFX API (loop param para ambientes). https://elevenlabs.io/sound-effects · https://elevenlabs.io/blog/how-we-created-a-soundboard-using-elevenlabs-sfx-api
- **Musica**: **ElevenLabs Music v2** (may-2026, commercial clearance, datos licenciados) y **Stable Audio 3.0** (open weights, datos licenciados) **por delante de Suno** — Suno v5 esta siendo deprecado en 2026 y arrastra riesgo de copyrightability; usarlo solo con verificacion de terminos por proyecto. https://decrypt.co/369237/elevenlabs-stability-ai-new-music-models-suno
- **Voz NPC (corregido)**: el default debe ser **voz sintetica NO clonada de persona real**. Chatterbox/Voicebox (codigo MIT) **no garantizan** que los pesos o el clonado esten libres de restricciones ni de derechos de imagen de voz; el claim "65.3% vs 24.5% ElevenLabs" es marketing, **no benchmark independiente**. Subtitulos para toda voz NPC (accesibilidad PONYTAIL, no negociable).

**Backends MCP.**
- **Summer Engine** — MCP vivo `:6550`, **44 tools `summer_*` (confirmado)** incluyendo `summer_generate_3d/image/audio` **y `summer_generate_video`**; lee `.summer/GameSoul.md`. https://github.com/SummerEngine/summer-engine-agent · https://www.summerengine.com/blog/best-ai-tools-for-godot
- **GDAI MCP** (3ddelano) — escenas/nodos/scripts/recursos/errores, **NO genera assets**. https://github.com/3ddelano/gdai-mcp-plugin-godot
- **Godot AI** (hi-godot HTTP) — materials/particles/audio ops, no genera mallas. https://github.com/hi-godot/godot-ai

**Import Godot 4.7 (lo que el lazo verifica).** GLB = formato canonico (malla+materiales+texturas en un fichero). https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- Bug de **tangentes/escala** real y vivo (#71221): scale enorme/negativo o malla sin tangentes con normal map -> iluminacion "muerta". https://github.com/godotengine/godot/issues/71221
- Materiales metallic/roughness se pueden perder en Blender->GLB. https://gamineai.com/help/blender-4-2-glb-export-loses-materials-godot-4-metallic-roughness-import-fix
- Colision solo por **hints de sufijo** `-col/-convcol/-colonly`. https://godotengine.org/asset-library/asset/4428

### Simbiosis con el flujo de la skill (pasos accionables)

El pipeline se modela como **una secuencia lineal de 6 pasos con gates** — **NO un "DAG" ni un orquestador propio** (eso seria arquitectura ad-hoc anti-PONYTAIL; no hay paralelismo ni ramas reales que lo justifiquen):

`intent -> generate -> optimize(retopo/LOD) -> import(GLB) -> validate(headless) -> wire(scene)`

1. **Dispatcher (SKILL.md):** ruta `assets|arte|audio|modelo|textura|sprite|rig|anim -> references/31_asset_pipeline.md`. Enrutar por tipo de asset a la herramienta canonica.
2. **Contrato de capacidades (ref 30):** bits `gen_3d/gen_image/gen_audio/import_glb/live_scene`. **DEFAULT = pipeline neutro** (herramienta externa + import nativo de Godot). **Summer es acelerador OPCIONAL si `:6550` esta vivo, NO la rama preferida** — evita lock-in a un fork propietario y la promesa "sin creditos" (claim del vendedor, no auditado). Si el backend no genera mallas (GDAI/Godot-AI), Claude genera externo y deja que **el editor importe** (ver paso 4); nunca pedir generacion a un backend que no la tiene (fallo silencioso).
3. **Coherencia de arte:** con Summer, leer `.summer/GameSoul.md`. Sin Summer, mantener `art_bible.md` equivalente (paleta, estilo, polycount target, formato, naming). Es el contrato cross-tool contra estilos dispares.
4. **Import (corregido):** **NO fabricar el `.import` a mano** — lo genera el editor. Ruta correcta: copiar GLB a `res://` sobre un proyecto **ya inicializado**, ejecutar `godot --headless --import`, y **LEER** el resultado (`.import` + `.godot/imported/`). Documentar que el import headless sin GPU puede comportarse distinto en texturas/lightmap. `scripts/import_glb.sh` envuelve esto y captura errores a `errors.json`.
5. **Tangentes para AI-gen (corregido):** el usuario **no controla** el export de Meshy/Tripo; el GLB llega ya hecho, a menudo **sin tangentes**. Mitigacion real: activar **regeneracion de tangentes en el importador de Godot**, o pasar por la **ruta Blender-in-the-middle** (canonica para 3D production-grade): `AI-gen -> Blender (apply transforms, regen tangents, fix UVs, decimate/quad-remesh) -> GLB -> Godot`.
6. **Validate (gates corregidos):** carga sin error; **PBR CONDICIONAL** (si hay normal map -> exige tangentes; **NO** exigir "4 canales siempre" — emisivos, unlit, flat-shaded y terreno con vertex color son legitimos sin normal/metalness); polycount <= target del art_bible; escala ~1.0 y no negativa; AABB razonable; audio loop flag; **licencia + copyrightability + disclosure registrados** por asset.
7. **Wire (godot-scripter):** instanciar nativo — `PackedScene`/`MeshInstance3D` desde GLB, `AnimationPlayer`/`AnimationTree` + `AnimationLibrary`, `ORMMaterial3D`/`StandardMaterial3D`, `AudioStreamPlayer3D` + loop nativo.

### Como se adapta Claude (decisiones, tools, verificacion, ponytail)

**Arbol de decision (firme, corregido):**
- **Backend:** sonda `:6550`. Vivo -> Summer es opcion (acelera, evita import manual) PERO el default sigue siendo el pipeline neutro por portabilidad. No vivo -> herramienta externa + import por editor headless.
- **Tipo -> herramienta:** mesh iterativo -> **Tripo**; mesh PBR pulido -> **Meshy**; export Godot-first -> **3D AI Studio**; textura tileable -> **FLUX.2 Pro API**; pixel art -> **PixelLab**; retopo/LOD -> **Quad Remesher/InstaLOD**; rig/anim -> **Tripo/Meshy Animate** -> retarget humanoide; SFX -> **ElevenLabs SFX API**; musica -> **ElevenLabs Music v2 / Stable Audio 3.0**; voz NPC -> **sintetica no clonada** + subtitulos.
- **Loop (corregido, clave anti-coste):** **HUMAN-GATE por defecto** — generar 1 candidato -> validar -> presentar al humano para aceptar/rechazar (como Tripo esta disenado). **Auto-fix solo para fallos deterministas y baratos**: falta loop flag de audio, escala != 1, regenerar tangentes en import. **NUNCA auto-regenerar** una malla por "polycount alto" o "no me gusta" — es no determinista, consume creditos del usuario y la herramienta no garantiza el criterio.
- **PONYTAIL aplicado (lo mejor del Architect, conservado):** reusar nodos/Resources nativos. GLB -> `PackedScene`/`MeshInstance3D`, no loader propio. Material -> `StandardMaterial3D`/`ORMMaterial3D`, no shader custom salvo necesidad real. Animacion -> `AnimationPlayer`/`AnimationTree` + `AnimationLibrary`, no FSM ad-hoc. Audio -> `AudioStreamPlayer3D` + `AudioStreamOggVorbis` loop nativo. Colision/terreno -> import hints (`-col`) antes que codigo.

### Acciones concretas

- Validar version del binario Godot en `verify_loop.sh`; target 4.7, flag compat 4.6.
- Antes de import: si polycount > target del art_bible -> retopo (Quad Remesher / Tripo / Blender).
- Para todo 3D que no sea prop desechable: pasar por **Blender-in-the-middle** (apply transforms, regen tangents, fix UVs).
- En import: activar regeneracion de tangentes para GLBs AI-gen sin tangentes.
- Registrar por cada asset, en un manifest: herramienta, plan/licencia, **grado de autoria humana**, y disclosure requerido.
- Bloquear build comercial solo cuando la licencia lo exige de verdad (Tripo free, FLUX Dev weights), **no** por Meshy free (que es comercial con atribucion): registrar la atribucion en su lugar.

### Que anadir/cambiar en la skill

**Nuevos:** `references/31_asset_pipeline.md` (secuencia de 6 pasos con gates, tabla tipo->herramienta->formato->gate, ruta Blender-in-the-middle, import hints, regen de tangentes); `references/32_asset_licensing.md` (TRES ejes: licencia comercial / copyrightability / disclosure); `scripts/validate_asset.gd` (gates corregidos: PBR condicional, escala, tangentes-si-normal, polycount, audio loop, licencia); `scripts/import_glb.sh` (reimport por editor + leer resultado, no fabricar `.import`).

**Cambios:** `SKILL.md` dispatcher + version-target explicita; `references/30_*` (bits de capacidad, default neutro, Summer opcional, human-gate en vez de lazo de convergencia de mallas); `references/29_summer_engine.md` (`summer_generate_3d/image/audio/video`, GameSoul.md, "sin creditos" como claim del vendedor); `verify_loop.sh`/`validate_all.gd` (invocar `validate_asset.gd`, chequear version); `hooks/` PostToolUse (disparar al ver `.glb/.png/.ogg/.wav/.import`); `commands/` (`/godot-asset`, `--assets` en `/godot-verify`, ganchar en `/godot-flow`); `agents/godot-reviewer` (budget de assets + gate copyrightability/disclosure); `agents/godot-scripter` (wiring nativo + subtitulos NPC).

### Pitfalls y limite lazy-not-negligent

**Pitfalls tecnicos:** AI-raw no production-ready (retopo obligatorio); tangentes/escala (#71221, peor en AI-gen sin tangentes); materiales perdidos Blender->GLB; colision solo por hints de sufijo; loop flag de audio olvidado; estilos dispares sin art_bible/GameSoul.

**Pitfalls legales (corregidos, el hueco central del Architect):**
- **Copyrightability — el riesgo legal mayor.** En EEUU un asset **100% IA no tiene copyright**: SCOTUS denego cert el **2-mar-2026**, dejando en pie el requisito de autoria humana. Disclosure NO es proteccion — marcar "AI-generated" es justo lo que confirma que no hay autoria. Para assets clave (protagonista, key art) recomendar **edicion/retopo manual documentado** para defender autoria. https://www.copyright.gov/ai/ · https://www.morganlewis.com/pubs/2026/03/us-supreme-court-declines-to-consider-whether-ai-alone-can-create-copyrighted-works
- **Licencia de Meshy (corregido):** Meshy **free = uso comercial CON atribucion** (CC BY 4.0, ej. "Model created with Meshy – CC BY 4.0 License"), **no** un bloqueo comercial. Tripo free = **NO comercial** (Pro+ si). FLUX.2 Pro **via API = comercial** (Dev weights = non-commercial). Un gate que clasifique mal esto genera falsos positivos (rompe el flujo) o infraccion (no registra atribucion). https://help.meshy.ai/en/articles/9992001-can-i-use-my-generated-assets-for-commercial-projects
- **Disclosure de plataforma:** Steam (reglas ene-2026) y **EU AI Act (aplicable ago-2026)** exigen declarar contenido IA.

**Limite lazy-not-negligent (firme).** *Lazy OK:* reusar nodos/Resources nativos, generar en vez de modelar a mano, batch LODs, usar Summer si esta vivo. *NEGLIGENTE (prohibido):* (1) saltarse el gate de validacion headless; (2) saltarse el gate legal de **tres ejes** (licencia + copyrightability + disclosure); (3) importar sin chequear colision/escala "porque carga"; (4) clonar voces reales sin consentimiento; (5) omitir subtitulos de voz NPC; (6) **auto-regenerar mallas en lazo** quemando creditos del usuario contra un criterio que la herramienta no garantiza.

### Fuentes (URLs reales)
- https://godotengine.org/download/archive/4.7-stable/
- https://docs.godotengine.org/en/stable/about/release_policy.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- https://github.com/godotengine/godot/issues/71221
- https://gamineai.com/help/blender-4-2-glb-export-loses-materials-godot-4-metallic-roughness-import-fix
- https://godotengine.org/asset-library/asset/4428
- https://www.meshy.ai/ · https://www.meshy.ai/features/text-to-3d · https://www.meshy.ai/features/ai-animation-generator
- https://help.meshy.ai/en/articles/9992001-can-i-use-my-generated-assets-for-commercial-projects
- https://www.tripo3d.ai/features/ai-auto-rigging · https://studio.tripo3d.ai/workspace/retopology/ · https://www.tripo3d.ai/content/en/guide/the-best-auto-rig-mixamo-alternative-tools
- https://www.3daistudio.com/UseCases/Godot · https://www.3daistudio.com/Tools/Remesh
- https://www.teamday.ai/blog/best-ai-image-models-2026 · https://pixelglow.lol/blog/best-ai-pixel-art-generator
- https://instalod.com/ · https://github.com/QuadRemesher
- https://elevenlabs.io/sound-effects · https://elevenlabs.io/blog/how-we-created-a-soundboard-using-elevenlabs-sfx-api · https://decrypt.co/369237/elevenlabs-stability-ai-new-music-models-suno
- https://github.com/SummerEngine/summer-engine-agent · https://www.summerengine.com/blog/best-ai-tools-for-godot · https://github.com/3ddelano/gdai-mcp-plugin-godot · https://github.com/hi-godot/godot-ai
- https://www.copyright.gov/ai/ · https://www.morganlewis.com/pubs/2026/03/us-supreme-court-declines-to-consider-whether-ai-alone-can-create-copyrighted-works
- https://ai.meta.com/research/publications/meta-3d-assetgen-text-to-mesh-generation-with-high-quality-geometry-texture-and-pbr-materials/
