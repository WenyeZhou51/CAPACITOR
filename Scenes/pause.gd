extends Control

var paused = false

func _ready() -> void:
	# Set this node to always process, even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure the pause menu also continues processing during pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	self.hide()
func _input(event):
<<<<<<< HEAD
	# Get all players in the 'players' group (defined in player.gd)
	if (get_node("Player") && get_node("Player").using_console):
=======
	var sender_id = get_tree().get_multiplayer().get_unique_id()
	var player = get_tree().get_root().get_node("Level/players/" + str(sender_id))
	# Get all players in the 'players' group (defined in player.gd)
	if (player && player.using_console):
>>>>>>> master
		return
		
	if event.is_action_pressed("Pause"):
		if paused:
<<<<<<< HEAD
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
=======
			resume_game(player)
		else:
			pause_game(player)

func pause_game(player: Player) -> void:
	self.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.set_process(false)
	# Turns off _input(), if you want
	player.set_process_input(false)
	var head = player.get_node("Head")
	head.set_process(false)
	head.set_process_input(false)
	paused = true

func resume_game(player: Player) -> void:
	self.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player.set_process(true)
	player.set_process_input(true)
	var head = player.get_node("Head")
	head.set_process(true)
	head.set_process_input(true)
	paused = false
	
func _on_resume_pressed() -> void:
	var sender_id = get_tree().get_multiplayer().get_unique_id()
	var player = get_tree().get_root().get_node("Level/players/" + str(sender_id))
	resume_game(player)
>>>>>>> master
	
func _on_exit_pressed() -> void:
	get_tree().quit()
