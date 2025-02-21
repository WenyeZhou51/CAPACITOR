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
	MultiplayerPropogate.propogate_flash_toggle.rpc(item_name)

@rpc("any_peer", "call_local")
func confirm_item_drop():
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_item_drop.rpc(player_name)

@rpc("any_peer", "call_local")
func confirm_player_dead():
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_player_dead.rpc(player_name)
