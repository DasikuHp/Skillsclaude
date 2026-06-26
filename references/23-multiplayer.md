## 23. Multiplayer y co-op

Godot 4.6 trae el stack *high-level multiplayer* sin cambios de firma respecto a 4.3/4.4/4.5 (no hubo refactor de red), así que las páginas `/en/stable/` y `/en/4.6/` son canónicas. El reto real para una IA que **no ve el editor** es que ~70% del setup multiplayer vive en el inspector (replication config, spawn path, lista de escenas spawneables) y **falla en silencio** si lo dejas vacío. Toda esta sección prioriza construir esa configuración **por código**, que es lo que una IA ciega sí puede hacer de forma reproducible.

### Enfoque nativo recomendado

Cuatro piezas, y mezclarlas es el bug #1:

| Pieza | Clase | Rol mental |
|---|---|---|
| Transporte | `ENetMultiplayerPeer` | "el cable" (UDP fiable/no-fiable) |
| API | `MultiplayerAPI` / `SceneMultiplayer` (default) | enruta RPCs, emite señales de conexión |
| Spawn | `MultiplayerSpawner` | **qué nodos existen** (authority -> peers) |
| Sync | `MultiplayerSynchronizer` + `SceneReplicationConfig` | **qué valores tienen** esos nodos |
| Eventos | `@rpc` / `[Rpc]` | eventos puntuales (golpe, abrir cofre, chat) |

Regla: **Spawner = qué nodos; Synchronizer = qué valores; RPC = eventos.** No muevas al jugador cada frame por RPC — eso es Synchronizer. Nunca cubras la **misma** propiedad por RPC *y* Synchronizer a la vez (conflicto de escritura).

Arquitectura para un RPG co-op (las 3 lentes coinciden): **listen-server / server-authoritative ligero**. Uno hostea (server + jugador, peer id `1`), el resto son clientes. El cliente envía *intención* (input) por `@rpc("any_peer")`; el server valida y empuja el estado (posición/hp) por Synchronizer. P2P puro (cada peer autoridad de su propio personaje, sin árbitro de mundo) sirve para co-op casual entre amigos, pero pierdes árbitro de enemigos/loot/economía. Para un RPG con enemigos: **server autoritario del mundo, peer-authority solo del movimiento de su jugador** (vía un nodo `Input` hijo).

**Patrón de autoridad determinista (clave anti-desync).** El engine empareja nodos remotos por `path + name + authority`. Si dejas que Godot auto-nombre (`@Player@2`), los nombres divergen entre peers y el sync apunta a fantasmas. Solución universal: el **nombre del nodo ES el peer id**, y la autoridad se deriva localmente — nunca se anuncia por RPC asíncrono.

```gdscript
func _enter_tree() -> void:
    set_multiplayer_authority(name.to_int())  # determinista, idéntico en todos los peers
```

Asigna autoridad en `_enter_tree()` o dentro de `spawn_function`, **nunca en `_ready()`** (rompe el sync, ver pitfalls). Pero ojo: en `_enter_tree` el peer aún puede no estar configurado, así que pasa el `peer_id` como **dato del spawn**, no lo leas del entorno.

**Construir el `SceneReplicationConfig` por código** (lo que evita el atasco del inspector). El `NodePath` es `"NodoRelativo:propiedad"` — `".:position"`, no `"position"` a secas, o no sincroniza y no avisa:

```gdscript
func _setup_sync() -> void:
    var cfg := SceneReplicationConfig.new()
    var np := NodePath(".:sync_position")  # ver interpolación abajo
    cfg.add_property(np)
    cfg.property_set_spawn(np, true)       # incluida en el spawn inicial
    cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
    var hp := NodePath(".:health")
    cfg.add_property(hp)
    cfg.property_set_replication_mode(hp, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
    $MultiplayerSynchronizer.replication_config = cfg
    $MultiplayerSynchronizer.replication_interval = 0.05  # 20 Hz; 0.0 = cada frame (caro)
```

Modos: `REPLICATION_MODE_ALWAYS` (cada `replication_interval`), `REPLICATION_MODE_ON_CHANGE` (cada `delta_interval`, solo al cambiar), `REPLICATION_MODE_NEVER`. Construir el config por código además **esquiva** el bug del editor donde editar el config de una escena instanciada no se guarda (GH-84793) y la limitación de que añadir/quitar propiedades por código sobre un config existente no siempre re-arma la sync (GH-65725) — por eso se crea un config nuevo entero.

**Spawn 100% por código con `spawn_function`** (no requiere poblar la lista `_spawnable_scenes` del inspector):

```gdscript
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
    spawner.spawn_path = ^"../Players"      # anchor explícito; mismo nodo en todos los peers
    spawner.spawn_function = _spawn_player

func _on_peer_connected(id: int) -> void:
    if multiplayer.is_server():             # SOLO el server spawnea
        spawner.spawn(id)                    # 'id' viaja como 'data' a TODOS los peers

func _spawn_player(data: int) -> Node:       # corre en CADA peer
    var p := preload("res://player.tscn").instantiate()
    p.name = str(data)                       # nombre determinista -> autoridad en _enter_tree
    return p                                  # NO hagas add_child: el spawner lo añade
```

Regla de oro de `spawn_function`: el Node devuelto **NO debe estar ya en el árbol** (Godot lo añade bajo `spawn_path`). Si haces `add_child` tú -> doble-parent/duplicados.

**Separación input/estado** (server-authoritative real): el personaje es autoridad del server; un nodo hijo `InputSynchronizer` es autoridad del cliente. El cliente escribe input ahí, su Synchronizer lo manda al server, el server lo procesa y replica la posición resultante.

```gdscript
# InputSynchronizer.gd — autoridad = cliente dueño
extends MultiplayerSynchronizer
@export var move_dir := Vector2.ZERO

func _process(_delta: float) -> void:
    if is_multiplayer_authority():
        move_dir = Input.get_vector("left", "right", "up", "down")
```

**Seguridad:** toda `@rpc("any_peer")` es superficie de ataque. Siempre `var sender := multiplayer.get_remote_sender_id()` y valida que `sender` posee la acción (ownership, vivo, en rango). `get_remote_sender_id()` lo da el engine (no spoofeable desde cliente vanilla) — confía en el id, **nunca** en los argumentos. Para juego serio: `SceneMultiplayer.auth_callback` para autenticar peers. **Nunca** `allow_object_decoding = true` con datos no confiables (es RCE: ejecuta código deserializado).

### Pitfalls y mensajes de error literales

- **`RPC '...' is not allowed on node ... Mode is 'Authority', authority is '<id>'.`** / `Unable to get RPC config for the function "..."` (GH-66224): el método no tiene `@rpc`/`[Rpc]`, la anotación difiere entre peers, o un no-authority llamó una RPC `"authority"`. La config `@rpc` debe ser **idéntica** en el script que ambos peers cargan.
- **RPC silencioso dentro de señales del *peer*** (GH-68750): no puedes lanzar RPC dentro del handler `peer_connected` del `MultiplayerPeer`. Conéctate a `multiplayer.peer_connected` (señal de la **API**), no a `peer.peer_connected`. Síntoma: id válido en log, RPC descartado sin error.
- **`Node not found` / `Failed to get cached path` / `get_cached_object: ID not found in cache of peer.`** (GH-76894, GH-78692): nombres no deterministas (fix: `name = str(peer_id)`), o el `spawn_path`/`MultiplayerSpawner` no existe con path idéntico en el cliente (fix: carga la **misma** escena raíz en host y cliente; espera a que ambos tengan el árbol antes de RPC al nodo recién spawneado).
- **`The MultiplayerSynchronizer ... is unable to process the pending spawn since it has no network ID.`** (GH-75067): asignar autoridad en `_ready()` —y, según el timing del spawn, incluso en `_enter_tree()` (es justo el patrón que reporta GH-75067)— puede disparar el error "no network ID". El fix robusto es **derivar la autoridad del nombre determinista del nodo** que `spawn_function` fija (`p.name = str(data)`): `set_multiplayer_authority(name.to_int())` en `_enter_tree()` como sitio primario, y `spawn_function` como fallback garantizado (corre en cada peer con el nombre ya puesto).
- **`Trying to call an RPC via a multiplayer peer which is not connected.`**: RPC antes de `connected_to_server`. Fix: espera la señal, o comprueba `multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED`.
- **RPC "no hace nada" en el emisor** (GH-98588): falta `"call_local"`.
- **`@rpc` en método de no-Node** (GH-89981): solo funciona en métodos de clases derivadas de `Node`.
- **Spawns dobles:** la IA pone `_add_player()` en ambos lados. Hay que gatear con `if multiplayer.is_server():`, y el host debe llamar `_add_player(1)` manualmente porque `peer_connected` NO dispara para el id propio.
- **El orden de los nodos `MultiplayerSynchronizer` en el árbol importa** (GH-75884): si el sync de input va antes que el de posición, el primer frame puede fallar. Prefiere un único synchronizer por nodo lógico.
- **C# default de `TransferMode` = `Reliable`; GDScript default = `unreliable`** (GH-docs#8874, verificado). No asumas paridad. En C# se invoca con `Rpc(MethodName.Foo, args)` / `RpcId(1, MethodName.Foo, args)` usando el `StringName` **generado** `MethodName.X`, **no** un literal ni `.rpc()`. El bug `Nonexisting function 'rpc' in base 'Callable'` (GH-84149) viene de portar la sintaxis GDScript a C#.
- **`rpc_id(0, ...)`**: `0` = broadcast a todos menos a ti. Para hablar **solo** con el server usa `rpc_id(1, ...)`.
- **Stuttering / teletransporte:** el Synchronizer **sobreescribe** `position` con el valor crudo y **no interpola** nativamente (proposal GH-7280). Fix: no sincronices `position`; sincroniza una variable espejo y lerpea hacia ella en el no-autoritario:
  ```gdscript
  @export var sync_position: Vector3  # ESTA va en el replication_config
  func _physics_process(delta: float) -> void:
      if is_multiplayer_authority():
          sync_position = global_position
      else:
          global_position = global_position.lerp(sync_position, 1.0 - exp(-15.0 * delta))
  ```

### Cómo no quedarte atascado

Sin editor, el flujo de validación es por CLI (todos los flags verificados en los FACTS 4.6):

- `godot --headless --check-only --script res://net/server.gd` — chequeo de sintaxis.
- `godot --headless --import` — regenera recursos/UIDs tras editar `.tscn` a mano. **4.6 ya no escribe `load_steps`**; los recursos usan `uid://` + ficheros `.uid` (desde 4.4). Tras editar `.tscn` manualmente, corre **Project > Tools > Upgrade Project Files** o `--import`.
- `godot --headless --quit-after 600 --verbose` — corre N frames con log de red verboso: los descartes de RPC, `Mismatching configuration` y `Node not found` aparecen aquí.
- Dos instancias para probar: parsea args tras `--` (`if "--server" in OS.get_cmdline_user_args()`).
- **Dedicated server:** el export "dedicated server" fuerza `--headless` y setea el feature tag `dedicated_server` -> `if OS.has_feature("dedicated_server"):` arranca como server. Export: `godot --headless --export-release "Linux Server" build/server.x86_64`.
- **Debug ciego obligatorio:** loguea `multiplayer.get_unique_id()`, `get_multiplayer_authority()`, `is_multiplayer_authority()` en `_ready` de cada peer, y `get_remote_sender_id()` dentro de cada RPC `any_peer` — es tu única ventana sin GUI.
- **Web/navegador:** ENet (UDP) **no** funciona. `WebSocketMultiplayerPeer` está **built-in en todas las plataformas** (cero dependencias) — es el default recomendado para el target web de una IA ciega. `WebRTCMultiplayerPeer` solo es built-in en el export Web/HTML5; en escritorio requiere el **GDExtension de WebRTC** y además un **servidor de signaling** externo, así que no funciona out-of-the-box en un build de prueba de escritorio. **C# no corre en web** (renderer Compatibility, sin .NET) — si el target es navegador, usa GDScript y detéctalo antes de escribir nada.

**Qué NO sincronizar (lista negra):** nodos cosméticos (partículas, audio one-shot, animación de UI -> dispáralos por RPC `unreliable`); valores derivables (calcula `health_bar` desde `hp` local); RNG/loot (el **server** tira el dado y replica el resultado, o sincroniza la semilla — `randi()` por cliente = mundos divergentes); inventario completo cada tick (RPC `reliable` solo al dueño al cambiar); `velocity` + `position` a la vez si el cliente corre física (fight de integración). Posición = `unreliable_ordered`; eventos = `reliable`. Para mapas grandes: `public_visibility = false` + `set_visibility_for(peer_id, true)` (interest management; ahorra banda y previene wallhacks — pero solo lo respeta el peer **con autoridad** sobre el synchronizer, por eso enemigos deben ser autoritarios del server).

### Addon vs construirlo

- **Co-op casero / LAN / pocos jugadores: CONSTRUIR** con el stack nativo (ENet + Spawner + Synchronizer + `@rpc`). Suficiente, sin dependencias.
- **Predicción/rollback/reconciliación serias: [netfox](https://github.com/foxssake/netfox)** — addon open-source activo (2026), construye *sobre* la API nativa, no la reemplaza. Para un co-op PvE **no hace falta**; la interpolación casera del lerp basta.
- **Rollback determinista lockstep (fighting): godot-rollback-netcode (Snopek)** — overkill y mal ajuste para RPG (asume P2P + simulación determinista total).
- **Steam/lobbies/NAT-punch:** **GodotSteam** (ecosistema principal). El veterano alertó que el repo `GodotSteam/MultiplayerPeer` quedó archivado (2025-11) y `expressobits/steam-multiplayer-peer` pausado — trátalo como **señal de no empezar dependencia nueva ahí**, pero la fecha exacta no la pude reverificar; confirma el estado del repo antes de adoptarlo.

**Cuándo NO meter multiplayer (YAGNI):** si el RPG es single-player con "co-op algún día", **no** arquitectures todo server-authoritative ya. El multiplayer triplica la superficie de bugs (autoridad, spawn determinista, desync, debug ciego). Mete red cuando el loop core SP sea divertido y estable; pero diseña los sistemas (inventario, combate) como "comando -> aplicar estado" desde el día 1 para abaratar el retrofit.

**Veredicto ponytail:** No escribas netcode — orquesta nodos. `MultiplayerSpawner` + `MultiplayerSynchronizer` + `@rpc` cubren el 100% de un RPG co-op sin una línea de transporte custom. El único código que *sí* escribes a mano es lo que el editor te ocultaría a ti, la IA ciega: construir el `SceneReplicationConfig` por código, derivar autoridad del nombre del nodo, y el lerp de interpolación. Todo lo demás —rollback, predicción, sockets Steam— es addon (netfox/GodotSteam) que se enchufa al mismo stack, o es YAGNI hasta que el single-player esté content-complete.



> **Escalera ponytail:** rung 1→4 (¿lo necesitas? → MP nativo) · **net propio:** @rpc + MultiplayerSynchronizer; NO metas multiplayer sin un caso real. # TECHO: P2P sin autoridad → UPGRADE a servidor autoritativo.
