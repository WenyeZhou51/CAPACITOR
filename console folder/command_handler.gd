extends Node

func _ready() -> void:
	get_parent().add_command_module($Console)
	
func on_command_echo(console, args):
	console.push_message(args[0])

func on_command_buy(console, args):
	console.push_message("buying... " + str(args[1]) + " of " + str(args[0]))
	
func on_command_clear(console, args):
	console.clear_output()
