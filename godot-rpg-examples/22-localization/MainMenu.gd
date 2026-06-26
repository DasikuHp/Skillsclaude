extends Control
## Demuestra tr(), tr_n() con contexto, format(), auto_translate_mode
## y re-traduccion correcta al cambiar de idioma.

@onready var title_label: Label = $Title
@onready var greet_label: Label = $Greeting
@onready var enemies_label: Label = $EnemiesKilled
@onready var player_name_label: Label = $PlayerName

var _player_name: String = "Cloud"
var _enemy_count: int = 3

func _ready() -> void:
	# El nombre propio NO debe traducirse aunque coincida con una clave.
	# Ponlo DIRECTAMENTE en el nodo (la herencia DISABLED es buggy, GH-95357).
	player_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_refresh_texts()

func _notification(what: int) -> void:
	# Se dispara tras TranslationServer.set_locale(). Los Control con
	# auto-translate se refrescan solos; los textos por codigo NO -> aqui.
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_texts()

func _refresh_texts() -> void:
	title_label.text = tr("START_GAME")
	# Traducir PRIMERO, formatear DESPUES. Nunca concatenar strings.
	greet_label.text = tr("GREET_PLAYER").format([_player_name])
	# Plural con contexto opcional; n elige la forma segun el locale.
	var txt: String = tr_n("%d enemy", "%d enemies", _enemy_count)
	enemies_label.text = txt % _enemy_count
	player_name_label.text = _player_name

func _on_spanish_pressed() -> void:
	LocalizationManager.set_language("es")

func _on_japanese_pressed() -> void:
	LocalizationManager.set_language("ja")
