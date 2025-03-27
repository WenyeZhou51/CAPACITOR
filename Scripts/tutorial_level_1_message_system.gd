extends Node

class_name TutorialLevel1MessageSystem

signal message_completed(index)

@export var message_panel: Panel
@export var message_label: Label

var player_path: NodePath
var player: Node
var current_message_index: int = 0
var player_find_attempts = 0

# Player action tracking
var has_dropped_item: bool = false
var has_picked_up_flashlight: bool = false 
var has_toggled_flashlight: bool = false
var has_sprinted: bool = false

# The messages to display in sequence
var messages = [
	"Q to drop item",
	"Pick up flashlight",
	"Click to turn on flashlight",
	"Shift to sprint. Sprint past the dark hall",
	"Turn in scrap and meet your quota"
]

func _ready():
	# Add to group for easy finding
	add_to_group("tutorial_ui")
	
	# Initialize the message panel and label if not set
	if not message_panel and has_node("MessagePanel"):
		message_panel = get_node("MessagePanel")
	
	if not message_label and message_panel and message_panel.has_node("VBoxContainer/MessageLabel"):
		message_label = message_panel.get_node("VBoxContainer/MessageLabel")
	
	# Delayed player finding
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(find_player)
	add_child(timer)
	timer.start()
	
	# Start with first message
	show_current_message()
	
	print("Tutorial Level 1 Message System ready, finding player shortly")

func find_player():
	print("TutorialLevel1MessageSystem attempting to find player...")
	player_find_attempts += 1
	
	if player_path:
		player = get_node_or_null(player_path)
		if player:
			print("Found player via player_path: ", player.get_path())
			return
	
	# Try every possible way to find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("players")
	if not player:
		# Try direct scene paths
		player = get_node_or_null("/root/tutorial1/Player")
		if not player:
			player = get_node_or_null("/root/Tutorial1/Player")
			if not player:
				# Try looking through the whole tree to find the Player
				var root = get_tree().root
				for i in range(root.get_child_count()):
					var scene = root.get_child(i)
					if scene.has_node("Player"):
						player = scene.get_node("Player")
						break
	
	print("Player find result in TutorialLevel1MessageSystem: ", player)
	
	if player:
		print("Found player: ", player.name, " at path: ", player.get_path())
	elif player_find_attempts < 3:
		# Try again after a delay
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.one_shot = true
		timer.timeout.connect(find_player)
		add_child(timer)
		timer.start()
		print("Will try again to find player in 1 second")
	else:
		push_error("Failed to find player after multiple attempts")

func _process(delta):
	# If player not found yet, keep trying
	if not player and player_find_attempts < 3:
		find_player()
		return
		
	# Make sure we have a valid player before checking input
	if not player:
		return
		
	# Check for actions based on the current message
	match current_message_index:
		0: # "Q to drop item" - Check for Q key press and item dropping
			if !has_dropped_item:
				# Check if Q key is pressed
				var q_pressed = Input.is_action_just_pressed("Drop")
				
				if q_pressed:
					print("Q key pressed for dropping item")
					# Wait a short time to verify item was dropped
					await get_tree().create_timer(0.1).timeout
					
					# Check if player dropped something
					if player.get("is_holding") != null and !player.get("is_holding"):
						has_dropped_item = true
						print("Player dropped an item")
						advance_to_next_message()
				
		1: # "Pick up flashlight" - Check for flashlight pickup
			if !has_picked_up_flashlight:
				# Check player's inventory for a flashlight
				var inventory = player.get("inventory")
				if inventory != null:
					print("Player inventory: ", inventory)
					
					# Look through all inventory slots for a flashlight
					for slot_item in inventory:
						if slot_item != null:
							print("Checking item in inventory: ", slot_item)
							
							# Check if item type is flashlight
							if slot_item.get("type") == "flashlight":
								has_picked_up_flashlight = true
								print("Player has flashlight in inventory")
								advance_to_next_message()
								break
							
							# Check if item has a flashlight in its name
							if "flash" in str(slot_item).to_lower() or "light" in str(slot_item).to_lower():
								has_picked_up_flashlight = true
								print("Player has something that seems to be a flashlight")
								advance_to_next_message()
								break
				
				# Check if current slot has a flashlight
				var current_slot = player.get("current_slot")
				if current_slot != null and inventory != null and current_slot < inventory.size():
					var current_item = inventory[current_slot]
					if current_item != null:
						print("Current item: ", current_item)
						if current_item.get("type") == "flashlight":
							has_picked_up_flashlight = true
							print("Player has flashlight in current slot")
							advance_to_next_message()
				
		2: # "Click to turn on flashlight" - Check for mouse click to toggle flashlight
			if !has_toggled_flashlight:
				# Check for mouse click
				var mouse_clicked = Input.is_action_just_pressed("Use")
				
				if mouse_clicked:
					print("Mouse clicked, checking if flashlight toggled")
					
					# Check player's inventory for a flashlight that might be toggled
					var inventory = player.get("inventory")
					var current_slot = player.get("current_slot")
					
					if inventory != null and current_slot != null and current_slot < inventory.size():
						var current_item = inventory[current_slot]
						if current_item != null and current_item.get("type") == "flashlight":
							print("Player clicked with a flashlight equipped")
							has_toggled_flashlight = true
							advance_to_next_message()
				
		3: # "Shift to sprint. Sprint past the dark hall" - Check for shift key and sprinting
			if !has_sprinted:
				# Check for shift key press
				var shift_pressed = Input.is_action_pressed("Sprint")
				
				if shift_pressed:
					print("Shift pressed for sprinting")
					# Check if player is actually moving while sprinting
					var is_moving = false
					
					if player.get("velocity") != null:
						var velocity = player.get("velocity")
						if velocity.length() > 0:
							is_moving = true
					
					if is_moving:
						has_sprinted = true
						print("Player sprinted")
						advance_to_next_message()
				
		4: # "Turn in scrap and meet your quota" - No condition, just informational
			# This message stays visible until the end of the tutorial or quota is met
			pass

# Shows the current message in the UI
func show_current_message():
	print("Showing message at index: ", current_message_index)
	if current_message_index < messages.size():
		if message_label:
			message_label.text = messages[current_message_index]
		if message_panel:
			message_panel.visible = true
	else:
		# Hide the UI when we're done
		if message_panel:
			message_panel.visible = false

# Force display of a specific message
func show_message(index: int):
	if index >= 0 and index < messages.size():
		current_message_index = index
		show_current_message()

# Advances to the next message and emits a signal
func advance_to_next_message():
	print("Advancing from message index: ", current_message_index)
	emit_signal("message_completed", current_message_index)
	current_message_index += 1
	
	if current_message_index < messages.size():
		show_current_message()
	else:
		# Tutorial is complete
		complete_tutorial()
		print("Tutorial completed")

# Get the current message index
func get_current_message_index() -> int:
	return current_message_index

# Marks the tutorial as complete and hides the UI
func complete_tutorial():
	if message_panel:
		message_panel.visible = false
	print("Tutorial complete!") 
