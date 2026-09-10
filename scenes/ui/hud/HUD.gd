extends CanvasLayer

const CORNER_ANCHORS := [
	{"anchor": Vector2(0, 0), "grow_h": Control.GROW_DIRECTION_END, "align": HORIZONTAL_ALIGNMENT_LEFT},
	{"anchor": Vector2(1, 0), "grow_h": Control.GROW_DIRECTION_BEGIN, "align": HORIZONTAL_ALIGNMENT_RIGHT},
	{"anchor": Vector2(0, 1), "grow_h": Control.GROW_DIRECTION_END, "align": HORIZONTAL_ALIGNMENT_LEFT},
	{"anchor": Vector2(1, 1), "grow_h": Control.GROW_DIRECTION_BEGIN, "align": HORIZONTAL_ALIGNMENT_RIGHT},
]

@onready var _root: Control = %Root
@onready var _end_overlay: PanelContainer = %EndOverlay
@onready var _end_label: Label = %EndLabel
@onready var _end_button: Button = %EndButton

var _bars: Dictionary = {} # player_id -> ProgressBar
var _score_labels: Dictionary = {} # player_id -> Label


func _ready() -> void:
	# Stay interactive even when the tree pauses on match end.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(player_ids: Array) -> void:
	for child in _root.get_children():
		child.queue_free()
	_bars.clear()
	_score_labels.clear()

	for i in range(player_ids.size()):
		var pid: int = player_ids[i]
		var corner: Dictionary = CORNER_ANCHORS[i % CORNER_ANCHORS.size()]
		_build_slot(pid, corner, i)

	_end_overlay.hide()
	_end_button.pressed.connect(_on_end_button_pressed)


func _build_slot(player_id: int, corner: Dictionary, index: int) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(110, 0)
	box.anchor_left = corner.anchor.x
	box.anchor_right = corner.anchor.x
	box.anchor_top = corner.anchor.y
	box.anchor_bottom = corner.anchor.y
	var margin_x := 10.0 if corner.anchor.x == 0 else -120.0
	var margin_y := 10.0 if corner.anchor.y == 0 else -46.0
	box.offset_left = margin_x
	box.offset_right = margin_x + 110.0
	box.offset_top = margin_y
	box.offset_bottom = margin_y + 36.0

	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Player %d%s" % [player_id, " (Bot)" if GameManager.is_bot(player_id) else ""]
	name_label.horizontal_alignment = corner.align
	name_label.add_theme_font_size_override("font_size", 11)
	name_row.add_child(name_label)

	var score_label := Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 11)
	score_label.modulate = Color(1, 1, 1, 0.6)
	name_row.add_child(score_label)
	_score_labels[player_id] = score_label

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = GameManager.player_slots.get(player_id, {}).get("max_health", 100)
	bar.value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110, 14)

	box.add_child(name_row)
	box.add_child(bar)
	_root.add_child(box)
	_bars[player_id] = bar


func update_health(player_id: int, current: int, max_health: int) -> void:
	if not _bars.has(player_id):
		return
	var bar: ProgressBar = _bars[player_id]
	bar.max_value = max_health
	bar.value = current
	var t := float(current) / float(max(1, max_health))
	if t > 0.5:
		bar.modulate = Color(0.4, 0.9, 0.4)
	elif t > 0.2:
		bar.modulate = Color(0.95, 0.8, 0.3)
	else:
		bar.modulate = Color(0.95, 0.3, 0.3)


func update_score(player_id: int, score: int) -> void:
	if _score_labels.has(player_id):
		_score_labels[player_id].text = str(score)


func show_match_end(winner_id: int) -> void:
	_end_label.text = "Player %d wins!" % winner_id
	_end_overlay.show()
	_end_button.grab_focus()

func toggle_pause_screen() -> void:
	_end_label.text = "Game paused"
	if _end_overlay.visible:
		_end_overlay.hide()
	else:
		_end_overlay.show()
		_end_button.grab_focus()

func _on_end_button_pressed() -> void:
	GameManager.go_to_main_menu()
