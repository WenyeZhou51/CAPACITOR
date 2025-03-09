extends Node


func request_team_score_update(val: int):
	MultiplayerConfirm.confirm_team_score_update.rpc_id(1, val)
	
func request_item_interact(item_name: String):
	MultiplayerConfirm.confirm_item_interact.rpc_id(1, item_name)
	
func request_flash_toggle(item_name: String):
	MultiplayerConfirm.confirm_flash_toggle.rpc_id(1, item_name)

func request_item_drop():
	MultiplayerConfirm.confirm_item_drop.rpc_id(1)

func request_inventory_idx_change(idx: int):
	MultiplayerConfirm.confirm_inventory_idx_change.rpc_id(1, idx)

func request_item_spawn(item: Constants.ITEMS, position: Transform3D):
	MultiplayerConfirm.confirm_item_spawn.rpc_id(1, item, position)
