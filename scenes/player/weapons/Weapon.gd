extends Node2D
class_name Weapon
## Extensible weapon base. Weapons can be melee or projectile-based and can
## attach timed effects to hit, path, or post-hit events.

enum RangeType { SHORT, LONG }
enum EffectTrigger { NONE, ON_HIT, ON_PATH, AFTER_HIT }

@export var display_name: String = "Weapon"
@export var damage: int = 14
@export var cooldown: float = 0.4
@export var range_type: RangeType = RangeType.SHORT
@export var effect_triggers: Array[EffectTrigger] = [EffectTrigger.NONE]
@export var effect_duration: float = 0.0
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


## Returns true if the attack actually fired.
func try_use(owner_player: Node) -> bool:
	if not is_ready():
		return false
	_cd_remaining = cooldown
	if audio_stream:
		AudioManager.play_sfx(audio_stream, "Character", 0.05)
	_use(owner_player)
	return true


## Override in subclasses.
func _use(_owner_player: Node) -> void:
	pass
