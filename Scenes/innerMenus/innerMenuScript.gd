extends Control



func _on_random_pressed() -> void:
	GameState.set_quota(1000)
	GameState.set_end_scene("res://Scenes/win.tscn")
	MultiplayerManager.switch_map("res://Scenes/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_fixed_pressed() -> void:
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/tutorial_level_0/level_0_complete.tscn")
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_0/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
