extends Control

@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	InputManager.save_current_bindings()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
