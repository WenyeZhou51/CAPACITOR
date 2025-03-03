extends Control

@export var text: String = "Default Text"  # Text to display in the popup
@onready var label: Label = $Label2  # Reference to the Label node
@onready var player 
@onready var grid_container = $ninepatch/GridContainer
# var quota = 600 // REPLACED WITH QUOTA FROM MULT MANAGER

@rpc("authority")
func setup_player(name: String):
	print_debug("ui setup player " + name)
	player = get_parent().get_node("players/" + name)
	if (not player == null):
		print_debug("player " + name + " found in ui")
	label.text = str(GameState.get_quota())
	GameState.team_score_changed.connect(on_value_changed)
	GameState.change_ui.connect(on_change_ui)
	player.inv_high.connect(update_highlight)
	var first = grid_container.get_child(0)
	first.self_modulate = Color(1,1,1,1)

func _ready():
	# Set the text of the label
	pass

func on_value_changed(val: int):
	#print("signal recieved")
	label.text = str(GameState.get_quota() - val)
	
func swap_UI(idx: int, new_scene: PackedScene):
	var old_child = grid_container.get_child(idx)
	grid_container.remove_child(old_child)
	old_child.queue_free()

	var new_instance = new_scene.instantiate()
	new_instance.self_modulate = Color(1,1,1,1)

	# Add the new instance and move it to the correct index
	grid_container.add_child(new_instance)
	grid_container.move_child(new_instance, idx)

func on_change_ui(idx: int, item: String):
	var new_scene: PackedScene
	if(item == "empty"):
		new_scene = load("res://imgs/inv_slot_ui.tscn")
		show_text("")
	elif(item == "flashlight"):
		new_scene = load("res://imgs/flash_slot.tscn")
		show_text(item)
	elif(item == "coolant"):
		new_scene = load("res://imgs/coolant_slot.tscn")
		show_text(item)
	else:
		new_scene = load("res://imgs/scrap_slot.tscn")
		show_text(item)
	swap_UI(idx, new_scene)

func update_highlight(previous_idx: int, curr_idx: int, name: String):
	if(previous_idx == curr_idx):
		return  # No need to update if selection hasn't changed
	print("checkpoint")
	
	if (previous_idx == -1):
		var t1 = (curr_idx - 1 + 4) % 4
		var t2 = (curr_idx + 1 + 4) % 4
		var old_child = grid_container.get_child(t1)
		var old_child2 = grid_container.get_child(t2)
		old_child.self_modulate = Color(0, 0, 0, 0)
		old_child2.self_modulate = Color(0, 0, 0, 0)
	else:
		var old_child = grid_container.get_child(previous_idx)
		old_child.self_modulate = Color(0, 0, 0, 0)
	
	var curr_child = grid_container.get_child(curr_idx)
	curr_child.self_modulate = Color(1,1,1,1)

func show_text(popup_text: String):
	var label = get_node("Label3")
	label.text = popup_text
	label.modulate = Color(1, 1, 1, 1)
