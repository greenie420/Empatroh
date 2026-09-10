extends Weapon
class_name FireballWeapon
## Fireball: long-range projectile. On impact it damages the target, creates a
## small explosion, and applies a temporary freeze effect.

const FIREBALL_PROJECTILE_SCENE := preload("res://scenes/player/weapons/FireballProjectile.tscn")

@export var projectile_speed: float = 300.0
@export var projectile_lifetime: float = 1.4
@export var explosion_radius: float = 24.0
@export var explosion_damage: int = 4
@export var freeze_duration: float = 5.0
@export var knockback: float = 120.0


func _use(owner_player: Node) -> void:
	var fireball: FireballProjectile = FIREBALL_PROJECTILE_SCENE.instantiate() as FireballProjectile
	get_tree().current_scene.add_child(fireball)
	fireball.global_position = owner_player.global_position + owner_player.aim_direction * 12.0
	fireball.velocity = owner_player.aim_direction * projectile_speed
	fireball.damage = damage
	fireball.owner_player_id = owner_player.player_id
	fireball.lifetime = projectile_lifetime
	fireball.explosion_radius = explosion_radius
	fireball.explosion_damage = explosion_damage
	fireball.freeze_duration = freeze_duration
	fireball.knockback = knockback
