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
	
	# Initialize the first slot's highlight
	var first = grid_container.get_child(0)
	var highlight = first.get_node("Highlight overlay")
	highlight.visible = true

func _ready():
	# Set the text of the label
	
	# Make all highlight overlays invisible initially
	for i in range(grid_container.get_child_count()):
		var slot = grid_container.get_child(i)
		if slot.has_node("Highlight overlay"):
			var highlight = slot.get_node("Highlight overlay")
			highlight.visible = false
			highlight.scale = Vector2(100, 100) / highlight.texture.get_size()
		
		if slot.has_node("slot sprite"):
			var sprite = slot.get_node("slot sprite")
			sprite.scale = Vector2(100, 100) / sprite.texture.get_size()

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
func on_change_ui(idx: int, item: String, price: int):
	# Changed to swapping the texture of the inventory slot instead
	var slot = grid_container.get_child(idx)
	var sprite = slot.get_node("slot sprite")
	var newTexture: Texture2D
	var nameTag = slot.get_node("name")
	var priceTag = slot.get_node("price")
	#var new_scene: PackedScene
	if(item == "empty"):
		newTexture = load("res://imgs/Slot.png")
		sprite.texture = newTexture
		nameTag.text = ""
		priceTag.text = ""
	elif(item == "flashlight"):
		newTexture = load("res://imgs/Flash.png")
		sprite.texture = newTexture
		nameTag.text = item
		priceTag.text = str(price)
	elif(item == "coolant"):
		newTexture = load("res://imgs/Coolant.png")
		sprite.texture = newTexture
		nameTag.text = item
		priceTag.text = str(price)
	else:
		newTexture = load("res://imgs/Scrap.png")
		sprite.texture = newTexture
		print("found nametag: ", nameTag)
		nameTag.text = item
		priceTag.text = str(price)
		#show_text(item)
	
	# Set the sprite size to 100x100 pixels
	sprite.scale = Vector2(100, 100) / sprite.texture.get_size()
		
	# change UI has been disabled for now
	#swap_UI(idx, new_scene)

func update_highlight(previous_idx: int, curr_idx: int, name: String):
	if(previous_idx == curr_idx):
		return  # No need to update if selection hasn't changed
	print("checkpoint")
	
	if (previous_idx == -1):
		var t1 = (curr_idx - 1 + 4) % 4
		var t2 = (curr_idx + 1 + 4) % 4
		var old_child = grid_container.get_child(t1)
		var old_child2 = grid_container.get_child(t2)
		
		# Only hide the highlight overlays, not the entire slot
		old_child.get_node("Highlight overlay").visible = false
		old_child2.get_node("Highlight overlay").visible = false
	else:
		var old_child = grid_container.get_child(previous_idx)
		
		# Only hide the highlight overlay, not the entire slot
		old_child.get_node("Highlight overlay").visible = false
	
	var curr_child = grid_container.get_child(curr_idx)
	
	# Make highlight overlay visible for current selection
	var highlight = curr_child.get_node("Highlight overlay")
	highlight.visible = true

func show_text(popup_text: String):
	var label = get_node("Label3")
	label.text = popup_text
	label.modulate = Color(1, 1, 1, 1)
