extends Control

@export var min_display_time: float = 1.5
@export var fade_time: float = 0.4


var _skipped := false


func _ready() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_time)
	tween.tween_interval(min_display_time)
	tween.tween_callback(_go_to_menu)


func _unhandled_input(event: InputEvent) -> void:
	if _skipped:
		return
	if event is InputEventKey and event.pressed:
		_skip()
	elif event is InputEventJoypadButton and event.pressed:
		_skip()
	elif event is InputEventMouseButton and event.pressed:
		_skip()


func _skip() -> void:
	_skipped = true
	_go_to_menu()


func _go_to_menu() -> void:
	if not is_inside_tree():
		return
	set_process_unhandled_input(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	#tween.tween_callback(func(): GameManager.go_to_main_menu())
	
	#uncomment this to go directly into the new game
	if OS.is_debug_build():
		tween.tween_callback(func(): GameManager.start_new_game())
	else:
		tween.tween_callback(func(): GameManager.go_to_main_menu())
