extends AnimationPlayer

@export var playerController : Player
@export var playerAnimations : AnimationPlayer
@export var sprites2d : Sprite2D

var hasJustLanded : bool = false


func _process(delta: float) -> void:
	if playerController.facing == 1:
		sprites2d.flip_h = false
	elif playerController.facing == -1:
		sprites2d.flip_h = true
	
	if abs(playerController.velocity.x) > 0:
		playerAnimations.play("moving")
	else:
		playerAnimations.play("idle")
		
	if playerController.velocity.y < 0:
		playerAnimations.play("jumping")
		hasJustLanded = true
	elif playerController.velocity.y > 0:
		playerAnimations.play("falling")
		hasJustLanded = true
	elif hasJustLanded: # squash & stretch effect
		hasJustLanded = false
		sprites2d.scale = Vector2(1.1, 0.9)
		var t = create_tween()
		t.tween_property(sprites2d, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_ELASTIC)
