extends Control

var paused = false

func _ready() -> void:
	# Set this node to always process, even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure the pause menu also continues processing during pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	self.hide()
func _input(event):
	# Get all players in the 'players' group (defined in player.gd)
	if (get_node("Player") && get_node("Player").using_console):
		return
		
	if event.is_action_pressed("Pause"):
		if paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	self.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	paused = true

func resume_game() -> void:
	self.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	paused = false
	
func _on_resume_pressed() -> void:
	resume_game()
	
func _on_exit_pressed() -> void:
	get_tree().quit()
