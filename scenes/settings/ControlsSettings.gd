extends Control

@onready var _player_option: OptionButton = %PlayerOption
@onready var _rows_container: VBoxContainer = %RowsContainer
@onready var _reset_button: Button = %ResetButton
@onready var _hint_label: Label = %HintLabel

var _current_player: int = 1
var _row_buttons: Dictionary = {} # action -> Button
var _listening_action: String = ""


func _ready() -> void:
	_player_option.clear()
	for pid in range(1, InputManager.PLAYER_COUNT + 1):
		_player_option.add_item("Player %d" % pid, pid)
	_player_option.item_selected.connect(_on_player_selected)
	_reset_button.pressed.connect(_on_reset_pressed)

	InputManager.rebind_captured.connect(_on_rebind_captured)
	InputManager.rebind_cancelled.connect(_on_rebind_cancelled)

	_build_rows()
	_refresh_row_labels()


func _on_player_selected(index: int) -> void:
	_current_player = _player_option.get_item_id(index)
	_refresh_row_labels()


func _build_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	_row_buttons.clear()

	for action in InputManager.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = InputManager.ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(120, 0)
		row.add_child(label)

		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(160, 28)
		bind_button.pressed.connect(_on_bind_button_pressed.bind(action, bind_button))
		row.add_child(bind_button)

		_rows_container.add_child(row)
		_row_buttons[action] = bind_button


func _refresh_row_labels() -> void:
	for action in _row_buttons.keys():
		var button: Button = _row_buttons[action]
		button.text = InputManager.describe_binding(_current_player, action)
	_hint_label.text = ""


func _on_bind_button_pressed(action: String, button: Button) -> void:
	if not _listening_action.is_empty():
		return
	_listening_action = action
	button.text = "Press a key / button..."
	_hint_label.text = "Waiting for input (Esc to cancel)"
	InputManager.start_rebind(_current_player, action)


func _on_rebind_captured(player_id: int, action: String, _event: InputEvent) -> void:
	_listening_action = ""
	_hint_label.text = ""
	if player_id == _current_player:
		_refresh_row_labels()


func _on_rebind_cancelled(player_id: int, action: String) -> void:
	_listening_action = ""
	_hint_label.text = ""
	if player_id == _current_player:
		_refresh_row_labels()


func _on_reset_pressed() -> void:
	InputManager.reset_to_defaults(_current_player)
	InputManager.save_current_bindings()
	_refresh_row_labels()
