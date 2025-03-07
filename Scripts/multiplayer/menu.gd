extends Node

@onready var music_player = $Music  # Reference the AudioStreamPlayer
@onready var audio_player = $Click  # Reference the AudioStreamPlayer
@onready var audio_player2 = $ReadySound  # Reference the AudioStreamPlayer


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
	$MarginContainer/VBoxContainer/HBoxContainer/START.hide()
	music_player.play(5000)
	
func _on_host_button_pressed() -> void:
	audio_player.play()
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2.hide()
	$MarginContainer/VBoxContainer/HBoxContainer/START.show()
	var ip = get_system_ip()
	var hostField = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Label
	if (ip != ""):
		hostField.text = ip
	else:
		hostField.text = "ERROR HOSTING"
	MultiplayerManager.host_game()
	
func hostMessage(msg: String):
	var hostLog = $MarginContainer/VBoxContainer/HBoxContainer2/hostlog
	if (!hostLog):
		print_debug("ERROR NO HOSTLOG")
	var cur = hostLog.text
	hostLog.text = cur + '\n' + msg
	
	
func _on_join_button_pressed() -> void:
	audio_player.play()
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer.hide()
	var input = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ip_input
	MultiplayerManager.SERVER_IP = input.text
	MultiplayerManager.join_game()
	print_debug("JOIN PRESSED")
	hostMessage("Joined as player " + str(multiplayer.get_unique_id()))
	
	# TODO : CALL MULT MANAGER JOIN GAME WITH IP AS THIS, THEN SEE THAT NO ERROR, ADD A NAME FIELD
	# TODO : MERGE


func _on_button_pressed() -> void:
	audio_player2.play()
	MultiplayerManager.start_game()
