extends Node

class_name TutorialLevel0Manager

var tutorial_ui
var player
var tutorial_message_system
var game_manager
var player_find_attempts = 0

# For tracking enemies that might become visible
var nearby_enemies = []
var enemy_detection_timer = 0.0
var enemy_detection_interval = 2.0

func _ready():
	# Find the tutorial UI first
	tutorial_ui = get_tree().get_first_node_in_group("tutorial_ui")
	if not tutorial_ui:
		tutorial_ui = find_child("TutorialMessageUI", true, false)
		if not tutorial_ui:
			tutorial_ui = get_node_or_null("/root/tutorial0/TutorialMessageUI")
			if not tutorial_ui:
				tutorial_ui = get_node_or_null("/root/Tutorial0/TutorialMessageUI")
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
			game_manager = get_node_or_null("/root/tutorial0/GameManager")
	
	print("Tutorial manager initialized, will find player shortly")
	
	# Connect to game state signals for quota
	if game_manager != null:
		if game_manager.has_signal("team_score_changed"):
			game_manager.team_score_changed.connect(_on_team_score_changed)

func find_player():
	print("Attempting to find player...")
	player_find_attempts += 1
	
	# Multiple ways to find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("players")
	if not player:
		# Try direct scene paths
		player = get_node_or_null("/root/tutorial0/Player")
		if not player:
			player = get_node_or_null("/root/Tutorial0/Player")
			if not player:
				# Try looking through the whole tree to find the Player
				var root = get_tree().root
				for i in range(root.get_child_count()):
					var scene = root.get_child(i)
					var potential_player = find_player_in_node(scene)
					if potential_player:
						player = potential_player
						break
	
	print("Player find result: ", player)
	
	if player:
		print("Found player: ", player.name, " at path: ", player.get_path())
		setup_tutorial_system()
	elif player_find_attempts < 3:
		# Try again after a delay if we haven't found the player yet
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.one_shot = true
		timer.timeout.connect(find_player)
		add_child(timer)
		timer.start()
		print("Will try again to find player in 1 second")
	else:
		push_error("Failed to find player after multiple attempts")

func find_player_in_node(node):
	# Recursively search for a node named "Player" or with a name containing "Player"
	if node.name == "Player" or "Player" in node.name:
		print("Found player candidate: ", node.name)
		return node
	
	for child in node.get_children():
		var result = find_player_in_node(child)
		if result:
			return result
	
	return null

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
		0: # Player moved
			print("Player has moved!")
		1: # Player jumped
			print("Player has jumped!")
		2: # Player picked up scrap
			print("Player picked up scrap!")
		3: # Player sold scrap
			print("Player sold scrap!")
		4: # Quota message
			print("Quota message shown")

func _on_team_score_changed(new_score):
	# Only hide the tutorial when quota is actually met
	var quota_met = false
	
	# Logic to determine if quota is met
	if new_score >= 600:  # Set to 600 as per the player.gd message
		quota_met = true
	
	if quota_met and tutorial_message_system != null:
		# If tutorial is complete and quota is met, hide it
		if tutorial_message_system.current_message_index == 4:
			tutorial_message_system.complete_tutorial()

# Optional: Method to skip the tutorial
func skip_tutorial():
	if tutorial_message_system != null and tutorial_message_system.has_method("complete_tutorial"):
		tutorial_message_system.complete_tutorial()

func check_for_enemies():
	# This function is no longer needed for the 4 messages
	pass 
