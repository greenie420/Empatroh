extends Control

const SLOT_OPTIONS := ["Off", "Human", "Bot"]

@onready var _new_game_button: Button = %NewGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton

@onready var _player_count_popup: PanelContainer = %PlayerCountPopup
@onready var _slot_rows: VBoxContainer = %SlotRows
@onready var _start_button: Button = %StartButton
@onready var _cancel_button: Button = %CancelButton
@onready var _error_label: Label = %ErrorLabel

var _slot_options: Dictionary = {} # player_id -> OptionButton (Off/Human/Bot)
var _character_options: Dictionary = {} # player_id -> OptionButton (skin choice)


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)

	_build_slot_rows()
	_player_count_popup.hide()
	_new_game_button.grab_focus()


func _build_slot_rows() -> void:
	for child in _slot_rows.get_children():
		child.queue_free()
	_slot_options.clear()
	_character_options.clear()

	for pid in range(1, GameManager.MAX_PLAYERS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var label := Label.new()
		label.text = "Player %d" % pid
		label.custom_minimum_size = Vector2(80, 0)
		row.add_child(label)

		var slot: Dictionary = GameManager.player_slots[pid]

		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(100, 0)
		for i in range(SLOT_OPTIONS.size()):
			option.add_item(SLOT_OPTIONS[i], i)

		if not slot["active"]:
			option.select(0)
		elif slot["type"] == GameManager.SLOT_HUMAN:
			option.select(1)
		else:
			option.select(2)

		var character_option := OptionButton.new()
		character_option.custom_minimum_size = Vector2(100, 0)
		var character_ids: Array = GameManager.CHARACTER_DISPLAY_NAMES.keys()
		for i in range(character_ids.size()):
			character_option.add_item(GameManager.CHARACTER_DISPLAY_NAMES.get(character_ids[i], character_ids[i]), i)

		var current_character_id: String = slot.get("character_id", character_ids[0])
		var selected_index := character_ids.find(current_character_id)
		character_option.select(max(0, selected_index))
		character_option.disabled = not slot["active"]

		# Grey out the skin picker whenever the slot is set to Off.
		option.item_selected.connect(func(index: int) -> void:
			character_option.disabled = index == 0
		)

		row.add_child(option)
		row.add_child(character_option)
		_slot_rows.add_child(row)
		_slot_options[pid] = option
		_character_options[pid] = character_option


func _on_new_game_pressed() -> void:
	_error_label.text = ""
	_player_count_popup.show()
	_start_button.grab_focus()


func _on_cancel_pressed() -> void:
	_player_count_popup.hide()
	_new_game_button.grab_focus()


func _on_start_pressed() -> void:
	var active_count := 0
	for pid in _slot_options.keys():
		var choice: int = _slot_options[pid].get_selected_id()
		var character_id: String = GameManager.CHARACTER_DISPLAY_NAMES.keys()[_character_options[pid].get_selected_id()]
		match choice:
			0:
				GameManager.set_slot(pid, false, GameManager.SLOT_HUMAN, GameManager.BotDifficulty.NORMAL, character_id)
			1:
				GameManager.set_slot(pid, true, GameManager.SLOT_HUMAN, GameManager.BotDifficulty.NORMAL, character_id)
				active_count += 1
			2:
				GameManager.set_slot(pid, true, GameManager.SLOT_BOT, GameManager.BotDifficulty.NORMAL, character_id)
				active_count += 1

	if active_count < GameManager.MIN_PLAYERS:
		_error_label.text = "Need at least %d players (human or bot)." % GameManager.MIN_PLAYERS
		return

	GameManager.start_new_game(GameManager.DEFAULT_LEVEL)


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/SettingsMenu.tscn")


func _on_exit_pressed() -> void:
	GameManager.quit_game()
