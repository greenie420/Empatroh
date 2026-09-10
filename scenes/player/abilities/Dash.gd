extends Ability
## Dash: quick horizontal burst in the facing direction, with a short window
## of invulnerability so it doubles as an escape/dodge tool.

@export var dash_speed: float = 420.0
@export var dash_duration: float = 0.18
@export var invulnerable_duration: float = 0.22


func _use(owner_player: Node) -> void:
	owner_player.start_dash(dash_speed * owner_player.facing, dash_duration)
	owner_player.grant_invulnerability(invulnerable_duration)
