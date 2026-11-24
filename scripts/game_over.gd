extends Node2D

@onready var game_over: AudioStreamPlayer2D = $GameOver

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_over.play()
	var result: Dictionary = SceneTransition.pending_data.get("loss", {})
	SceneTransition.pending_data.erase("loss")
	if not result.is_empty():
		$header.text = "OUT OF FUEL" if result.reason == "no_time" else "HULL LOST"
		$header.add_theme_font_size_override("font_size", 68)
		$Label.set_offsets_preset(Control.PRESET_TOP_WIDE)
		$Label.position = Vector2(0, 345)
		$Label.size = Vector2(1280, 62)
		$Label.add_theme_font_size_override("font_size", 26)
		$Label.text = "Score %06d   /   Chase %d%%   /   Locks %d of 3\nTry again?" % [result.score, result.progress, result.locks]
	$YesButton.grab_focus()

func _on_yes_button_pressed() -> void:
	SceneTransition.goto_scene("res://Worlds/World1.tscn")
	

func _on_no_button_pressed() -> void:
	SceneTransition.goto_scene("res://Objects/MainMenu.tscn")
