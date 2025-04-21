extends Node

class_name TutorialLevel2Manager

var tutorial_ui
var player
var tutorial_message_system
var game_manager
var player_find_attempts = 0

func _ready():
	# Find the tutorial UI first
	tutorial_ui = get_tree().get_first_node_in_group("tutorial_ui")
	if not tutorial_ui:
		tutorial_ui = find_child("TutorialMessageUI", true, false)
		if not tutorial_ui:
			tutorial_ui = get_node_or_null("/root/tutorial2/TutorialMessageUI")
			if not tutorial_ui:
				tutorial_ui = get_node_or_null("/root/Tutorial2/TutorialMessageUI")
				if not tutorial_ui:
					var root = get_tree().root
					for i in range(root.get_child_count()):
						var node = root.get_child(i)
						if node.has_node("TutorialMessageUI"):
							tutorial_ui = node.get_node("TutorialMessageUI")
							break
	
	tutorial_message_system = tutorial_ui
	print("Found tutorial UI: ", tutorial_ui)
	
	# Set up delayed player finding
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(find_player)
	add_child(timer)
	timer.start()
	
	# Continue with rest of setup
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = find_child("GameManager", true, false)
		if not game_manager:
			game_manager = get_node_or_null("/root/tutorial2/GameManager")
	
	print("Tutorial manager initialized, will find player shortly")
	
	# Connect to game state signals for quota
	if game_manager != null:
		if game_manager.has_signal("team_score_changed"):
			game_manager.team_score_changed.connect(_on_team_score_changed)

func find_player():
	player_find_attempts += 1
	print("Attempting to find player (attempt #", player_find_attempts, ")")
	
	# Try to get the player using various methods
	player = get_tree().get_first_node_in_group("player")
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if not player:
		# Try specific paths
		player = get_node_or_null("/root/tutorial2/players/1")
		if not player:
			player = get_node_or_null("/root/Tutorial2/players/1")
			if not player:
				# Try using a more generic approach
				var players_container = get_node_or_null("/root/tutorial2/players")
				if players_container and players_container.get_child_count() > 0:
					player = players_container.get_child(0)
	
	if player:
		print("Player found: ", player)
		setup_tutorial_system()
	else:
		if player_find_attempts < 3:
			print("Player not found yet, will try again")
		else:
			push_error("Unable to find player after multiple attempts")

func setup_tutorial_system():
	# Now that we have the player, set up the tutorial message system
	if tutorial_message_system != null:
		# Connect to the message_completed signal
		if tutorial_message_system.has_signal("message_completed"):
			tutorial_message_system.message_completed.connect(_on_message_completed)
			print("Successfully connected to message_completed signal")
		else:
			push_error("Tutorial message system does not have message_completed signal")
		
		if player != null:
			tutorial_message_system.player_path = player.get_path()
			print("Set player path to: ", player.get_path())
		else:
			push_error("Cannot set player path: player is null")
			
		# Make sure UI is visible
		if tutorial_message_system.has_method("show_current_message"):
			# Access the message panel safely
			if tutorial_message_system.has_node("MessagePanel"):
				tutorial_message_system.get_node("MessagePanel").visible = true
				print("Made message panel visible")
			
			# Start the tutorial
			tutorial_message_system.show_current_message()
			print("Called show_current_message()")
		else:
			push_error("Tutorial message system missing required methods")
	else:
		push_error("Tutorial message system not found")

func _process(delta):
	# Debug player reference
	if not player and player_find_attempts >= 3:
		find_player()  # Try one more time during gameplay

func _on_message_completed(message_index: int):
	print("Tutorial message completed: ", message_index)
	
	# You can add specific logic for when each message is completed
	match message_index:
		0: # Player interacted with console
			print("Player interacted with console!")
		1: # Player typed help
			print("Player typed help!")
		2: # Player bought coolant
			print("Player bought coolant!")
		3: # Player exited console
			print("Player exited console!")
		4: # Player picked up coolant
			print("Player picked up coolant!")
		5: # Player refueled generator
			print("Player refueled generator!")
		6: # Quota message
			print("Quota message shown")

func _on_team_score_changed(new_score):
	# Only hide the tutorial when quota is actually met
	var quota_met = false
	
	# Logic to determine if quota is met
	if new_score >= 600:  # Set to 600 as per the player.gd message
		quota_met = true
	
	if quota_met and tutorial_message_system != null:
		# If tutorial is complete and quota is met, hide it
		if tutorial_message_system.current_message_index == 6:
			tutorial_message_system.complete_tutorial()

# Optional: Method to skip the tutorial
func skip_tutorial():
	if tutorial_message_system != null and tutorial_message_system.has_method("complete_tutorial"):
		tutorial_message_system.complete_tutorial() 
