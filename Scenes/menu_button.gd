extends Button

@export var hover_scale: float = 1.1
@export var normal_scale: float = 1.0
@export var transition_duration: float = 0.1

var tween: Tween

func _ready():
	# Connect signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Ensure the button starts at normal scale
	scale = Vector2(normal_scale, normal_scale)
	
	# Make button flat with no background
	flat = true
	
	# Disable focus mode to prevent border flashing when clicked
	focus_mode = Control.FOCUS_NONE

func _on_mouse_entered():
	# Cancel any existing animation
	if tween:
		tween.kill()
	
	# Create new animation for scaling up
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2(hover_scale, hover_scale), transition_duration).set_ease(Tween.EASE_OUT)

func _on_mouse_exited():
	# Cancel any existing animation
	if tween:
		tween.kill()
	
	# Create new animation for scaling down
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2(normal_scale, normal_scale), transition_duration).set_ease(Tween.EASE_OUT) 