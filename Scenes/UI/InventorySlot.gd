extends Control

var slot_item = null
var item_texture
var is_selected = false

func _ready():
    item_texture = $Sprite2D
    update_slot()

func set_item(item):
    slot_item = item
    update_slot()

func get_item():
    return slot_item

func set_selected(selected):
    is_selected = selected
    update_slot()

func update_slot():
    if slot_item:
        item_texture.texture = slot_item.texture
        item_texture.show()
    else:
        item_texture.hide()
    
    # Instead of applying shader to background, expand the sprite size for highlighting
    if is_selected:
        # Increase the scale of the sprite for highlighting
        item_texture.scale = Vector2(1.2, 1.2) # 20% larger
        # Optional: Add a glow effect or tint
        item_texture.modulate = Color("6eff6e")  # Green tint
    else:
        # Reset to normal size when not selected
        item_texture.scale = Vector2(1.0, 1.0)
        item_texture.modulate = Color(1, 1, 1, 1)  # Reset to normal color 