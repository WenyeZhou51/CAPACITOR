extends Node

var has_join: bool = false
var state = 0
var status_update_timer: Timer

# Load the IPEncoder class directly
const IPEncoderClass = preload("res://Scripts/Management/ip_encoder.gd")
var ip_encoder = IPEncoderClass.new()

@onready var click_good = $ClickGood # Reference the AudioStreamPlayer
@onready var click_back = $ClickBack # Reference the AudioStreamPlayer
@onready var click_join = $ClickJoin

func get_system_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Only consider IPv4 addresses 
		if "." in addr and not addr.begins_with("127.") and not addr.begins_with("169.254."): 
			print_debug("ADDR IP FOUND: ", addr)
			return addr
	return ""

func _ready() -> void:
	print("[DEBUG] menu._ready() - Starting menu initialization")
	state = 0
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/room_code_label.hide() # Hide room code label initially
	
	print("[DEBUG] menu._ready() - Connecting to MultiplayerManager.host_msg signal")
	MultiplayerManager.host_msg.connect(hostMessage)
	
	print("[DEBUG] menu._ready() - Connecting to MultiplayerManager.external_ip_obtained signal")
	# Verify the signal exists
	print("[DEBUG] menu._ready() - Signal exists: " + str(MultiplayerManager.has_signal("external_ip_obtained")))
	MultiplayerManager.external_ip_obtained.connect(_on_external_ip_obtained)
	print("[DEBUG] menu._ready() - Signal connection established")
	
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input.hide()
	
	# Setup status update timer
	print("[DEBUG] menu._ready() - Setting up status update timer")
	status_update_timer = Timer.new()
	status_update_timer.wait_time = 1.0
	status_update_timer.timeout.connect(_update_connection_status)
	add_child(status_update_timer)
	status_update_timer.start()
	print("[DEBUG] menu._ready() - Status update timer started")
	
	# Check if we should auto-start the game (for tutorials)
	if GameState.should_auto_start():
		print("[DEBUG] menu._ready() - Auto-starting game for tutorial")
		# Auto-host the game
		_on_host_button_pressed()
		# Wait a frame to ensure hosting is complete
		await get_tree().process_frame
		# Auto-start the game
		_on_button_pressed()
		# Reset the auto-start flag
		GameState.set_auto_start(false)
	
	print("[DEBUG] menu._ready() - Menu initialization complete")

func _update_connection_status():
	var status_label = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer2/connection_status
	if status_label:
		var status = MultiplayerManager.get_network_status()
		status_label.text = "Status: " + status
		
		# Color the status label based on connection state
		match status:
			"Hosting", "Connected":
				status_label.modulate = Color(0, 1, 0) # Green
			"Connecting...":
				status_label.modulate = Color(1, 1, 0) # Yellow
			_:
				status_label.modulate = Color(1, 1, 1) # White
				
		# Show start button only if we're hosting and at least one player is connected
		if status == "Hosting" and has_join:
			$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.visible = true
		
func _on_external_ip_obtained(ip_address: String) -> void:
	print("[DEBUG] menu._on_external_ip_obtained() - Signal received with IP: " + ip_address)
	var hostField = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/Label
	if hostField:
		print("[DEBUG] menu._on_external_ip_obtained() - Label found, updating text")
		# Show the room code label
		$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/room_code_label.show()
		# Just display the code itself, since we now have a label
		hostField.text = ip_address
		hostField.add_theme_font_size_override("font_size", 90) # Make it larger
		print("[DEBUG] menu._on_external_ip_obtained() - Label updated to: " + hostField.text)
	else:
		print("[DEBUG] menu._on_external_ip_obtained() - ERROR: Label not found!")

func _on_host_button_pressed() -> void:
	print("[DEBUG] menu._on_host_button_pressed() - Host button pressed")
	click_good.play()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.show()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/join_button.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/host_button.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.show()
	
	# Get user-entered name
	var username = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.text
	print("[DEBUG] menu._on_host_button_pressed() - Username: " + username)
	MultiplayerManager.player_username = username
	
	# Initial text while waiting for UPnP
	var hostField = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/Label
	if hostField:
		print("[DEBUG] menu._on_host_button_pressed() - Setting label to 'Setting up...'")
		hostField.text = "Setting up..."
	else:
		print("[DEBUG] menu._on_host_button_pressed() - ERROR: Label not found!")
	
	print("[DEBUG] menu._on_host_button_pressed() - Calling MultiplayerManager.host_game()")
	# Start hosting
	MultiplayerManager.host_game()
	print("[DEBUG] menu._on_host_button_pressed() - MultiplayerManager.host_game() completed")
		
	has_join = true
	print("[DEBUG] menu._on_host_button_pressed() - Host button handling complete")

func hostMessage(msg: String):
	click_join.play()
	var hostLog = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer2/hostlog
	if (!hostLog):
		print_debug("ERROR NO HOSTLOG")
		return
	
	# Keep only the most recent messages
	var lines = []
	if hostLog.text.length() > 0:
		lines = hostLog.text.split("\n")
		# Keep only the last 4 messages to avoid clutter
		if lines.size() >= 4:
			lines = lines.slice(-3, lines.size())
	
	# Add the new message
	lines.append(msg)
	
	# Update the log text
	hostLog.text = "\n".join(lines)
	
	# Labels don't have scrollbars, so we can't auto-scroll

func _on_join_button_pressed() -> void:
	print("[DEBUG] menu._on_join_button_pressed() - Join button pressed")
	click_good.play()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input.show()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/host_button.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.show()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/room_code_label.show() # Show the room code label
	var input = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input
	
	if state == 0:
		state = 1
		return
	
	# Get the input text
	var ip_text = input.text.strip_edges()
	if ip_text.is_empty():
		hostMessage("Error: Please enter a Room Code")
		return
		
	# Save username and IP
	MultiplayerManager.player_username = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.text
	MultiplayerManager.SERVER_IP = ip_text
	
	# Try to join
	MultiplayerManager.join_game()
	print_debug("JOIN PRESSED")
	hostMessage("Connecting...")
	has_join = true

func _on_button_pressed() -> void:
	click_good.play()
	MultiplayerManager.player_username = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.text
	MultiplayerManager.start_game()

func _on_back_multi_pressed() -> void:
	print("[DEBUG] menu._on_back_multi_pressed() - Back button pressed")
	print("[DEBUG] menu._on_back_multi_pressed() - Network status: " + MultiplayerManager.network_status)
	print("[DEBUG] menu._on_back_multi_pressed() - Is server: " + str(multiplayer.is_server()))
	print("[DEBUG] menu._on_back_multi_pressed() - Has multiplayer peer: " + str(multiplayer.multiplayer_peer != null))
	
	click_back.play()
	
	# Clean up any active connections before returning to main menu
	if MultiplayerManager.network_status != "Not connected":
		print("[DEBUG] menu._on_back_multi_pressed() - Active connection detected, cleaning up")
		if multiplayer.is_server():
			print("[DEBUG] menu._on_back_multi_pressed() - We are the server, kicking everyone")
			MultiplayerManager.kick_everyone()
		else:
			print("[DEBUG] menu._on_back_multi_pressed() - We are a client, closing connection")
			if multiplayer.multiplayer_peer:
				print("[DEBUG] menu._on_back_multi_pressed() - Closing multiplayer peer")
				multiplayer.multiplayer_peer.close()
			else:
				print("[DEBUG] menu._on_back_multi_pressed() - No multiplayer peer to close")
	else:
		print("[DEBUG] menu._on_back_multi_pressed() - No active connection, nothing to clean up")
	
	print("[DEBUG] menu._on_back_multi_pressed() - Changing scene to Menu.tscn")
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[DEBUG] menu._notification() - Window close request received")
		# Clean up network resources on exit
		if MultiplayerManager.network_status != "Not connected":
			print("[DEBUG] menu._notification() - Active connection detected, cleaning up")
			if multiplayer.is_server():
				print("[DEBUG] menu._notification() - We are the server, kicking everyone")
				MultiplayerManager.kick_everyone()
			else:
				print("[DEBUG] menu._notification() - We are a client, closing connection")
				if multiplayer.multiplayer_peer:
					print("[DEBUG] menu._notification() - Closing multiplayer peer")
					multiplayer.multiplayer_peer.close()
				else:
					print("[DEBUG] menu._notification() - No multiplayer peer to close")
		else:
			print("[DEBUG] menu._notification() - No active connection, nothing to clean up")
