extends Control

@onready var _master_slider: HSlider = %MasterSlider
@onready var _ambient_slider: HSlider = %AmbientSlider
@onready var _character_slider: HSlider = %CharacterSlider
@onready var _fx_slider: HSlider = %FxSlider

@onready var _master_value: Label = %MasterValue
@onready var _ambient_value: Label = %AmbientValue
@onready var _character_value: Label = %CharacterValue
@onready var _fx_value: Label = %FxValue


func _ready() -> void:
	_setup_slider(_master_slider, _master_value, "Master")
	_setup_slider(_ambient_slider, _ambient_value, "Ambient")
	_setup_slider(_character_slider, _character_value, "Character")
	_setup_slider(_fx_slider, _fx_value, "FX")


func _setup_slider(slider: HSlider, value_label: Label, bus: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = SettingsManager.get_volume(bus)
	_update_value_label(value_label, slider.value)
	slider.value_changed.connect(func(v):
		SettingsManager.set_volume(bus, v)
		_update_value_label(value_label, v)
	)
	slider.drag_ended.connect(func(_changed): SettingsManager.save_settings())


func _update_value_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(round(value * 100.0))
