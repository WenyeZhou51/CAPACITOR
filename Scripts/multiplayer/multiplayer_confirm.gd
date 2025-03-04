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
func confirm_current_slot_idx(idx: int):
	var sender_id = multiplayer.get_remote_sender_id()
	var player_name = str(sender_id)
	# Get the direct player reference and call set_inv_slot immediately for local player
	var player = get_tree().get_root().find_child(player_name, true, false)
	if player and player is Player:
		# Update the slot directly for immediate local response
		player.curSlotUpdating = false  # Reset this immediately to unblock further scrolling
		player.set_inv_slot(idx)
	# Also propagate to all clients to ensure synchronization
	MultiplayerPropogate.propagate_current_slot_idx.rpc(sender_id, idx)
