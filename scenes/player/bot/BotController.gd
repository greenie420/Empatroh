extends Node
class_name BotController
## Minimal local-multiplayer bot. Not trying to be clever: pick the nearest
## living opponent, close the distance to a preferred fighting range, jump
## when it looks stuck or the target is above, and throw out attacks/
## abilities on a randomized decision timer so bots don't all react in
## lockstep. Good enough to fill an empty slot for a deathmatch; swap out
## `_decide()` for something smarter later without touching Player.gd.

@export var player: Player
@export var difficulty: int = GameManager.BotDifficulty.NORMAL

const PREFERRED_RANGE := 40.0
const DECISION_INTERVAL_BY_DIFFICULTY := {
	0: 0.45, # EASY - slow to react
	1: 0.28, # NORMAL
	2: 0.15, # HARD - reacts fast
}
const ABILITY_CHANCE_BY_DIFFICULTY := {0: 0.05, 1: 0.12, 2: 0.22}
const JUMP_CHANCE_STUCK := 0.6

var _decision_timer: float = 0.0
var _cached_state: Dictionary = {
	"move_axis": 0.0, "aim_y": 0.0, "jump": false, "slide": false, "attack_primary": false,
	"attack_secondary": false, "utility": false,
}
var _last_x: float = 0.0
var _stuck_time: float = 0.0


func compute_input(delta: float) -> Dictionary:
	if player == null or player.is_dead:
		return {"move_axis": 0.0, "aim_y": 0.0, "jump": false, "slide": false, "attack_primary": false, "attack_secondary": false, "utility": false}

	_decision_timer -= delta
	# Always reset the "just pressed" style flags each frame; they only stay
	# true for the single frame a decision is made, matching human input.
	_cached_state.jump = false
	_cached_state.attack_primary = false
	_cached_state.attack_secondary = false
	_cached_state.utility = false

	if _decision_timer <= 0.0:
		_decision_timer = DECISION_INTERVAL_BY_DIFFICULTY.get(difficulty, 0.28)
		_decide()

	_track_stuck(delta)
	return _cached_state


func _decide() -> void:
	var target := _find_nearest_target()
	if target == null:
		_cached_state.move_axis = 0.0
		_cached_state.aim_y = 0.0
		return

	var offset: Vector2 = target.global_position - player.global_position
	var dist := absf(offset.x)

	_cached_state.aim_y = clampf(offset.y / 80.0, -1.0, 1.0)

	if dist > PREFERRED_RANGE:
		_cached_state.move_axis = signf(offset.x)
	elif dist < PREFERRED_RANGE * 0.6:
		_cached_state.move_axis = -signf(offset.x) # back off slightly
	else:
		_cached_state.move_axis = 0.0

	# Jump toward a target that's notably above us.
	if offset.y < -20.0 and player.is_on_floor():
		_cached_state.jump = true

	var ability_chance: float = ABILITY_CHANCE_BY_DIFFICULTY.get(difficulty, 0.12)

	if dist <= PREFERRED_RANGE:
		_cached_state.attack_primary = true
		if randf() < 0.3:
			_cached_state.attack_secondary = true
	elif dist <= PREFERRED_RANGE * 2.0 and randf() < 0.4:
		_cached_state.attack_secondary = true # try the ranged option from farther out

	if randf() < ability_chance:
		_cached_state.utility = true


func _find_nearest_target() -> Player:
	var best: Player = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("players"):
		if node == player or node.is_dead:
			continue
		var d: float = player.global_position.distance_squared_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best


func _track_stuck(delta: float) -> void:
	# If we're trying to move but not making horizontal progress (walked into
	# a wall/ledge), occasionally jump to try to get unstuck.
	if absf(_cached_state.move_axis) > 0.1 and player.is_on_floor():
		if absf(player.global_position.x - _last_x) < 0.5:
			_stuck_time += delta
		else:
			_stuck_time = 0.0
		if _stuck_time > 0.3 and randf() < JUMP_CHANCE_STUCK:
			_cached_state.jump = true
			_stuck_time = 0.0
	_last_x = player.global_position.x
