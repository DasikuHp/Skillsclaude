# 30. Enrutado de MCP + lazo auto-correctivo con convergencia

Hay **dos backends MCP de la misma familia pero topología distinta**, más una
degradación headless. Esta skill **no elige bando: abstrae un contrato de capacidades**,
detecta cuál está conectado y enruta. Así no rompe a los usuarios actuales de Godot AI y
gana las superpoderes de Summer cuando está.

## Los dos backends (no son intercambiables a ciegas)

| Eje | **Summer Engine** | **Godot AI** v2.7.6 |
|---|---|---|
| Transporte | **stdio** (`summer mcp`, lo cablea `summer setup`) | **HTTP** (URL dinámica del dock) |
| Arranque | CLI / engine local | dock del editor |
| Descubrimiento | `~/.summer/api-token` + `localhost:6550` | URL que publica el dock |
| Namespace | `summer_*` (~44) | sin prefijo (~40) |
| Proyecto | `summer create` scaffolda | abres un proyecto Godot existente |
| Extra | genera assets, cloud | — |

## Detección (en `hooks/session_start.sh`, cacheada en `.claude/mcp_backend`)

1. ¿Hay tool `summer_get_project_context` / responde `localhost:6550` con el token? → **summer**.
2. ¿Hay tool de scene-tree sin prefijo / responde el endpoint HTTP del dock? → **godot-ai**.
3. Ninguno → **headless** (avisar; el lazo NO se rompe, ver abajo).

## Contrato de capacidades (verbo → implementación)

Comandos/hooks/flows hablan contra el **verbo**, no contra el tool concreto:

| Verbo | summer | godot-ai | headless (fallback) |
|---|---|---|---|
| `scene_tree` | `summer_get_scene_tree` | `scene_get_hierarchy` | parse `.tscn` |
| `add_node` | `summer_add_node` | `node_create` | editar `.tscn` + check |
| `set_prop` | `summer_set_prop` | `node_set_property` | editar + check |
| `play` | `summer_play`/`summer_stop` | `project_run`/`game_manage` | `godot --headless --quit-after N` |
| `errors` | `summer_get_script_errors` + `summer_get_diagnostics` + `summer_get_debugger_errors` | `logs_read` | `godot --check-only` / smoke |
| `asset_gen` | `summer_generate_*` | — (no soportado) | — (omitir con aviso) |

`asset_gen` solo existe en Summer → cuando el backend no es summer, los comandos lo
**comunican explícitamente** en vez de fallar en silencio (lazy-not-negligent).

## El lazo auto-correctivo (fuente de verdad = runtime real)

Compilar ≠ arrancar. En un RPG los bugs viven en el **runtime** (combate, diálogo, save).
El lazo lee el **error real** del runtime, no lo adivina:

```
DETECTAR   play → errors (summer_get_debugger_errors / logs_read / smoke headless)
   │
NORMALIZAR cada error → {message, file, line, cause, fix, reference, source, hash}
   │        (source = "summer" | "godot-ai" | "headless"; una sola forma para todos)
DIAGNOSTICAR  empareja message contra hooks/errors.json → causa+fix+reference (refs 01-26)
   │
REPARAR    aplica el fix en el archivo señalado (verbo set_prop/edit; flujo verify_and_fix)
   │
RE-VERIFICAR  vuelve a play limpio
   │
CONVERGENCIA  si hash(error) se repite ≥2  ó  iteraciones > MAX_ITERS(4) → ESCALAR
              (devuelve el stack trace real + refs consultadas; nunca parche a ciegas ni loop infinito)
```

- **`source`** marca la fidelidad del diagnóstico (runtime vivo > headless estático).
- **`hash`** (sobre message+file+line) detecta no-convergencia: si tras un fix vuelve el
  mismo error, no insistas — escala con el contexto.
- **Degradación**: sin MCP, el lazo cae a `scripts/verify_loop.sh` (`godot --headless`) y
  normaliza igual a la misma forma. El lazo **nunca** deja a la IA esperando un editor que
  no está.

## Regla de oro (onboarding, G5)
Tras CADA cambio: **un verbo, un play, un vistazo** (`see-it`: `project_run`/`summer_play`
+ captura). Bloquea prompts multi-mecánica partiéndolos en cola: cuando algo rompe, sabes
qué cambio fue. Es la metodología publicada de Summer y el anti-stuck más barato.

## Veredicto ponytail
No construyas un puente que no compila ni fusiones dos MCP a la fuerza: **abstrae el verbo,
detecta el backend, degrada con gracia**. El único código propio es el contrato + la
normalización de errores; el músculo (escena/run/diagnóstico) lo dan los MCP. `net`: cero
managers, cero estado paralelo, cero lock-in a un backend.
