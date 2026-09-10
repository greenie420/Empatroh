extends Weapon
## Sword: short-range instant melee attack.

@export var melee_range: float = 26.0
@export var knockback: float = 220.0


func _use(owner_player: Node) -> void:
	for other in get_tree().get_nodes_in_group("players"):
		if other == owner_player or other.is_dead:
			continue
		var to_other: Vector2 = other.global_position - owner_player.global_position
		if to_other.length() > melee_range:
			continue
		if to_other.length_squared() > 0.01 and to_other.normalized().dot(owner_player.aim_direction) < 0.25:
			continue
		other.take_damage(damage, owner_player.player_id)
		other.apply_knockback(owner_player.aim_direction * knockback)
