extends Control

@onready var click_good = $ClickGood # Reference the AudioStreamPlayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_button_pressed() -> void:
	click_good.play()
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
