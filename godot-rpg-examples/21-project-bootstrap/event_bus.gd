# res://autoload/event_bus.gd
# Autoload nº1 (registrar PRIMERO en [autoload]). Bus de senales global: cero
# dependencias -> rompe ciclos de inicializacion. Los demas sistemas se comunican
# por senales en lugar de referencias directas.
#
# project.godot:
# [autoload]
# EventBus="*res://autoload/event_bus.gd"        ; el * = habilitado; el ORDEN = orden de carga
# GameState="*res://autoload/game_state.gd"
# SaveManager="*res://autoload/save_manager.gd"
extends Node

## Senales tipadas (GDScript 2.0). Usa StringName para ids/keys.
signal player_died
signal item_picked(item_id: StringName, amount: int)
signal scene_change_requested(target: String)
signal flag_changed(flag: StringName, value: bool)

# NUNCA accedas a otros autoloads en _init(): aun no existen -> "Cannot call method
# on a null value". Si necesitas inicializar contra otro autoload, hazlo en _ready().
# Este autoload no depende de nadie, asi que no necesita _ready().
