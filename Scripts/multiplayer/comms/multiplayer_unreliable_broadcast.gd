extends Node

@rpc("any_peer", "unreliable", "call_local")
func broadcast_sound(sound: Constants.SOUNDS):
	var player_name = str(multiplayer.get_remote_sender_id());
	var player = get_tree().get_root().get_node("Level/players/" + player_name)
	
	
	
