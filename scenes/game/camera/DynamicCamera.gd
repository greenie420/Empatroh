extends Camera2D
class_name DynamicCamera

@export_category("Camera settings")
@export_group("Options")
@export_subgroup("Core parameters")
@export var min_zoom_scale: float       # never zoom in tighter than this (view-scale units)
@export var enforce_max_zoom: bool      # if true, players CAN be cropped
@export var max_zoom_scale: float         # only used when enforce_max_zoom = true
@export var world_margin: float
@export var follow_smoothing: float
@export var zoom_smoothing: float
@export var reference_view_size: Vector2

var _target_position: Vector2
var _target_zoom_scale: float   # view-scale (bigger = more zoomed OUT), NOT Camera2D.zoom directly
var _all_players_grounded := false

func _ready() -> void:
	var living := _get_living_players()
	_target_position = _compute_bounds(living).get_center() if not living.is_empty() else global_position
	global_position = _target_position
	_target_zoom_scale = min_zoom_scale
	zoom = Vector2(1.0 / _target_zoom_scale, 1.0 / _target_zoom_scale)  # invert view-scale -> camera zoom

func _physics_process(delta: float) -> void:
	var living := _get_living_players()
	if living.is_empty():
		return

	var bounds: Rect2 = _compute_bounds(living)
	_target_position = bounds.get_center()

	#var framed_rect := Rect2(
		#bounds.position - Vector2(world_margin, world_margin),
		#bounds.size + Vector2(world_margin, world_margin) * 2.0
	#)

	#var zoom_x: float = framed_rect.size.x / reference_view_size.x
	#var zoom_y: float = framed_rect.size.y / reference_view_size.y
	#var required_zoom: float = maxf(zoom_x, zoom_y)   # view-scale needed to fit both axes
#
	## Always respect the min floor (never zoom in tighter than min_zoom_scale).
	## Only respect the max ceiling (allow cropping) if explicitly opted in.
	#if enforce_max_zoom:
		#_target_zoom_scale = clampf(required_zoom, max_zoom_scale, min_zoom_scale)
	#else:
		#_target_zoom_scale = maxf(required_zoom, min_zoom_scale)
#
	#global_position = global_position.lerp(_target_position, clampf(follow_smoothing * delta, 0.0, 1.0))
#
	#var target_camera_zoom: float = 1.0 / _target_zoom_scale   # convert view-scale -> actual camera zoom
	#var new_scale: float = lerpf(zoom.x, target_camera_zoom, clampf(zoom_smoothing * delta, 0.0, 1.0))
	#zoom = Vector2(new_scale, new_scale)
	# --------------------------------
	# POSITION / PAN
	# --------------------------------

	global_position = global_position.lerp(
		_target_position,
		clampf(follow_smoothing * delta, 0.0, 1.0)
	)

	# --------------------------------
	# ZOOM
	# --------------------------------

	var all_grounded := true

	for player in living:
		if not player.is_on_floor() and not player.is_on_wall():
			all_grounded = false
			break

	if all_grounded:
		var framed_rect := Rect2(
			bounds.position - Vector2(world_margin, world_margin),
			bounds.size + Vector2(world_margin, world_margin) * 2.0
		)

		var zoom_x: float = framed_rect.size.x / reference_view_size.x
		var zoom_y: float = framed_rect.size.y / reference_view_size.y
		var required_zoom: float = maxf(zoom_x, zoom_y)

		if enforce_max_zoom:
			_target_zoom_scale = clampf(
				required_zoom,
				max_zoom_scale,
				min_zoom_scale
			)
		else:
			_target_zoom_scale = maxf(
				required_zoom,
				min_zoom_scale
			)

		var target_camera_zoom: float = 1.0 / _target_zoom_scale

		var new_scale := lerpf(
			zoom.x,
			target_camera_zoom,
			clampf(zoom_smoothing * delta, 0.0, 1.0)
		)

		zoom = Vector2(new_scale, new_scale)

func _get_living_players() -> Array:
	var result := []
	for node in get_tree().get_nodes_in_group("players"):
		if not node.is_dead:
			result.append(node)
	return result

func _compute_bounds(players: Array) -> Rect2:
	var rect := Rect2(players[0].global_position, Vector2.ZERO)
	for i in range(1, players.size()):
		rect = rect.expand(players[i].global_position)
	return rect
