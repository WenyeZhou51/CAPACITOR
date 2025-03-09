extends Node


func request_team_score_update(val: int):
	MultiplayerConfirm.confirm_team_score_update.rpc_id(1, val)
	
func request_item_interact(item_name: String):
	MultiplayerConfirm.confirm_item_interact.rpc_id(1, item_name)
	
func request_flash_toggle(item_name: String):
	MultiplayerConfirm.confirm_flash_toggle.rpc_id(1, item_name)

func changeHolding():
	MultiplayerConfirm.confirm_changeHolding.rpc_id(1)
	
func request_item_drop():
	MultiplayerConfirm.confirm_item_drop.rpc_id(1)

func update_current_slot_idx(idx: int):
	MultiplayerConfirm.confirm_current_slot_idx.rpc_id(1, idx)

func disconnect_player():
	MultiplayerConfirm.confirm_disconnect.rpc_id(1)
