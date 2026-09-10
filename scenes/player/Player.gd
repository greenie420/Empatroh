extends CharacterBody2D
class_name Player

signal health_changed(player_id: int, current: int, max: int)
signal died(player_id: int)
signal respawned(player_id: int)

const CHARACTER_TEXTURES: Dictionary = {
	"player1": preload("res://assets/sprites/characters/player1.png"),
	"player2": preload("res://assets/sprites/characters/player2.png"),
}
const DEFAULT_CHARACTER_ID := "player1"

@export_category("Player settings")
@export_group("Options")
@export_subgroup("Core parameters")
@export var player_id: int
@export var character_id: String = DEFAULT_CHARACTER_ID
@export var max_health: int
@export var move_speed: float
@export var jump_velocity: float
@export var gravity: float

@export_subgroup("Movement enhancements")
@export var acceleration: float
@export var coyote_time: float
@export var double_jump_multiplier: float

@export_subgroup("Wall hug")
@export var wall_slide_speed: float
@export var wall_jump_horizontal: float
@export var wall_jump_vertical: float

@export_subgroup("Slide")
@export var slide_speed: float
@export var slide_acceleration: float
@export var slide_friction: float
@export var slide_min_speed: float
@export var slope_jump_angle: float
@export var slope_jump_boost: float

var weapon_primary_scene: PackedScene
var weapon_secondary_scene: PackedScene
var ability_1_scene: PackedScene

@onready var _respawn_timer: Timer = %RespawnTimer
@onready var _sprite: Sprite2D = %Sprite2D
@onready var _aim_indicator: Polygon2D = %AimIndicator

var health: int
var is_dead: bool = false
var facing: int = 1
var aim_direction: Vector2 = Vector2.RIGHT
var is_invulnerable: bool = false
var has_doublejumped: bool = false
var is_wall_hugging: bool = false
var is_sliding: bool = false
var is_frozen: bool = false

var spawn_position: Vector2 = Vector2.ZERO
var bot_controller: Node = null

var _weapon_primary: Weapon
var _weapon_secondary: Weapon
var _ability_1: Ability

var _dash_timer: float = 0.0
var _dash_velocity_x: float = 0.0
var _invuln_timer: float = 0.0
var _freeze_timer: float = 0.0
var _coyote_timer: float = 0.0
var _wall_normal: Vector2 = Vector2.ZERO
var _wall_jump_available: bool = false
var _wall_jump_lock_timer: float = 0.0

# Movement is split into two layers:
#   _movement_velocity  = velocity controlled by the player (run/jump/slide/dash)
#   _external_velocity  = velocity imposed by gameplay (knockback, explosions, etc.)
# This prevents a status effect such as freeze from accidentally stopping gravity
# and prevents normal acceleration from immediately deleting weapon knockback.
var _movement_velocity: Vector2 = Vector2.ZERO
var _external_velocity: Vector2 = Vector2.ZERO

@export_subgroup("External forces")
@export var knockback_decay: float


func _ready() -> void:
	add_to_group("players")
	health = max_health
	spawn_position = global_position
	set_character(character_id)
	_update_aim_indicator()

	_weapon_primary = _instantiate_module(weapon_primary_scene) as Weapon
	_weapon_secondary = _instantiate_module(weapon_secondary_scene) as Weapon
	_ability_1 = _instantiate_module(ability_1_scene) as Ability


func set_character(id: String) -> void:
	character_id = id
	_sprite.texture = CHARACTER_TEXTURES.get(id, CHARACTER_TEXTURES[DEFAULT_CHARACTER_ID])


func _instantiate_module(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var node: Node = scene.instantiate()
	add_child(node)
	return node

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	var input_state := _get_input_state(delta)

	_update_aim(input_state)
	_update_movement(input_state, delta)
	_apply_external_velocity(delta)
	_sync_velocity_for_move()

	move_and_slide()
	_update_post_move_state(input_state)

	if input_state.attack_primary and _weapon_primary:
		_weapon_primary.try_use(self)
	if input_state.attack_secondary and _weapon_secondary:
		_weapon_secondary.try_use(self)
	if input_state.utility and _ability_1:
		_ability_1.try_use(self)


func _update_timers(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = max(0.0, _invuln_timer - delta)
		is_invulnerable = _invuln_timer > 0.0

	if _freeze_timer > 0.0:
		_freeze_timer = max(0.0, _freeze_timer - delta)
		is_frozen = _freeze_timer > 0.0

	if _dash_timer > 0.0:
		_dash_timer = max(0.0, _dash_timer - delta)

	if _wall_jump_lock_timer > 0.0:
		_wall_jump_lock_timer = max(0.0, _wall_jump_lock_timer - delta)


func _update_movement(input_state: Dictionary, delta: float) -> void:
	# `_movement_velocity` is owned by the movement controller. External
	# forces such as weapon knockback are kept separate in `_external_velocity`
	# so normal acceleration/deceleration can never erase or suspend them.
	var grounded := is_on_floor()

	if grounded:
		_coyote_timer = coyote_time
		has_doublejumped = false
		_wall_jump_available = false
		if _movement_velocity.y > 0.0:
			_movement_velocity.y = 0.0
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)
		# Gravity is ALWAYS applied while airborne, including while frozen.
		# A freeze is a control/status effect, not a suspension of physics.
		_movement_velocity.y += gravity * delta

	# Jumping is player control, so a frozen player cannot initiate a jump.
	if not is_frozen and input_state.jump:
		if is_wall_hugging and _wall_jump_available:
			_wall_jump()
		elif can_jump():
			_movement_velocity.y = -jump_velocity
			_coyote_timer = 0.0
		elif can_doublejump():
			has_doublejumped = true
			_movement_velocity.y = -jump_velocity * double_jump_multiplier

	# Dash is also player-controlled. It overrides normal horizontal movement,
	# but it does NOT erase external knockback.
	if _dash_timer > 0.0 and not is_frozen:
		_movement_velocity.x = _dash_velocity_x
		return

	if is_frozen:
		# Preserve no player steering while frozen. External velocity is still
		# allowed to move the player and gravity continues above.
		_movement_velocity.x = move_toward(_movement_velocity.x, 0.0, acceleration * delta)
		is_sliding = false
		return

	# Slide is grounded player control.
	if input_state.slide and grounded and (absf(input_state.move_axis) > 0.01 or absf(_movement_velocity.x) > slide_min_speed):
		is_sliding = true
	else:
		is_sliding = false

	if is_sliding:
		var slide_direction := signf(input_state.move_axis)
		if absf(slide_direction) < 0.01:
			slide_direction = float(facing)
		_movement_velocity.x = move_toward(_movement_velocity.x, slide_direction * slide_speed, slide_acceleration * delta)
	else:
		var target_x: float = input_state.move_axis * move_speed
		_movement_velocity.x = move_toward(_movement_velocity.x, target_x, acceleration * delta)

	# Jumping during a slide on a meaningful slope gets the requested boost.
	if input_state.jump and is_sliding and _is_meaningful_slope():
		_movement_velocity.y = -jump_velocity * slope_jump_boost
		_movement_velocity.x *= slope_jump_boost
		is_sliding = false

	if not input_state.slide and absf(_movement_velocity.x) < slide_min_speed:
		is_sliding = false

	if absf(input_state.move_axis) > 0.01:
		facing = int(signf(input_state.move_axis))

# Wall jump
func _wall_jump() -> void:
	_movement_velocity = Vector2(
		-_wall_normal.x * wall_jump_horizontal,
		-wall_jump_vertical
	)
	_wall_jump_available = false
	is_wall_hugging = false
	_wall_jump_lock_timer = 0.08

# External forces
func _apply_external_velocity(delta: float) -> void:
	_external_velocity = _external_velocity.move_toward(
		Vector2.ZERO,
		knockback_decay * delta
	)

func _sync_velocity_for_move() -> void:
	velocity = _movement_velocity + _external_velocity

func _update_aim(input_state: Dictionary) -> void:
	var raw_aim := Vector2(input_state.move_axis, input_state.aim_y)
	if raw_aim.length_squared() > 0.01:
		aim_direction = raw_aim.normalized()
		if absf(aim_direction.x) > 0.01:
			facing = int(signf(aim_direction.x))
	_update_aim_indicator()


func _update_aim_indicator() -> void:
	if not is_instance_valid(_aim_indicator):
		return
	_aim_indicator.rotation = aim_direction.angle()


func _update_post_move_state(input_state: Dictionary) -> void:
	# This state is intentionally updated AFTER move_and_slide(), because wall
	# contact and the wall normal come from the latest collision result.
	var was_hugging := is_wall_hugging
	is_wall_hugging = false

	if is_on_wall() and not is_on_floor() and _wall_jump_lock_timer <= 0.0:
		var normal := get_wall_normal()
		var pushing_into_wall: float = input_state.move_axis * normal.x < -0.1
		if pushing_into_wall and velocity.y >= 0.0:
			_wall_normal = normal
			is_wall_hugging = true
			_wall_jump_available = true
			# Limit the movement component of the descent. External knockback is
			# deliberately separate and therefore cannot accidentally disable gravity.
			_movement_velocity.y = min(_movement_velocity.y, wall_slide_speed)
		elif was_hugging and velocity.y >= 0.0:
			_wall_normal = normal

	if not is_wall_hugging and is_on_floor():
		_wall_jump_available = false

	# Refresh the cached coyote state from the actual post-move collision.
	if is_on_floor():
		_coyote_timer = coyote_time
		has_doublejumped = false


func _is_meaningful_slope() -> bool:
	if not is_on_floor():
		return false
	var floor_normal := get_floor_normal()
	var angle_from_up := rad_to_deg(acos(clampf(floor_normal.dot(Vector2.UP), -1.0, 1.0)))
	return angle_from_up >= slope_jump_angle


func _get_input_state(delta: float) -> Dictionary:
	if bot_controller:
		return bot_controller.compute_input(delta)

	var left := InputManager.action_name(player_id, "move_left")
	var right := InputManager.action_name(player_id, "move_right")
	var up := InputManager.action_name(player_id, "aim_up")
	var down := InputManager.action_name(player_id, "aim_down")
	return {
		"move_axis": Input.get_axis(left, right),
		"aim_y": Input.get_axis(up, down),
		"jump": Input.is_action_just_pressed(InputManager.action_name(player_id, "jump")),
		"slide": Input.is_action_pressed(InputManager.action_name(player_id, "slide")),
		"attack_primary": Input.is_action_just_pressed(InputManager.action_name(player_id, "attack_primary")),
		"attack_secondary": Input.is_action_just_pressed(InputManager.action_name(player_id, "attack_secondary")),
		"utility": Input.is_action_just_pressed(InputManager.action_name(player_id, "utility")),
	}


func can_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


func can_doublejump() -> bool:
	return not is_on_floor() and not has_doublejumped and not is_wall_hugging


# ----- Combat hooks -----

func take_damage(amount: int, instigator_id: int = -1) -> void:
	if is_dead or is_invulnerable:
		return
	health = max(0, health - amount)
	health_changed.emit(player_id, health, max_health)
	if health <= 0:
		_die(instigator_id)


func apply_knockback(force: Vector2) -> void:
	# Never write knockback directly into `velocity`: the movement controller
	# would otherwise overwrite it during the next acceleration step.
	_external_velocity += force


func grant_invulnerability(duration: float) -> void:
	_invuln_timer = max(_invuln_timer, duration)
	is_invulnerable = true


func apply_freeze(duration: float) -> void:
	_freeze_timer = max(_freeze_timer, duration)
	is_frozen = true


func start_dash(velocity_x: float, duration: float) -> void:
	_dash_velocity_x = velocity_x
	_dash_timer = duration


# ----- Death / Respawn -----

func _die(instigator_id: int) -> void:
	is_dead = true
	died.emit(player_id)
	visible = false
	set_physics_process(false)
	if instigator_id != -1 and instigator_id != player_id:
		GameManager.report_score(instigator_id)
	_respawn_timer.start()


func _on_respawn_timer_timeout() -> void:
	global_position = spawn_position
	health = max_health
	is_dead = false
	visible = true
	velocity = Vector2.ZERO
	_movement_velocity = Vector2.ZERO
	_external_velocity = Vector2.ZERO
	_coyote_timer = 0.0
	has_doublejumped = false
	is_wall_hugging = false
	_wall_jump_available = false
	_freeze_timer = 0.0
	is_frozen = false
	set_physics_process(true)
	health_changed.emit(player_id, health, max_health)
	respawned.emit(player_id)
