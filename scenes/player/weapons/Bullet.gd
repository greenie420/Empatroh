extends Area2D
class_name Bullet

var velocity: Vector2 = Vector2.ZERO
var damage: int = 8
var owner_player_id: int = -1
var lifetime: float = 1.2

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and body.player_id != owner_player_id and not body.is_dead:
		body.take_damage(damage, owner_player_id)
		body.apply_knockback(velocity.normalized() * 140.0)
		queue_free()
	elif body.is_in_group("level_geometry"):
		queue_free()
