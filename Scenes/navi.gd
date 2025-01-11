extends NavigationRegion3D

func _on_DungeonGenerator_dungeon_done_generating():
	# Ensure the NavigationRegion3D has a NavigationMesh assigned
	var navmesh = self.navmesh
	if navmesh == null:
		print("Error: No NavigationMesh assigned to this NavigationRegion3D!")
		return

	# Get the region's RID
	var region_rid = self.get_region_rid()
	if region_rid == RID():
		print("Error: Failed to retrieve region RID!")
		return

	# Assign the NavigationMesh to the region using NavigationServer3D
	NavigationServer3D.region_set_navigation_mesh(region_rid, navmesh)
	print("Navigation mesh successfully updated for this region!")
