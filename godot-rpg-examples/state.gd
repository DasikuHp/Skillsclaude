@abstract
class_name State
extends Node
## Base abstracta de estado (Godot 4.5+: @abstract en vez de simular interfaces).
## Cada estado decide a dónde transita; el StateMachine no lo sabe.

var machine: StateMachine

@abstract func enter() -> void
@abstract func exit() -> void
@abstract func physics_update(delta: float) -> void
