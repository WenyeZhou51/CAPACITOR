extends Area3D


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		body.near_console = true
		var console_3d = get_parent() # The CSGBox3D with console.gd
		body.console_window = console_3d.console_ui
	
	
	


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		body.near_console = false
		body.console_window = null
