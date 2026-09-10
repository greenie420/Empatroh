extends Area2D
class_name FireballProjectile

var velocity: Vector2 = Vector2.ZERO
var damage: int = 8
var owner_player_id: int = -1
var lifetime: float = 1.4
var explosion_radius: float = 24.0
var explosion_damage: int = 4
var freeze_duration: float = 5.0
var knockback: float = 120.0

var _age: float = 0.0
var _impacted := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2(0.0, -7.0), 5.0, Color.RED)
	draw_circle(Vector2(0.0, -7.0), 2.4, Color.YELLOW)
	draw_circle(Vector2(0.0, -7.0), 1.0, Color.WHITE_SMOKE)


func _on_body_entered(body: Node) -> void:
	if _impacted:
		return
	if body.is_in_group("players") and body.player_id != owner_player_id and not body.is_dead:
		_impact(body)
	elif body.is_in_group("level_geometry"):
		_impact(null)


func _impact(primary_target: Node) -> void:
	_impacted = true
	if primary_target:
		primary_target.take_damage(damage, owner_player_id)
		primary_target.apply_knockback(velocity.normalized() * knockback)
		primary_target.apply_freeze(freeze_duration)

	for other in get_tree().get_nodes_in_group("players"):
		if other.is_dead or other.player_id == owner_player_id:
			continue
		if other == primary_target:
			continue
		var offset: Vector2 = other.global_position - global_position
		if offset.length() <= explosion_radius:
			other.take_damage(explosion_damage, owner_player_id)
			other.apply_knockback(offset.normalized() * knockback * 0.5 if offset.length_squared() > 0.01 else Vector2.ZERO)

	queue_free()
