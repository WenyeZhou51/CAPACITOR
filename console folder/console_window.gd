extends PanelContainer

@onready var input_bar: Control = $VBoxContainer/InputBar
@onready var display: Control = $VBoxContainer/ScrollContainer/Display

@export var message_buffer_limit: int = 100

var message_buffer: PackedStringArray = PackedStringArray()
var command_modules: Array = []
func _ready():
	focus_entered.connect(_on_focus)
	mouse_entered.connect(_on_mouse_enter)
	
func _on_focus():
	$VBoxContainer/InputBar.grab_focus()


func _on_mouse_enter():
	$VBoxContainer/InputBar.grab_focus()
func add_command_module(module: CommandModule):
	module.console = self
	command_modules.push_back(module)

func push_message(msg: String):
	message_buffer.append(msg)
	if message_buffer.size() > message_buffer_limit:
		message_buffer.remove_at(0)

	var result = ""
	for i in range(message_buffer.size()):
		if i > 0:
			result += "\n"
		result += message_buffer[i]

	display.bbcode_text = result

func clear_output():
	message_buffer = PackedStringArray()
	display.text = ""

func _gui_input(event: InputEvent) -> void:
	print("receiving gui input on console side")
	if visible and $VBoxContainer/InputBar.has_focus():
		# Handle special keys and accept input
		if event.is_action_pressed("ui_accept"):
			accept_event()
		elif event is InputEventKey:
			accept_event()
	# Remove the get_viewport().push_input(event) line completely

func parse_input(input: String):
	var tokenized = input.split(" ", false, 1)
	if tokenized.size() == 0:
		return

	var command = tokenized[0].to_lower()
	var command_module = null
	for module in command_modules:
		if module.has_command(command):
			command_module = module
			break

	if command_module == null:
		push_message("Syntax Error")
		return

	var args = ""
	if tokenized.size() > 1:
		args = tokenized[1]

	command_module.command_entered(command, args)

func _on_input_bar_text_submitted(text: String):
	input_bar.clear()
	if text.length() == 0:
		return
	parse_input(text)
