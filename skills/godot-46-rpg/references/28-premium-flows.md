# 28. Flujos premium — orquestar el MCP en acciones caras y útiles

Las tools del MCP (reference 27) son **átomos** (`node_create`, `signal_manage`…).
El valor premium está en **encadenarlas en flujos** que hacen en un gesto lo que a
mano son 10-20 pasos frágiles, y que **cierran el lazo viendo el resultado**
(`project_run` + `editor_screenshot` + `logs_read`). Cada flujo respeta el veredicto
ponytail: compone nodos/Resources nativos, no construye arquitectura propia.

> Estos flujos son **orquestación a nivel de skill** sobre las tools EXISTENTES del
> addon — no requieren tocar el servidor. (Añadir tools nuevas al engine sí exige el
> repo Python del MCP; ver "Roadmap" al final.)

## Patrón de un flujo

1. **Plan** (qué nodos/recursos, qué veredicto aplica). 2. **Construir** (tools `node_*`/`scene_*`/`resource_*`). 3. **Cablear** (`signal_manage`, `node_set_property`). 4. **Verificar viendo** (`project_run`/`game_manage` + `editor_screenshot` + `logs_read`). 5. **Auto-fix** (mapea el error con `hooks/errors.json` → `script_patch` → repite).

## Catálogo de flujos premium

### F1 · `rpg_scaffold` — esqueleto jugable en un gesto
`scripts/new_project.sh` → `scene_manage`(main) → `node_create` Player(CharacterBody3D)+SpringArm3D+Camera3D → `script_attach`(player_controller) → `autoload_manage`(Settings/Save/EventBus) → `input_map_manage`(move_*) → `project_run` + `editor_screenshot`. **Sale: un personaje que se mueve.** Ref: 1, 10, 21.

### F2 · `enemy_combat_wire` — enemigo de combate totalmente cableado (el más caro)
`node_create` Enemy + Hitbox/Hurtbox(Area3D+CollisionShape3D) → `node_set_property`(collision_layer/mask correctos) → `resource_manage`(DamageInfo.tres) → `signal_manage`(hurtbox.area_entered → HealthComponent.take_damage) → `animation_create`(attack con Call Method Track enable/disable hitbox) → `node_create` NavigationAgent3D + `script_attach`(FSM patrol/chase/attack) → `project_run`+`logs_read`. **Toca 7 dominios; entrega un enemigo que persigue, ataca y recibe daño.** Ref: 3, 7, 2.

### F3 · `hud_bind` — HUD reactivo sin acoplar
`ui_manage`(CanvasLayer + TextureProgressBar vida/maná) → `theme_manage`(estilo) → `signal_manage`(Stats.health_changed → barra) . **La UI escucha por señal; cambias datos sin tocar UI.** Ref: 9, 4.

### F4 · `nav_bake_patrol` — navegación lista
`node_create` NavigationRegion3D → `node_manage`(bake navmesh) → `node_create` agentes + `node_set_property`(radius/avoidance) → `script_attach`(patrulla). Verifica con `game_manage`(visible navigation) + `editor_screenshot`. Ref: 7.

### F5 · `material_fx_pack` — feedback de impacto
`material_manage`(hit-flash vía instance uniform / Stencil outline) + `particle_manage`(GPUParticles3D one-shot de impacto) + `node_create` Decal(sangre) → `signal_manage`(combate → disparar VFX). Ref: 11, 25, 3.

### F6 · `dungeon_gen` — nivel procedural
`batch_execute`(secuencia de set_cell_item en GridMap) o `script_create`(generador) → `scene_save`. Verifica con `project_run`+`editor_screenshot` cenital. Ref: 24, 10.

### F7 · `playtest_capture` — verificación VISUAL del comportamiento
`project_run` → bucle de `editor_screenshot` cada N frames + `logs_read` → reporte "qué se ve + qué errores". Es la verificación que un humano haría mirando la pantalla, automatizada. Ref: 14, 16.

### F8 · `verify_and_fix` — lazo cerrado con auto-reparación
`test_run` (o `validate_all.gd`) → si hay error, casa el mensaje literal contra
`hooks/errors.json` (causa+fix+reference) → `script_patch` aplica el fix → re-`test_run`.
Repite hasta verde o hasta que el fallo sea real y fuera de alcance. **Este es el
corazón anti-stuck: el MCP no solo detecta, repara y re-verifica.** Ref: 13, 16.

## Cómo invocarlos
- Comando `/godot-flow <Fn>` (ver `commands/godot-flow.md`) describe el flujo y deja que
  Claude ejecute las tools en orden, verificando entre pasos.
- Sin editor vivo: degradan a `scripts/` (F1→`new_project.sh`, F7/F8→`verify_loop.sh`).

## Reglas premium (lazy-not-negligent en flujos)
- **Verifica entre pasos**, no solo al final (un `node_create` fallido envenena los siguientes).
- **Idempotencia**: `node_find` antes de `node_create` para no duplicar.
- **Nunca** recortes validación de layers/máscaras en combate ni de rutas en save: ahí los bugs son invisibles.
- Cada flujo termina con un **veredicto**: qué tools compuso, qué NO se construyó a mano, `net` de pasos manuales ahorrados.

## Roadmap (requiere el repo Python del MCP, fuera de este repo)
Tools NUEVAS de engine que serían "premium" reales (definir en `src/godot_ai/tools/domains.py`
+ handler GDScript aquí): `lod_setup`, `occluder_bake`, `lightmap_bake`, `gridmap_paint`,
`skeleton_retarget`, `shader_from_preset`, `profile_capture` (Tracy/Perfetto), `export_preset`.
Para implementarlas hay que traer el repo upstream a scope (hoy solo está el addon).
