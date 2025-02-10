extends Node


func get_system_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Only consider IPv4 addresses 
		if "." in addr and not addr.begins_with("127.") and not addr.begins_with("169.254."): 
			print_debug("ADDR IP FOUND: ", addr)
			return addr
	return ""

func _ready() -> void:
	pass
	
func _on_host_button_pressed() -> void:
	var ip = get_system_ip()
	var hostField = $MarginContainer/HBoxContainer/VBoxContainer/Label
	if (ip != ""):
		hostField.text = ip
	else:
		hostField.text = "ERROR HOSTING"
	MultiplayerManager.host_game()
	
func _on_join_button_pressed() -> void:
	var input = $MarginContainer/HBoxContainer/VBoxContainer2/ip_input
	MultiplayerManager.SERVER_IP = input.text
	MultiplayerManager.join_game()
	print_debug("JOIN PRESSED")
	
	# TODO : CALL MULT MANAGER JOIN GAME WITH IP AS THIS, THEN SEE THAT NO ERROR, ADD A NAME FIELD
	# TODO : MERGE


func _on_button_pressed() -> void:
	MultiplayerManager.start_game()
