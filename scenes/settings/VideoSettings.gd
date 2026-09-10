extends Control

@onready var _scale_option: OptionButton = %ScaleOption
@onready var _resolution_label: Label = %ResolutionLabel
@onready var _fullscreen_check: CheckBox = %FullscreenCheck
@onready var _vsync_check: CheckBox = %VsyncCheck
#@onready var alert_dialog := %AcceptDialog

func _ready() -> void:
	_populate_scale_options()
	_fullscreen_check.button_pressed = SettingsManager.fullscreen
	_vsync_check.button_pressed = SettingsManager.vsync
	_update_resolution_label_and_select()

	_scale_option.item_selected.connect(_on_scale_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	
	# Connect to window resize signal
	#get_tree().root.size_changed.connect(_on_window_resized)


func _on_window_resized() -> void: # doesn't quite work yet -- TODO
	if SettingsManager.fullscreen:
		return
	
	var win_size := DisplayServer.window_get_size()
	
	# Calculate scale candidates
	var scale_x : float = round(float(win_size.x) / SettingsManager.BASE_WIDTH)
	var scale_y : float = round(float(win_size.y) / SettingsManager.BASE_HEIGHT)
	
	# Choose the scale that yields the smaller deviation from the target size
	var error_x : float = abs(win_size.x - SettingsManager.BASE_WIDTH * scale_x)
	var error_y : float = abs(win_size.y - SettingsManager.BASE_HEIGHT * scale_y)
	var new_scale := int(scale_x if error_x <= error_y else scale_y)
	
	var max_scale := SettingsManager.get_max_scale_factor()
	new_scale = clampi(new_scale, 1, max_scale)
	
	if new_scale != SettingsManager.scale_factor:
		SettingsManager.scale_factor = new_scale
		var index := new_scale - 1
		if index >= 0 and index < _scale_option.item_count:
			_scale_option.select(index)
		_update_resolution_label_and_select()


func _populate_scale_options() -> void:
	_scale_option.clear()
	var max_factor := SettingsManager.get_max_scale_factor()
	for factor in range(1, max_factor + 1):
		var w := SettingsManager.BASE_WIDTH * factor
		var h := SettingsManager.BASE_HEIGHT * factor
		_scale_option.add_item("%dx  (%d x %d)" % [factor, w, h], factor)
	var current_index := clampi(SettingsManager.scale_factor - 1, 0, _scale_option.item_count - 1)
	_scale_option.select(current_index)


func _update_resolution_label_and_select() -> void:
	var win_size := DisplayServer.window_get_size()
	
	if SettingsManager.fullscreen:
		var screen_size := DisplayServer.screen_get_size()
		_resolution_label.text = "Fullscreen at %dx%d" % [screen_size.x, screen_size.y]
		disable_scale_select(true)
	else:
		# In windowed mode, show the actual window size
		# (which is BASE_WIDTH * scale_factor, as set in apply_video_settings)
		_resolution_label.text = "Windowed at %dx%d" % [win_size.x, win_size.y]
		disable_scale_select()
		

func _on_scale_selected(index: int) -> void:
	if SettingsManager.fullscreen:
		#alert_dialog.dialog_text = "Can't change resolution when in fullscreen mode."
		#alert_dialog.popup_centered()
		OS.alert("Can't change resolution when in fullscreen mode.", "Uh oh")
		var current_factor = SettingsManager.scale_factor
		var current_index = current_factor - 1  # Because items are added from 1 upwards
		_scale_option.select(current_index)
	else:
		var factor: int = _scale_option.get_item_id(index)
		SettingsManager.set_scale_factor(factor)
		_update_resolution_label_and_select()
		_on_window_resized()
	
	
func disable_scale_select(check: bool = false) -> void:
	_scale_option.disabled = check


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)
	_update_resolution_label_and_select()


func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.vsync = pressed
	SettingsManager.apply_video_settings()
