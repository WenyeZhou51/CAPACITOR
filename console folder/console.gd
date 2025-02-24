extends CSGBox3D

@onready var console_ui = $SubViewport/ConsoleWindow

func _ready():
	add_to_group("console")
	$"Console Interaction Area".add_to_group("console")
	$SubViewport.handle_input_locally = true 
	$SubViewport.gui_disable_input = false
	$SubViewport.gui_embed_subwindows = true
