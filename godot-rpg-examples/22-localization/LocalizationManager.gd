extends Node
## Autoload. Aplica el locale guardado ANTES de mostrar la UI y lo persiste.
## Maneja el cambio de idioma en runtime, incluyendo re-aplicar textos
## seteados por codigo (que NO se re-traducen solos al cambiar locale).

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "en"

signal locale_changed(locale: String)

func _ready() -> void:
	var loc := _load_saved_locale()
	TranslationServer.set_locale(loc)
	# QA opcional: detecta strings sin traducir y overflow de UI.
	# TranslationServer.set_pseudolocalization_enabled(true)

func set_language(loc: String) -> void:
	# Normaliza p.ej. "en-US" -> "en_US"; verifica que exista.
	loc = TranslationServer.standardize_locale(loc)
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	if not loaded.has(loc):
		push_warning("Locale '%s' no cargado. Disponibles: %s" % [loc, loaded])
	TranslationServer.set_locale(loc)
	_save_locale(loc)
	locale_changed.emit(loc)

func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return OS.get_locale_language() if not OS.get_locale_language().is_empty() else DEFAULT_LOCALE
	return cfg.get_value("i18n", "locale", DEFAULT_LOCALE)

func _save_locale(loc: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # ignora error si no existe
	cfg.set_value("i18n", "locale", loc)
	cfg.save(SETTINGS_PATH)
