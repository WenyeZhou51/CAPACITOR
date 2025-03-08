extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_next_2_pressed() -> void:
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/win.tscn")
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_2/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_leave_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
