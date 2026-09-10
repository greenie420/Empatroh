extends Node
## SettingsManager
## Loads/saves user://settings.cfg and applies it: integer window scaling,
## per-bus audio volume, and per-player keybindings. InputManager owns the
## actual InputMap wiring; this owns persistence + "apply on boot".

const SETTINGS_PATH := "user://settings.cfg"
const CONTROLS_VERSION := 2

const BASE_WIDTH := 640
const BASE_HEIGHT := 320

# --- Video ---
var scale_factor: int = 2
var fullscreen: bool = false
var vsync: bool = true

# --- Audio (linear 0.0 - 1.0, converted to dB when applied) ---
var volume_master: float = 1.0
var volume_ambient: float = 1.0
var volume_character: float = 1.0
var volume_fx: float = 1.0

# --- Controls ---
# bindings[player_id][action_name] = Array[Dictionary] (serialized InputEvents)
var bindings: Dictionary = {}

var _cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_video_settings()
	apply_audio_settings()
	# Control bindings are applied by InputManager once it has its defaults ready.


func get_max_scale_factor() -> int:
	var screen_size := DisplayServer.screen_get_size()
	var max_w := int(floor(float(screen_size.x) / BASE_WIDTH))
	var max_h := int(floor(float(screen_size.y) / BASE_HEIGHT))
	return max(1, min(max_w, max_h))


func load_settings() -> void:
	var err := _cfg.load(SETTINGS_PATH)
	if err != OK:
		# No file yet, defaults stand.
		return

	scale_factor = _cfg.get_value("video", "scale_factor", scale_factor)
	fullscreen = _cfg.get_value("video", "fullscreen", fullscreen)
	vsync = _cfg.get_value("video", "vsync", vsync)

	volume_master = _cfg.get_value("audio", "master", volume_master)
	volume_ambient = _cfg.get_value("audio", "ambient", volume_ambient)
	volume_character = _cfg.get_value("audio", "character", volume_character)
	volume_fx = _cfg.get_value("audio", "fx", volume_fx)

	bindings.clear()
	var saved_controls_version: int = _cfg.get_value("controls", "version", 0)
	if saved_controls_version != CONTROLS_VERSION:
		# Input defaults changed. Ignore old bindings so the new layout is used.
		return

	for section in _cfg.get_sections():
		if section.begins_with("bindings_p"):
			var player_id := int(section.substr("bindings_p".length()))
			var player_bindings := {}
			for key in _cfg.get_section_keys(section):
				player_bindings[key] = _cfg.get_value(section, key, [])
			bindings[player_id] = player_bindings


func save_settings() -> void:
	_cfg.set_value("controls", "version", CONTROLS_VERSION)

	_cfg.set_value("video", "scale_factor", scale_factor)
	_cfg.set_value("video", "fullscreen", fullscreen)
	_cfg.set_value("video", "vsync", vsync)

	_cfg.set_value("audio", "master", volume_master)
	_cfg.set_value("audio", "ambient", volume_ambient)
	_cfg.set_value("audio", "character", volume_character)
	_cfg.set_value("audio", "fx", volume_fx)

	for player_id in bindings.keys():
		var section := "bindings_p%d" % player_id
		var player_bindings: Dictionary = bindings[player_id]
		for action in player_bindings.keys():
			_cfg.set_value(section, action, player_bindings[action])

	_cfg.save(SETTINGS_PATH)


# ---------------- Video ----------------

func apply_video_settings() -> void:
	scale_factor = clampi(scale_factor, 1, get_max_scale_factor())
	
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var win_size := Vector2i(BASE_WIDTH, BASE_HEIGHT) * scale_factor
		DisplayServer.window_set_size(win_size)
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - win_size) / 2)
	
	# V‑sync still applies
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


func set_scale_factor(value: int) -> void:
	scale_factor = clampi(value, 1, get_max_scale_factor())
	apply_video_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_video_settings()


# ---------------- Audio ----------------

func apply_audio_settings() -> void:
	AudioManager.set_bus_volume_linear("Master", volume_master)
	AudioManager.set_bus_volume_linear("Ambient", volume_ambient)
	AudioManager.set_bus_volume_linear("Character", volume_character)
	AudioManager.set_bus_volume_linear("FX", volume_fx)


func set_volume(bus: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus:
		"Master":
			volume_master = value
		"Ambient":
			volume_ambient = value
		"Character":
			volume_character = value
		"FX":
			volume_fx = value
	AudioManager.set_bus_volume_linear(bus, value)


func get_volume(bus: String) -> float:
	match bus:
		"Master":
			return volume_master
		"Ambient":
			return volume_ambient
		"Character":
			return volume_character
		"FX":
			return volume_fx
	return 1.0


# ---------------- Controls ----------------

func set_binding(player_id: int, action: String, events: Array) -> void:
	if not bindings.has(player_id):
		bindings[player_id] = {}
	bindings[player_id][action] = events


func get_binding(player_id: int, action: String) -> Array:
	if bindings.has(player_id) and bindings[player_id].has(action):
		return bindings[player_id][action]
	return []


func has_saved_bindings() -> bool:
	return not bindings.is_empty()
