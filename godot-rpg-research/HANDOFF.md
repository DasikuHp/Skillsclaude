# Traspaso — Skill definitiva de Godot 4.6 para RPG 3D libre

Estado del trabajo y prompt para continuar en una **nueva sesión apuntando a
`DasikuHp/Skillsclaude`**. La sesión actual estaba limitada (scope) a
`DasikuHp/webmontec`, por eso no se pudo pushear a Skillsclaude.

## Qué hay hecho (en la rama `claude/godot-4.6-rpg-skill-3ugthu` de webmontec)

- `skillgodot4.6.md` — skill base en formato ponytail (frontmatter + secciones):
  escalera de decisión, features 4.6 (Jolt, IKModifier3D, diccionarios tipados,
  @abstract, SSR/LOD), GDScript vs C#, y patrones de RPG (locomoción,
  inventario, estados, guardado, navegación, combate). Con fuentes.
- `godot-rpg-examples/` — scripts `.gd` reales y tipados + README de cableado:
  `player.gd`, `item_data.gd`, `inventory.gd`, `stats.gd`, `state.gd`,
  `state_machine.gd`, `states/idle_state.gd`, `states/run_state.gd`,
  `save_system.gd`.
- `README-skills.md` — índice de la colección de skills.
- `godot-rpg-research/` — investigación profunda ya verificada:
  - `00-rendering.md` — renderers (Forward+/Mobile/Compatibility), GI
    (SDFGI/VoxelGI/LightmapGI), SSR Hi-Z 4.6, LOD/occlusion, iluminación,
    materiales/shaders, VFX (Decal/GPUParticles3D/MultiMesh), presets por
    plataforma.
  - `01-release-editor.md` — release 4.6, suite IK completa (TwoBoneIK3D,
    SplineIK3D, FABRIK3D, CCDIK3D, JacobianIK3D, ChainIK3D, IterateIK3D),
    Jolt, breaking changes 4.5→4.6, mantenimiento 4.6.1–4.6.3, navegación,
    profiling (Tracy/Perfetto), nodos con ID único.

## Qué falta (la investigación profunda que quedó a medias)

Había un workflow de ~110 agentes (10 investigadores × 10 dominios) que se
**detuvo a petición del usuario**. Faltan por investigar y sintetizar a fondo
(StackOverflow, GitHub, foros, docs, addons) estos 10 dominios de gameplay,
con el MEJOR código en GDScript **y** C#:

1. Controlador de personaje + cámara 3ª persona (CharacterBody3D, SpringArm3D, root motion)
2. Animación, AnimationTree e IK (IKModifier3D: foot placement, look-at; blend spaces; retargeting)
3. Combate y daño (Area3D hit/hurtboxes, fórmulas, estados, proyectiles/hechizos, i-frames)
4. Stats, niveles y progresión (Resources, curvas XP, árboles de habilidades, modificadores de equipo)
5. Inventario, items y equipo (Resources, stacking, slots, drag-and-drop, crafteo, loot tables)
6. Diálogo y quests (árboles ramificados, condiciones, tracking de objetivos, journal)
7. IA enemiga y navegación (NavigationAgent3D, avoidance, navmesh, FSM vs behavior trees, aggro/patrol/chase)
8. Guardado y persistencia (JSON vs binario vs ConfigFile vs ResourceSaver, guardar Resources por id, slots, versionado)
9. UI, HUD y menús (Control/Containers/anchors, Theme, barras, menús, UI de inventario/diálogo, navegación con mando)
10. Gestión de mundo/niveles y arquitectura (transición de escenas, GridMap, streaming, autoloads, bus de señales, composición vs herencia, threading/WorkerThreadPool, decisión GDScript vs C#)

## Correcciones/notas a aplicar al ensamblar

- `@abstract` llegó en **4.5**, NO en 4.6 (no atribuirlo a 4.6).
- Suite IK 4.6: nombrar las clases reales (TwoBoneIK3D, SplineIK3D, FABRIK3D,
  CCDIK3D, JacobianIK3D, ChainIK3D, IterateIK3D) bajo `IKModifier3D`/`SkeletonModifier3D`.
- Migración 4.5→4.6: glow más brillante (re-tunear), GLSL `view_matrix` mat4→mat3x4,
  `AnimationPlayer` String→StringName (recompilar C#), Android source-set, `ssr_depth_tolerance` 0.2→0.5.
- D3D12 es el driver por defecto en Windows para proyectos nuevos; Jolt por defecto solo en proyectos nuevos.

---

## PROMPT PARA LA NUEVA SESIÓN (cópialo tal cual)

> Estoy creando una **skill definitiva de Godot 4.6 para hacer un RPG 3D libre
> (open-source)**, en formato **ponytail** (frontmatter `name`/`description`
> con frases-gatillo + cuerpo markdown; filosofía "el mejor código es el que no
> escribes": reusar nodos y Resources nativos del motor antes que escribir
> arquitectura propia). Debe cubrir **GDScript y C# (.NET 8)** con código real,
> tipado e idiomático, pitfalls, y fuentes citadas.
>
> Quiero que sea meticulosa y exhaustiva. Investiga en internet (docs oficiales
> de Godot 4.6, StackOverflow, gamedev.stackexchange, GitHub —proyectos RPG
> open-source reales—, foros de Godot, Reddit r/godot, GDQuest, y el Asset
> Library para addons) el **mejor código posible** para cada uno de estos 10
> dominios de RPG, y escribe una sección por dominio: (1) controlador de
> personaje + cámara 3ª persona, (2) animación/AnimationTree/IK con
> IKModifier3D, (3) combate y daño, (4) stats/niveles/progresión, (5)
> inventario/items/equipo, (6) diálogo y quests, (7) IA enemiga y navegación
> con NavigationAgent3D, (8) guardado/persistencia, (9) UI/HUD/menús, (10)
> gestión de mundo/niveles y arquitectura del proyecto. Para cada dominio: el
> enfoque nativo recomendado, código GDScript Y C#, nodos/clases 4.6 exactos,
> pitfalls, "addon vs construirlo", y un veredicto ponytail. Si quieres
> paralelizar, usa un workflow con ~10 agentes por dominio.
>
> Datos de 4.6 ya verificados que debes incorporar: Jolt es el motor de física
> 3D por defecto en proyectos nuevos; la suite IK completa es TwoBoneIK3D,
> SplineIK3D, FABRIK3D, CCDIK3D, JacobianIK3D, ChainIK3D, IterateIK3D bajo
> IKModifier3D/SkeletonModifier3D; SSR reescrito (Hi-Z, half-res por defecto);
> diccionarios tipados `Dictionary[K, V]`; `@abstract` existe desde 4.5 (no es
> de 4.6); renderers Forward+/Mobile/Compatibility (web=Compatibility);
> D3D12 driver por defecto en Windows para proyectos nuevos. Breaking changes
> 4.5→4.6 a mencionar: glow más brillante, GLSL view_matrix mat4→mat3x4,
> AnimationPlayer String→StringName (recompilar C#), ssr_depth_tolerance 0.2→0.5.
>
> El resultado final: crea en este repo (`DasikuHp/Skillsclaude`) el archivo
> `skillgodot4.6.md` (la skill definitiva ensamblada), una carpeta
> `godot-rpg-examples/` con scripts `.gd` ejecutables por cada sistema, una
> carpeta `godot-rpg-research/` con las notas de investigación, y un
> `README.md` índice. Commitea y pushea todo a este repo. NO crees un pull
> request salvo que te lo pida.
>
> (Tengo trabajo previo de otra sesión —skill base, ejemplos y la investigación
> de rendering + release/editor 4.6— que te puedo pegar si lo necesitas; pídemelo
> y lo aporto, o regenéralo desde cero si prefieres.)
