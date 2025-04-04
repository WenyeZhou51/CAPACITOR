extends Node

var has_join: bool = false

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
	MultiplayerManager.host_msg.connect(hostMessage)
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.hide();
	
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
	
func _on_host_button_pressed() -> void:
	click_good.play()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer2.hide()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/START.show()
	var ip = get_system_ip()
	var hostField = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer/Label
	if (ip != ""):
		hostField.text = ip
	else:
		hostField.text = "ERROR HOSTING"
	has_join = true
	MultiplayerManager.host_game()
	
func hostMessage(msg: String):
	click_join.play()
	var hostLog = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer2/hostlog
	if (!hostLog):
		print_debug("ERROR NO HOSTLOG")
	var cur = hostLog.text
	hostLog.text = cur + '\n' + msg
	
	
func _on_join_button_pressed() -> void:
	click_good.play()
	$MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer.hide()
	var input = $MarginContainer/Control/ColorRect/VBoxContainer/HBoxContainer/VBoxContainer2/ip_input
	MultiplayerManager.SERVER_IP = input.text
	MultiplayerManager.join_game()
	print_debug("JOIN PRESSED")
	hostMessage("Joined as player " + str(multiplayer.get_unique_id()))
	has_join = true
	# TODO : CALL MULT MANAGER JOIN GAME WITH IP AS THIS, THEN SEE THAT NO ERROR, ADD A NAME FIELD
	# TODO : MERGE


func _on_button_pressed() -> void:
	click_good.play()
	MultiplayerManager.start_game()


func _on_back_multi_pressed() -> void:
	click_back.play()
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
