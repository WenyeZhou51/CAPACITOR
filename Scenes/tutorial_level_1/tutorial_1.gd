extends Control

@onready var click_good = $ClickGood # Reference the AudioStreamPlayer
@onready var click_back = $ClickBack # Reference the AudioStreamPlayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_next_2_pressed() -> void:
	click_good.play()
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/win.tscn")
	#GameState.set_auto_start(true)
	MultiplayerManager.switch_map.rpc("res://Scenes/tutorial_level_2/testscene.tscn")
	MultiplayerManager.start_game()


func _on_leave_2_pressed() -> void:
	click_back.play()
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
