extends Node

var has_join: bool = false
var state = 0
var status_update_timer: Timer

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
	state = 0
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.hide()
	MultiplayerManager.host_msg.connect(hostMessage)
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input.hide()
	
	# Setup status update timer
	status_update_timer = Timer.new()
	status_update_timer.wait_time = 1.0
	status_update_timer.timeout.connect(_update_connection_status)
	add_child(status_update_timer)
	status_update_timer.start()
	
	# Check if we should auto-start the game (for tutorials)
	if GameState.should_auto_start():
		print_debug("Auto-starting game for tutorial")
		# Auto-host the game
		_on_host_button_pressed()
		# Wait a frame to ensure hosting is complete
		await get_tree().process_frame
		# Auto-start the game
		_on_button_pressed()
		# Reset the auto-start flag
		GameState.set_auto_start(false)

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
		
func _on_host_button_pressed() -> void:
	click_good.play()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.show()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/join_button.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.show()
	
	# Get user-entered name
	MultiplayerManager.player_username = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.text
	
	# Start hosting
	MultiplayerManager.host_game()
	
	# We'll let the UPnP process handle displaying the external IP
	# but show the local IP as a fallback
	var local_ip = get_system_ip()
	var hostField = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/Label
	if local_ip != "":
		hostField.text = "Local IP: " + local_ip
	else:
		hostField.text = "Local IP unknown"
		
	has_join = true
	
func hostMessage(msg: String):
	click_join.play()
	var hostLog = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer2/hostlog
	if (!hostLog):
		print_debug("ERROR NO HOSTLOG")
		return
		
	var cur = hostLog.text
	if cur.length() > 0:
		hostLog.text = cur + '\n' + msg
	else:
		hostLog.text = msg
	
	# Labels don't have scrollbars, so we can't auto-scroll

func _on_join_button_pressed() -> void:
	click_good.play()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input.show()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/host_button.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.show()
	var input = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/ip_input
	
	if state == 0:
		state = 1
		return
	
	# Validate IP address format
	var ip_text = input.text.strip_edges()
	if ip_text.is_empty():
		hostMessage("Error: Please enter an IP address")
		return
		
	# Save username and IP
	MultiplayerManager.player_username = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.text
	MultiplayerManager.SERVER_IP = ip_text
	
	# Try to join
	MultiplayerManager.join_game()
	print_debug("JOIN PRESSED")
	hostMessage("Connecting to server at " + ip_text + "...")
	has_join = true

func _on_button_pressed() -> void:
	click_good.play()
	MultiplayerManager.player_username = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/NAME.text
	MultiplayerManager.start_game()

func _on_back_multi_pressed() -> void:
	click_back.play()
	
	# Clean up any active connections before returning to main menu
	if MultiplayerManager.network_status != "Not connected":
		if multiplayer.is_server():
			MultiplayerManager.kick_everyone()
		else:
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.close()
	
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Clean up network resources on exit
		if MultiplayerManager.network_status != "Not connected":
			if multiplayer.is_server():
				MultiplayerManager.kick_everyone()
			else:
				if multiplayer.multiplayer_peer:
					multiplayer.multiplayer_peer.close()
