extends Node2D

const PlayerScene := preload("res://scenes/player/Player.tscn")
const DynamicCameraScene := preload("res://scenes/game/camera/DynamicCamera.tscn")
const BotControllerScript := preload("res://scenes/player/bot/BotController.gd")

const WeaponPrimary := preload("res://scenes/player/weapons/Sword.tscn")
const WeaponSecondary := preload("res://scenes/player/weapons/Fireball.tscn")
const AbilityOne := preload("res://scenes/player/abilities/Dash.tscn")

@onready var _level_root: Node2D = $LevelRoot
@onready var _hud: CanvasLayer = $HUD

var _camera: DynamicCamera
var LEVEL_HALF_WIDTH: int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_level()
	_spawn_camera()
	LEVEL_HALF_WIDTH = round(_camera.reference_view_size.x/2)
	_spawn_players()
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.score_changed.connect(_hud.update_score)


func _load_level() -> void:
	var level_scene: PackedScene = load(GameManager.current_level_path)
	var level: Node2D = level_scene.instantiate() as Node2D
	_level_root.add_child(level)


func _spawn_camera() -> void:
	_camera = DynamicCameraScene.instantiate() as DynamicCamera
	add_child(_camera)
	_camera.make_current()


func _get_spawn_points() -> Array:
	var points := get_tree().get_nodes_in_group("spawn_points")
	#points.sort_custom(func(a, b): return a.name < b.name)
	var looking_at_direction: Array = points.map(func(p): return 1 if p.position.x <= LEVEL_HALF_WIDTH else -1)
	return [points, looking_at_direction]


func _spawn_players() -> void:
	var active_slots := GameManager.get_active_slots()
	_hud.setup(active_slots)
	
	var result := _get_spawn_points()
	var spawn_points = result[0]
	var looking_at_direction = result[1]

	for i in range(active_slots.size()):
		var pid: int = active_slots[i]
		var player: Player = PlayerScene.instantiate() as Player
		player.player_id = pid
		player.character_id = GameManager.player_slots[pid].get("character_id", GameManager.CHARACTER_DISPLAY_NAMES.keys()[0])
		player.weapon_primary_scene = WeaponPrimary
		player.weapon_secondary_scene = WeaponSecondary
		player.ability_1_scene = AbilityOne
		
		# players facing towards the center
		player.facing = looking_at_direction[i]
		player.aim_direction = Vector2(player.facing, 0.0)

		add_child(player)

		if not spawn_points.is_empty():
			var spawn: Node2D = spawn_points[i % spawn_points.size()]
			player.global_position = spawn.global_position
			player.spawn_position = spawn.global_position

		if GameManager.is_bot(pid):
			var bot := BotControllerScript.new()
			bot.name = "BotController"
			bot.player = player
			bot.difficulty = GameManager.player_slots[pid]["difficulty"]
			player.add_child(bot)
			player.bot_controller = bot

		player.health_changed.connect(_on_player_health_changed)


func _on_player_health_changed(player_id: int, current: int, max_health: int) -> void:
	_hud.update_health(player_id, current, max_health)


func _on_match_ended(winner_id: int) -> void:
	_hud.show_match_end(winner_id)
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_INHERIT
	
func on_esc_pressed() -> void:
	_hud.toggle_pause_screen()
	if get_tree().paused:
		get_tree().paused = false
	else:
		get_tree().paused = true
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ESC"):
		on_esc_pressed()
