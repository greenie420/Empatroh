extends Node2D
class_name Ability
## Base class for player abilities (distinct from weapons: usually
## movement/utility/AoE rather than a primary damage source).

@export var display_name: String = "Ability"
@export var cooldown: float = 3.0
@export var audio_stream: AudioStream

var _cd_remaining: float = 0.0


func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		_cd_remaining = max(0.0, _cd_remaining - delta)


func is_ready() -> bool:
	return _cd_remaining <= 0.0


func cooldown_fraction() -> float:
	if cooldown <= 0.0:
		return 1.0
	return 1.0 - (_cd_remaining / cooldown)


func try_use(owner_player: Node) -> bool:
	if not is_ready():
		return false
	_cd_remaining = cooldown
	if audio_stream:
		AudioManager.play_sfx(audio_stream, "Character", 0.05)
	_use(owner_player)
	return true


func _use(_owner_player: Node) -> void:
	pass
