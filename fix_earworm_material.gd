@tool
extends EditorScript

func _run():
	# Load the earworm scene
	var earworm_scene = load("res://Scenes/prefabs/enemies/enemy_earworm.tscn")
	if not earworm_scene:
		print("Failed to load earworm scene")
		return
	
	# Instance the scene to modify it
	var earworm_instance = earworm_scene.instantiate()
	
	# Get the earworm model
	var earworm_model = earworm_instance.get_node("EarwormModel")
	if not earworm_model:
		print("Failed to find EarwormModel node")
		earworm_instance.queue_free()
		return
	
	# Find all mesh instances in the model
	var mesh_instances = []
	find_mesh_instances(earworm_model, mesh_instances)
	
	if mesh_instances.size() == 0:
		print("No mesh instances found in the earworm model")
		earworm_instance.queue_free()
		return
	
	print("Found " + str(mesh_instances.size()) + " mesh instances")
	
	# Apply lighting-responsive material to each mesh
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			print("Processing mesh: " + mesh_instance.name)
			
			# Create a new StandardMaterial3D
			var material = StandardMaterial3D.new()
			
			# Get the existing material if any
			var existing_material = null
			if mesh_instance.get_surface_override_material_count() > 0:
				existing_material = mesh_instance.get_surface_override_material(0)
			elif mesh_instance.mesh.get_surface_count() > 0 and mesh_instance.mesh.surface_get_material(0):
				existing_material = mesh_instance.mesh.surface_get_material(0)
			
			# Copy properties from existing material if possible
			if existing_material and existing_material is StandardMaterial3D:
				if existing_material.albedo_texture:
					material.albedo_texture = existing_material.albedo_texture
				material.albedo_color = existing_material.albedo_color
			
			# Configure the material to respond to lighting
			material.roughness = 0.7
			material.metallic = 0.0
			material.emission_enabled = false
			
			# Apply the material
			mesh_instance.material_override = material
			print("Applied lighting-responsive material to " + mesh_instance.name)
	
	# Save the modified scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(earworm_instance)
	
	var error = ResourceSaver.save(packed_scene, "res://Scenes/prefabs/enemies/enemy_earworm.tscn")
	if error != OK:
		print("Failed to save modified scene: " + str(error))
	else:
		print("Successfully saved modified earworm scene")
	
	# Clean up
	earworm_instance.queue_free()

# Helper function to find all mesh instances in a node hierarchy
func find_mesh_instances(node, result_array):
	if node is MeshInstance3D:
		result_array.append(node)
	
	for child in node.get_children():
		find_mesh_instances(child, result_array) 