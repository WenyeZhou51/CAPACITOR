extends Node

@rpc("any_peer", "call_local")
func confirm_team_score_update(val: int):
	var new_score = GameState.get_team_score() + val;
	MultiplayerPropogate.propogate_team_score_update.rpc(new_score)

@rpc("any_peer", "call_local")
func confirm_item_interact(item_name: String):
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_item_interact.rpc(player_name, item_name)
	
@rpc("any_peer", "call_local")
func confirm_flash_toggle(item_name: String):
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_flash_toggle.rpc(player_name, item_name)

@rpc("any_peer", "call_local")
func confirm_changeHolding():
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.changeHolding.rpc(player_name)
	
@rpc("any_peer", "call_local")
func confirm_current_slot(new_slot: int):
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().get_root().get_node("Level/players/" + str(sender_id))
	if player:
		player.current_slot = new_slot
		MultiplayerPropogate.propagate_current_slot.rpc(sender_id, new_slot)

@rpc("any_peer", "call_local")
func confirm_item_drop():
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_item_drop.rpc(player_name)

@rpc("any_peer", "call_local")
func confirm_player_dead():
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_player_dead.rpc(player_name)
