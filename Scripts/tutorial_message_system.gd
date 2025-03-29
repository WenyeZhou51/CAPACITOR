extends Node

class_name TutorialMessageSystem

signal message_completed(index)

@export var message_panel: Panel
@export var message_label: Label

var player_path: NodePath
var player: Node
var current_message_index: int = 0
var player_find_attempts = 0

# Player action tracking
var has_moved: bool = false
var has_picked_up_scrap: bool = false 
var has_sold_scrap: bool = false

# The messages to display in sequence
var messages = [
	"Move with AWSD",
	"Pick up scrap with E",
	"Move to the Fabricator and press E to sell scrap",
	"Meet the quota by turning in all scraps in this room"
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
	
	print("Tutorial Message System ready, finding player shortly")

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
		player = get_node_or_null("/root/tutorial0/players/1") # Adjust path as needed
		if not player:
			player = get_node_or_null("/root/Tutorial0/players/1")
	
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
		0: # Movement tutorial - "Move with AWSD"
			# Check for WASD keys
			if !has_moved:
				var w_pressed = Input.is_action_pressed("Forward")
				var a_pressed = Input.is_action_pressed("Left")
				var s_pressed = Input.is_action_pressed("Back")
				var d_pressed = Input.is_action_pressed("Right")
				
				# Log key states for debugging
				if w_pressed or a_pressed or s_pressed or d_pressed:
					print("Key pressed: W=", w_pressed, " A=", a_pressed, " S=", s_pressed, " D=", d_pressed)
				
				if w_pressed or a_pressed or s_pressed or d_pressed:
					print("Player moved using WASD")
					has_moved = true
					advance_to_next_message()
				
		1: # Scrap pickup tutorial - "Pick up scrap with E"
			# Check for scrap pickup
			if !has_picked_up_scrap:
				var has_scrap = false
				
				# Check inventory status
				if player.get("inventory_count") != null and player.get("inventory_count") > 0:
					has_scrap = true
					print("Detected scrap: inventory_count > 0")
				elif player.get("inv_size") != null and player.get("inv_size") > 0:
					has_scrap = true
					print("Detected scrap: inv_size > 0")
				elif player.get("is_holding") != null and player.get("is_holding"):
					has_scrap = true
					print("Detected scrap: is_holding = true")
				
				if has_scrap:
					print("Player picked up scrap")
					has_picked_up_scrap = true
					advance_to_next_message()
				
		2: # Sell scrap tutorial - "Move to the Fabricator and press E to sell scrap"
			# Check for scrap selling
			if !has_sold_scrap:
				var has_sold = false
				
				# Check if player has sold scrap
				if player.get("has_sold_scrap") != null and player.get("has_sold_scrap"):
					has_sold = true
					print("Detected scrap sale: has_sold_scrap = true")
				# Check if player had scrap but now doesn't
				elif has_picked_up_scrap and ((player.get("inventory_count") != null and player.get("inventory_count") == 0) or 
											  (player.get("inv_size") != null and player.get("inv_size") == 0) or
											  (player.get("is_holding") != null and !player.get("is_holding"))):
					has_sold = true
					print("Detected scrap sale: had scrap but now empty")
				
				if has_sold:
					print("Player sold scrap")
					has_sold_scrap = true
					advance_to_next_message()
				
		3: # Quota message - "Meet the quota by turning in all scraps in this room"
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
