extends Control


func _ready() -> void:
	# Set this node to always process, even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure the pause menu also continues processing during pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	self.hide()

func _input(event):
	if event.is_action_pressed("Pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	self.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func resume_game() -> void:
	self.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	
func _on_resume_pressed() -> void:
	resume_game()
	
func _on_exit_pressed() -> void:
	get_tree().quit()
