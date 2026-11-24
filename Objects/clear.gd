extends Node2D
class_name ClearScene

@onready var time_label: Label = $TimeLabel
var clear_time: float = 0.0
var _leaving: bool = false

func _ready() -> void:
	clear_time = float(SceneTransition.pending_data.get("clear_time", 0.0))
	var score: int = int(SceneTransition.pending_data.get("score", 0))
	var best: int = int(SceneTransition.pending_data.get("best_score", 0))
	var combo: int = int(SceneTransition.pending_data.get("best_combo", 0))
	for key in ["clear_time", "score", "best_score", "best_combo"]:
		SceneTransition.pending_data.erase(key)
	$header.text = "BOUNTY SECURED"
	$header.add_theme_font_size_override("font_size", 66)
	$Label.text = "Score %06d  |  Best %06d" % [score, best]
	$Label.add_theme_font_size_override("font_size", 30)
	var total: int = int(clear_time)
	time_label.text = "Time %02d:%02d  |  Best streak %d" % [int(total / 60.0), total % 60, combo]
	var hint := Label.new()
	hint.text = "ENTER / SPACE: MAIN MENU"
	hint.position = Vector2(0, 515)
	hint.size = Vector2(1280, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 21)
	hint.z_index = 201
	add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if not _leaving and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_leaving = true
		SceneTransition.goto_scene("res://Objects/MainMenu.tscn")
