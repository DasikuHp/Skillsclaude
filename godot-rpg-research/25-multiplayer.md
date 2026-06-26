## Adjudicación entre las 3 lentes

Las tres lentes (docs / veterano / escéptico) coincidieron en lo esencial: stack de 4 piezas, listen-server para co-op, autoridad determinista por nombre de nodo, construir el `SceneReplicationConfig` por código, no sincronizar cosméticos/RNG, y YAGNI. Las discrepancias resueltas:

1. **`@rpc` transfer_mode default — ¿unreliable o reliable?** Docs decía "unreliable" (default GDScript). Veterano y escéptico señalaron que en **C#** el default es `Reliable`. **Verificado vía WebSearch (GH-docs#8874):** ambos tienen razón — es una inconsistencia documentada real: GDScript default = `unreliable`, C# `[Rpc]` default = `Reliable`. Lo mantengo explícito como pitfall porque una IA que asume paridad sincroniza mal.

2. **Default completo de `@rpc` sin args.** Veterano afirmó `@rpc == @rpc("authority", "call_remote", "unreliable", 0)`. Coincide con docs (mode default authority, sync default call_remote, transfer default unreliable). Adjudicado: correcto, conservado implícitamente.

3. **Interpolación: ¿sincronizar `position` directamente?** Docs sugería `replication_interval = 0.0` + CharacterBody local. Escéptico y veterano fueron más precisos: el Synchronizer sobreescribe el valor crudo y NO interpola (proposal GH-7280), causando jitter; el patrón robusto es sincronizar una **variable espejo** (`sync_position`) y lerpear. Adjudico a favor del patrón espejo (más anti-stuck y verificable contra la proposal abierta), mencionando el lerp explícito.

4. **`SceneReplicationConfig` por código — ¿funciona?** Docs citó GH-65725 (añadir/quitar props por código no actualiza la sync), lo que parecía contradecir al escéptico que recomienda construirlo por código. Resolución: NO se contradicen — el bug es sobre **mutar** un config existente; crear un `SceneReplicationConfig.new()` entero y asignarlo sí funciona y además esquiva GH-84793 (editor no guarda config de escena instanciada). Adjudicado: construir config nuevo por código es el camino correcto para IA ciega; conservo ambas citas.

5. **Estado de addons Steam (archivado/pausado).** Solo el veterano dio fechas concretas (GodotSteam/MultiplayerPeer archivado 2025-11-13; expressobits pausado). No pude reverificar las fechas exactas por búsqueda directa. Las degradé a "señal de no empezar dependencia nueva ahí, confirma antes de adoptar" en vez de afirmarlas como hecho. netfox SÍ verificado como addon activo y recomendado (WebSearch).

6. **`rpc_id(0)` vs `rpc_id(1)`.** Docs tenía un comentario confuso en el snippet C# (`RpcId(0, ...) // broadcast? NO`). Veterano/escéptico lo aclararon: `0` = broadcast a todos menos a ti; `1` = solo server; `Rpc()` = broadcast en C#. Adjudicado con la versión clara.

7. **Nota de verificación del escéptico:** descartó el rumor "4.5 reworked replication defaults" por no estar confirmado. No lo incluí en la sección — correcto descartarlo.

Descarté: el comentario erróneo `RpcId(0,...)` del dossier docs, y cualquier afirmación de cambio de firma de red en 4.6 (las tres lentes confirman que no hubo refactor).

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html
- https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html
- https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html
- https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html
- https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html
- https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_dedicated_servers.html
- https://godotengine.org/article/multiplayer-changes-godot-4-0-report-2/
- https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/
- https://github.com/godotengine/godot-docs/issues/8874
- https://github.com/godotengine/godot/issues/66224
- https://github.com/godotengine/godot/issues/68750
- https://github.com/godotengine/godot/issues/75067
- https://github.com/godotengine/godot/issues/75884
- https://github.com/godotengine/godot/issues/76894
- https://github.com/godotengine/godot/issues/78692
- https://github.com/godotengine/godot/issues/84149
- https://github.com/godotengine/godot/issues/84793
- https://github.com/godotengine/godot/issues/89981
- https://github.com/godotengine/godot/issues/98588
- https://github.com/godotengine/godot/issues/65725
- https://github.com/godotengine/godot-docs/issues/11205
- https://github.com/godotengine/godot-proposals/issues/7280
- https://github.com/foxssake/netfox
- https://foxssake.github.io/netfox/latest/
- https://forum.godotengine.org/t/how-to-fix-trying-to-call-an-rpc-via-a-multiplayer-peer-which-is-not-connected/37037
- https://forum.godotengine.org/t/is-it-possible-to-achieve-network-interpolation-with-multiplayer-synchronizer/48514
- https://gist.github.com/Meshiest/1274c6e2e68960a409698cf75326d4f6
