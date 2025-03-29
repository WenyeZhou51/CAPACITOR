extends Node

class_name TutorialLevel2MessageSystem

signal message_completed(index)

@export var message_panel: Panel
@export var message_label: Label

var player_path: NodePath
var player: Node
var current_message_index: int = 0
var player_find_attempts = 0

# Player action tracking
var has_interacted_with_console: bool = false
var has_typed_help: bool = false
var has_bought_coolant: bool = false
var has_exited_console: bool = false
var has_picked_up_coolant: bool = false
var has_refueled_generator: bool = false

# The messages to display in sequence
var messages = [
	"E to interact with the console",
	"Type help to view console commands",
	"buy a coolant from the console",
	"esc to exit from console",
	"Pick up the coolant",
	"Refuel the generator with coolant to prevent overheating",
	"complete the quota while preventing generator overheat"
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
	
	print("Tutorial Level 2 Message System ready, finding player shortly")

func find_player():
	player_find_attempts += 1
	
	# Try to get the player using the path if set
	if player_path:
		player = get_node_or_null(player_path)
		if player:
			print("Player found via path: ", player)
	
	# If still not found, try using groups
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			print("Player found via group: ", player)
	
	# If still no player, try finding directly in scene tree
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if player:
			print("Player found via first node in group: ", player)
	
	# Try other common names or paths
	if not player:
		player = get_node_or_null("/root/tutorial2/players/1") # Adjust path as needed
		if not player:
			player = get_node_or_null("/root/Tutorial2/players/1")
	
	if player:
		print("Player reference set to: ", player)
	else:
		if player_find_attempts <= 3:
			print("Player not found, will try again")
		else:
			print("Failed to find player after multiple attempts")

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
		0: # "E to interact with the console"
			# Check if player interacted with console
			if !has_interacted_with_console:
				# Check if player is in console mode - this would need proper implementation
				if player.get("in_console_mode") != null and player.get("in_console_mode"):
					print("Player interacted with console")
					has_interacted_with_console = true
					advance_to_next_message()
				
		1: # "Type help to view console commands"
			# Check if player typed help
			if !has_typed_help:
				# This might be tracked in a console manager or similar
				if player.get("has_typed_help") != null and player.get("has_typed_help"):
					print("Player typed help")
					has_typed_help = true
					advance_to_next_message()
				
		2: # "buy a coolant from the console"
			# Check if player bought coolant
			if !has_bought_coolant:
				if player.get("has_bought_coolant") != null and player.get("has_bought_coolant"):
					print("Player bought coolant")
					has_bought_coolant = true
					advance_to_next_message()
				
		3: # "esc to exit from console"
			# Check if player exited console
			if !has_exited_console:
				if player.get("in_console_mode") != null and !player.get("in_console_mode") and has_interacted_with_console:
					print("Player exited console")
					has_exited_console = true
					advance_to_next_message()
				
		4: # "Pick up the coolant"
			# Check if player picked up coolant
			if !has_picked_up_coolant:
				if player.get("has_picked_up_coolant") != null and player.get("has_picked_up_coolant"):
					print("Player picked up coolant")
					has_picked_up_coolant = true
					advance_to_next_message()
				
		5: # "Refuel the generator with coolant to prevent overheating"
			# Check if player refueled generator
			if !has_refueled_generator:
				if player.get("has_refueled_generator") != null and player.get("has_refueled_generator"):
					print("Player refueled generator")
					has_refueled_generator = true
					advance_to_next_message()
				
		6: # "complete the quota while preventing generator overheat"
			# This just displays information, no condition to advance
			pass

# Shows the current message in the UI
func show_current_message():
	print("Showing message at index: ", current_message_index)
	if current_message_index < messages.size():
		if message_label:
			message_label.text = messages[current_message_index]
			# Wait one frame for the label to update its size
			await get_tree().process_frame
			adjust_panel_size()
			
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

# Adjust panel size based on message content
func adjust_panel_size():
	if message_panel and message_label:
		# Get the minimum size needed for the message
		var message_size = message_label.get_minimum_size()
		
		# Add padding for the container
		var panel_width = max(500, message_size.x + 60)  # Minimum width 500px
		var panel_height = message_size.y + 60  # Add padding
		
		# Properly resize the panel while maintaining centering
		# When using anchors_preset 5 (top-center), we need to set the offsets correctly
		message_panel.custom_minimum_size.x = panel_width
		message_panel.size.x = panel_width
		message_panel.size.y = panel_height
		
		# For proper centering with anchor 0.5, we need equal offsets on both sides
		var half_width = panel_width / 2
		message_panel.offset_left = -half_width
		message_panel.offset_right = half_width
		message_panel.position.y = 30
		
		# Force a layout update
		message_panel.queue_redraw()

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