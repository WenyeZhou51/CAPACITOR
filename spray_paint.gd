extends Pickapable  # Inherits from base class

class_name SprayPaint_Class

@onready var spray_particles: GPUParticles3D = $Model/SprayParticles
@export var spray_sound: AudioStreamPlayer
@export var spray_duration: float = 1.0  # Increase duration for better testing
@export_range(1.0, 20.0, 0.5) var spray_distance: float = 5.0  # Default to 5 meters, adjustable in inspector
@export var paint_color: Color = Color(0.501961, 0, 1, 1)  # Purple color
@export var allowed_layers: int = 1  # Default to layer 1 (walls and floors)

var is_spraying: bool = false
var spray_timer: float = 0.0
var current_player: Node = null

func _ready() -> void:
	print("[Spray debug] SprayPaint initialized")
	if spray_particles:
		spray_particles.emitting = false
		print("[Spray debug] Found spray_particles: " + str(spray_particles))
	else:
		print("[Spray debug] ERROR: spray_particles is null!")
		# Try to find it manually
		spray_particles = get_node_or_null("Model/SprayParticles")
		if spray_particles:
			print("[Spray debug] Found spray_particles through manual search")
		else:
			print("[Spray debug] Failed to find particles even through manual search")
			# Show all child nodes for debugging
			print("[Spray debug] Child nodes: " + str(get_children()))
			var model = get_node_or_null("Model")
			if model:
				print("[Spray debug] Model children: " + str(model.get_children()))
	
	# Get the AudioStreamPlayer if not provided via export
	if not spray_sound:
		spray_sound = $AudioStreamPlayer
		if spray_sound:
			print("[Spray debug] Found AudioStreamPlayer")
			if spray_sound.stream:
				print("[Spray debug] AudioStreamPlayer has stream")
			else:
				print("[Spray debug] ERROR: AudioStreamPlayer has no stream!")
		else:
			print("[Spray debug] ERROR: AudioStreamPlayer not found!")

func _process(delta: float) -> void:
	if is_spraying:
		spray_timer += delta
		if current_player:
			# Cast ray and create paint on surfaces
			_spray_paint(current_player)
			
		if spray_timer >= spray_duration:
			print("[Spray debug] Stopping spray after duration: " + str(spray_duration))
			stop_spray()

func use(player: Node) -> void:
	print("[Spray debug] use() called by player")
	current_player = player
	start_spray()
	if spray_sound and spray_sound.stream:
		spray_sound.play()
		print("[Spray debug] Playing sound")
	else:
		print("[Spray debug] Cannot play sound - spray_sound: " + str(spray_sound))

func start_spray() -> void:
	print("[Spray debug] Starting spray")
	is_spraying = true
	spray_timer = 0.0
	if spray_particles:
		# Force restart the particles
		spray_particles.emitting = false
		spray_particles.restart()
		spray_particles.emitting = true
		print("[Spray debug] Particles emitting set to true")
	else:
		print("[Spray debug] ERROR: Cannot emit particles - spray_particles is null")
	
func stop_spray() -> void:
	print("[Spray debug] Stopping spray")
	is_spraying = false
	current_player = null
	if spray_particles:
		spray_particles.emitting = false
		print("[Spray debug] Particles emitting set to false")
	else:
		print("[Spray debug] ERROR: Cannot stop particles - spray_particles is null")

func _spray_paint(player: Node) -> void:
	# Get the camera for raycast
	var camera = player.get_node("Head/Camera3D")
	if not camera:
		print("[Spray debug] ERROR: No camera found for raycast")
		return
	
	# Perform raycast from camera
	var space_state = player.get_world_3d().direct_space_state
	var ray_origin = camera.global_position
	var ray_end = ray_origin + camera.global_transform.basis.z * -spray_distance
	
	# Create physics raycast query
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [player]
	query.collision_mask = allowed_layers  # Only collide with allowed layers (walls/floors)
	var result = space_state.intersect_ray(query)
	
	if result:
		print("[Spray debug] Hit object: " + str(result.collider.name) + " at " + str(result.position))
		# Check if this is a sprayable surface (wall or floor)
		if _is_sprayable_surface(result.collider):
			# Create paint decal
			var paint = _create_paint_decal(result.position, result.normal)
			
			# Add to the world
			var world = player.get_tree().current_scene
			world.add_child(paint)
		else:
			print("[Spray debug] Surface not sprayable: " + str(result.collider.name))

func _is_sprayable_surface(object: Object) -> bool:
	# Only allow spraypaint on walls and floors, not on doors or props
	
	# Check if it's explicitly a door or prop (reject these)
	if "door" in object.name.to_lower() or "prop" in object.name.to_lower():
		print("[Spray debug] Not sprayable: door or prop detected")
		return false
		
	# Only allow if it's a wall or floor
	if "wall" in object.name.to_lower() or "floor" in object.name.to_lower() or "ceiling" in object.name.to_lower():
		print("[Spray debug] Sprayable surface detected based on name")
		return true
	
	# Additional check for static level geometry that might be walls/floors but not named as such
	# We only allow specific object types that are likely to be walls/floors
	if (object is StaticBody3D or object is CSGShape3D) and not ("door" in object.get_parent().name.to_lower() or "prop" in object.get_parent().name.to_lower()):
		# Extra check - if this has a parent with "door" or "prop" in the name, reject it
		print("[Spray debug] Sprayable static geometry detected")
		return true
	
	# If we reach here, it's not a sprayable surface
	print("[Spray debug] Not a sprayable surface")
	return false

func _create_paint_decal(position: Vector3, normal: Vector3) -> Node3D:
	print("[Spray debug] Creating paint decal at " + str(position))
	
	# Create simple mesh to represent the paint
	var paint = Node3D.new()
	paint.name = "PaintDecal"
	
	# Create a mesh instance for the paint splash
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PaintMesh"
	
	# Create a simple quad mesh for the paint
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(0.2, 0.2)
	mesh_instance.mesh = plane_mesh
	
	# Create material for the paint
	var material = StandardMaterial3D.new()
	material.albedo_color = paint_color
	material.emission_enabled = true
	material.emission = paint_color
	material.emission_energy_multiplier = 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	
	# Add to the decal node
	paint.add_child(mesh_instance)
	
	# Position and orient the paint decal
	paint.global_position = position + normal * 0.01  # Slight offset to prevent z-fighting
	
	# Make the paint face the normal direction
	if normal != Vector3.UP and normal != Vector3.DOWN:
		paint.look_at(position + normal, Vector3.UP)
	else:
		# Special case for floor/ceiling
		paint.look_at(position + normal, Vector3.FORWARD)
	
	# Rotate the quad to be flat against the surface
	mesh_instance.rotation_degrees.x = 90
	
	# Add random rotation to make each splash look different
	paint.rotate(normal, randf() * TAU)
	
	return paint 
