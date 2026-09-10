extends Node
## InputManager
## Owns the InputMap. Each player slot gets namespaced actions so players can
## be rebound independently. Gameplay reads these actions through action_name().

signal rebind_captured(player_id: int, action: String, event: InputEvent)
signal rebind_cancelled(player_id: int, action: String)

const PLAYER_COUNT := 4

const ACTIONS := [
	"move_left",
	"move_right",
	"aim_up",
	"aim_down",
	"jump",
	"slide", #probably shouldnt be here
	"attack_primary",
	"attack_secondary",
	"utility",
]

const ACTION_LABELS := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"aim_up": "Aim Up",
	"aim_down": "Aim Down",
	"jump": "Jump",
	"slide": "Slide",
	"attack_primary": "Weapon 1",
	"attack_secondary": "Weapon 2",
	"utility": "Utility",
}

var _listening: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions_exist()
	if SettingsManager.has_saved_bindings():
		apply_saved_bindings()
	else:
		reset_to_defaults(0)
		save_current_bindings()


func action_name(player_id: int, action: String) -> String:
	return "p%d_%s" % [player_id, action]


func _ensure_actions_exist() -> void:
	for player_id in range(1, PLAYER_COUNT + 1):
		for action in ACTIONS:
			var full := action_name(player_id, action)
			if not InputMap.has_action(full):
				InputMap.add_action(full)


# ---------------- Defaults ----------------

func _default_events_for(player_id: int, action: String) -> Array:
	match player_id:
		1: # WASD + G/H/J/M
			match action:
				"move_left": return [_key(KEY_A)]
				"move_right": return [_key(KEY_D)]
				"aim_up": return [_key(KEY_W)]
				"aim_down": return [_key(KEY_S)]
				"jump": return [_key(KEY_J)]
				"slide": return [_key(KEY_S)]
				"attack_primary": return [_key(KEY_G)]
				"attack_secondary": return [_key(KEY_H)]
				"utility": return [_key(KEY_M)]
		2: # Arrow cluster + numpad
			match action:
				"move_left": return [_key(KEY_LEFT)]
				"move_right": return [_key(KEY_RIGHT)]
				"aim_up": return [_key(KEY_UP)]
				"aim_down": return [_key(KEY_DOWN)]
				"jump": return [_key(KEY_KP_6)]
				"slide": return [_key(KEY_DOWN)]
				"attack_primary": return [_key(KEY_KP_4)]
				"attack_secondary": return [_key(KEY_KP_5)]
				"utility": return [_key(KEY_KP_3)]
		3: # Joypad device 0
			match action:
				"move_left": return [_joy_axis(0, JOY_AXIS_LEFT_X, -1.0)]
				"move_right": return [_joy_axis(0, JOY_AXIS_LEFT_X, 1.0)]
				"aim_up": return [_joy_axis(0, JOY_AXIS_LEFT_Y, -1.0)]
				"aim_down": return [_joy_axis(0, JOY_AXIS_LEFT_Y, 1.0)]
				"jump": return [_joy_button(0, JOY_BUTTON_A)]
				"slide": return [_joy_button(0, JOY_BUTTON_DPAD_DOWN)]
				"attack_primary": return [_joy_button(0, JOY_BUTTON_X)]
				"attack_secondary": return [_joy_button(0, JOY_BUTTON_Y)]
				"utility": return [_joy_button(0, JOY_BUTTON_LEFT_SHOULDER)]
		4: # Joypad device 1
			match action:
				"move_left": return [_joy_axis(1, JOY_AXIS_LEFT_X, -1.0)]
				"move_right": return [_joy_axis(1, JOY_AXIS_LEFT_X, 1.0)]
				"aim_up": return [_joy_axis(1, JOY_AXIS_LEFT_Y, -1.0)]
				"aim_down": return [_joy_axis(1, JOY_AXIS_LEFT_Y, 1.0)]
				"jump": return [_joy_button(1, JOY_BUTTON_A)]
				"slide": return [_joy_button(1, JOY_BUTTON_DPAD_DOWN)]
				"attack_primary": return [_joy_button(1, JOY_BUTTON_X)]
				"attack_secondary": return [_joy_button(1, JOY_BUTTON_Y)]
				"utility": return [_joy_button(1, JOY_BUTTON_LEFT_SHOULDER)]
	return []


func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	return e


func _joy_button(device: int, button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	return e


func _joy_axis(device: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = value
	return e


## player_id == 0 resets every player.
func reset_to_defaults(player_id: int) -> void:
	var ids := range(1, PLAYER_COUNT + 1) if player_id == 0 else [player_id]
	for pid in ids:
		for action in ACTIONS:
			var full := action_name(pid, action)
			InputMap.action_erase_events(full)
			for event in _default_events_for(pid, action):
				InputMap.action_add_event(full, event)


# ---------------- Persistence bridge ----------------

func apply_saved_bindings() -> void:
	for pid in range(1, PLAYER_COUNT + 1):
		for action in ACTIONS:
			var full := action_name(pid, action)
			var saved := SettingsManager.get_binding(pid, action)
			InputMap.action_erase_events(full)
			if saved.is_empty():
				for event in _default_events_for(pid, action):
					InputMap.action_add_event(full, event)
			else:
				for data in saved:
					var event := _deserialize_event(data)
					if event:
						InputMap.action_add_event(full, event)


func save_current_bindings() -> void:
	for pid in range(1, PLAYER_COUNT + 1):
		for action in ACTIONS:
			var full := action_name(pid, action)
			var events := InputMap.action_get_events(full)
			var serialized := []
			for event in events:
				var data := _serialize_event(event)
				if not data.is_empty():
					serialized.append(data)
			SettingsManager.set_binding(pid, action, serialized)
	SettingsManager.save_settings()


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.physical_keycode}
	elif event is InputEventJoypadButton:
		return {"type": "joy_button", "device": event.device, "button": event.button_index}
	elif event is InputEventJoypadMotion:
		return {"type": "joy_axis", "device": event.device, "axis": event.axis, "value": event.axis_value}
	return {}


func _deserialize_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			return _key(data["keycode"])
		"joy_button":
			return _joy_button(data["device"], data["button"])
		"joy_axis":
			return _joy_axis(data["device"], data["axis"], data["value"])
	return null


# ---------------- Live rebinding ----------------

func start_rebind(player_id: int, action: String) -> void:
	_listening = {"player_id": player_id, "action": action}
	set_process_unhandled_input(true)


func cancel_rebind() -> void:
	if not _listening.is_empty():
		rebind_cancelled.emit(_listening["player_id"], _listening["action"])
		_listening = {}


func _unhandled_input(event: InputEvent) -> void:
	if _listening.is_empty():
		return

	var accepted_event: InputEvent = null

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			cancel_rebind()
			get_viewport().set_input_as_handled()
			return
		accepted_event = _key(event.physical_keycode)
	elif event is InputEventJoypadButton and event.pressed:
		accepted_event = _joy_button(event.device, event.button_index)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		accepted_event = _joy_axis(event.device, event.axis, signf(event.axis_value))

	if accepted_event == null:
		return

	var player_id: int = _listening["player_id"]
	var action: String = _listening["action"]
	var full := action_name(player_id, action)

	InputMap.action_erase_events(full)
	InputMap.action_add_event(full, accepted_event)

	_listening = {}
	rebind_captured.emit(player_id, action, accepted_event)
	save_current_bindings()
	get_viewport().set_input_as_handled()


func describe_binding(player_id: int, action: String) -> String:
	var events := InputMap.action_get_events(action_name(player_id, action))
	if events.is_empty():
		return "Unbound"
	var event: InputEvent = events[0]
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode)
	elif event is InputEventJoypadButton:
		return "Pad%d Btn%d" % [event.device, event.button_index]
	elif event is InputEventJoypadMotion:
		var dir := "+" if event.axis_value > 0 else "-"
		return "Pad%d Axis%d%s" % [event.device, event.axis, dir]
	return "Unknown"
