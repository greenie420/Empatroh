extends Weapon
## Blaster: fires a Bullet in the direction the owner is facing.

const BulletScene := preload("res://scenes/player/weapons/Bullet.tscn")

@export var bullet_speed: float = 340.0
@export var muzzle_offset: float = 14.0


func _use(owner_player: Node) -> void:
	var bullet: Bullet = BulletScene.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = owner_player.global_position + Vector2(muzzle_offset * owner_player.facing, -6)
	bullet.velocity = Vector2(bullet_speed * owner_player.facing, 0)
	bullet.damage = damage
	bullet.owner_player_id = owner_player.player_id
