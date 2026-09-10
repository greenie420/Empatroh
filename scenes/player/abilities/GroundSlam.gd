extends Ability
## Ground Slam: radial knockback + damage centered on the player. Good
## "get off me" panic button when surrounded.

@export var radius: float = 60.0
@export var damage: int = 12
@export var knockback: float = 260.0


func _use(owner_player: Node) -> void:
	for other in get_tree().get_nodes_in_group("players"):
		if other == owner_player or other.is_dead:
			continue
		var offset: Vector2 = other.global_position - owner_player.global_position
		var dist := offset.length()
		if dist > radius:
			continue
		other.take_damage(damage, owner_player.player_id)
		var dir := offset.normalized() if dist > 1.0 else Vector2(owner_player.facing, -0.5)
		other.apply_knockback(dir * knockback)
