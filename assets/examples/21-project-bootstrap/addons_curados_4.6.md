# Addons curados Godot 4.6 (repos reales verificados)
# Verifica la pagina /releases de cada addon contra 4.6 antes de fijar version.

| Addon          | Repo real                                      | Tipo             | RPG: para que                         | Nota 4.6 / anti-stuck |
|----------------|------------------------------------------------|------------------|---------------------------------------|-----------------------|
| Dialogic 2     | github.com/dialogic-godot/dialogic             | GDScript         | Dialogos, VN, branching, retratos     | Mantenido. Copia solo addons/dialogic/. AssetLib 833. |
| Dialogue Mgr   | github.com/nathanhoad/godot_dialogue_manager   | GDScript         | Dialogo mas ligero/scripteable        | Alternativa a Dialogic; elige uno, no ambos. |
| Phantom Camera | github.com/ramokz/phantom-camera               | GDScript         | Camara 3D tipo Cinemachine (follow/blend) | Verifica release vs 4.6. AssetLib 1822. |
| LimboAI        | github.com/limbonaut/limboai                   | C++ GDExtension  | Behavior Trees + FSM (IA enemigos)    | Necesita BINARIO .so/.dll por plataforma; soporte 4.6 desde v1.6.0; <1.6.0 rompe. NO ideal para web. |
| Beehave        | github.com/bitbrain/beehave (branch godot-4.x) | GDScript         | Behavior Trees (alternativa pura)     | Sin binario -> mejor para CI/agentes y web. NO usar a la vez con LimboAI (clase Blackboard colisiona). |
| GLoot          | github.com/peter-kish/gloot                    | GDScript         | Inventario universal (grid, stacks)   | 4.4+ (releases actuales; AssetLib aun lista 4.2). Autor peter-kish (NO peter1745). AssetLib 1368. Importa solo addons/. |
| GUT            | github.com/bitwes/Gut                          | GDScript         | Unit testing por CLI                  | Serie 9.x = Godot 4.x. Usar si tests solo GDScript. |
| gdUnit4        | github.com/MikeSchulze/gdUnit4                 | GDScript + C#    | Testing GDScript+C#, mocking, JUnit XML | Usar si C#/mixto o quieres CI; GitHub Action: MikeSchulze/gdUnit4-action. (godot-gdunit-labs es la org actual; MikeSchulze redirige.) |

# Habilitar addons sin editor: editar project.godot ->
# [editor_plugins]
# enabled=PackedStringArray("res://addons/phantom_camera/plugin.cfg", "res://addons/dialogic/plugin.cfg")
