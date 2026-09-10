extends Node
## GameManager
## Central authority for scene flow (splash -> menu -> game), which of the
## 4 player slots are active, whether a slot is a human or a bot, and which
## level to load. Everything else (input, audio, settings) is its own
## autoload so this one stays focused on match setup.

signal match_started
signal match_ended(winner_id: int)
signal score_changed(player_id: int, score: int)

const MAIN_MENU_SCENE := "res://scenes/main_menu/MainMenu.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"
const DEFAULT_LEVEL := "res://scenes/levels/level0/Level0.tscn"

const MIN_PLAYERS := 1
const MAX_PLAYERS := 4

const SLOT_HUMAN := "human"
const SLOT_BOT := "bot"

enum BotDifficulty { EASY, NORMAL, HARD }

const CHARACTER_DISPLAY_NAMES := {
	"player1": "Mage elf",
	"player2": "Electric robot",
} # add new skin ids here as they're made

var current_level_path: String = DEFAULT_LEVEL
var score_target: int = 1 if OS.is_debug_build() else 10
var scores: Dictionary = {}

## player_slots[1..4] = {"active": bool, "type": "human"/"bot", "difficulty": BotDifficulty, "character_id": String}
## Defaults: two human players active, slots 3-4 off (available as bots from the menu).
var player_slots: Dictionary = {
	1: {"active": true, "type": SLOT_HUMAN, "difficulty": BotDifficulty.NORMAL, "character_id": "player1"},
	2: {"active": true, "type": SLOT_HUMAN, "difficulty": BotDifficulty.NORMAL, "character_id": "player2"},
	3: {"active": false, "type": SLOT_BOT, "difficulty": BotDifficulty.NORMAL, "character_id": "player1"},
	4: {"active": false, "type": SLOT_BOT, "difficulty": BotDifficulty.NORMAL, "character_id": "player2"},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	get_tree().paused = false


func set_slot(player_id: int, active: bool, type: String = SLOT_HUMAN, difficulty: BotDifficulty = BotDifficulty.NORMAL, character_id: String = "") -> void:
	if not player_slots.has(player_id):
		return
	var resolved_character_id: String = character_id
	if resolved_character_id.is_empty():
		# Keep whatever character was already picked for this slot, if any.
		resolved_character_id = player_slots[player_id].get("character_id", CHARACTER_DISPLAY_NAMES.keys()[0])
	player_slots[player_id] = {
		"active": active,
		"type": type,
		"difficulty": difficulty,
		"character_id": resolved_character_id,
	}


func get_active_slots() -> Array:
	var result := []
	for pid in player_slots.keys():
		if player_slots[pid]["active"]:
			result.append(pid)
	result.sort()
	return result


func active_player_count() -> int:
	return get_active_slots().size()


func is_bot(player_id: int) -> bool:
	return player_slots.has(player_id) and player_slots[player_id]["active"] and player_slots[player_id]["type"] == SLOT_BOT


func start_new_game(level_path: String = DEFAULT_LEVEL) -> void:
	current_level_path = level_path
	scores.clear()
	for pid in get_active_slots():
		scores[pid] = 0
	get_tree().change_scene_to_file(GAME_SCENE)
	match_started.emit()


func report_score(player_id: int) -> void:
	if not scores.has(player_id):
		scores[player_id] = 0
	scores[player_id] += 1
	score_changed.emit(player_id, scores[player_id])
	if scores[player_id] >= score_target:
		match_ended.emit(player_id)


func quit_game() -> void:
	get_tree().quit()
