# terrain_stitcher.gd
# terrain_stitcher.gd
@tool
extends EditorPlugin

var dock: Control = null

func _enter_tree() -> void:
	print("[TerrainStitcher] Plugin entering tree")
	
	if dock:
		print("[TerrainStitcher] Dock already exists, cleaning up")
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
	
	# Create the dock instance
	dock = preload("res://addons/terrain_stitcher/stitcher_dock.tscn").instantiate()
	if not dock:
		push_error("Failed to instantiate dock scene")
		return
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	print("[TerrainStitcher] Dock added to editor dock")
	
	# Connect to selection changes
	var selection = get_editor_interface().get_selection()
	if selection:
		selection.selection_changed.connect(_on_selection_changed)
		print("[TerrainStitcher] Selection signals connected")

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
	print("[TerrainStitcher] Plugin cleanup complete")

func _on_selection_changed() -> void:
	if not dock:
		push_error("Dock not available for selection update")
		return
		
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	var mesh_instances = selection.filter(func(node): return node is MeshInstance3D)
	
	if dock.has_method("update_selection"):
		print("[TerrainStitcher] Selection changed: %d mesh instances found" % mesh_instances.size())
		dock.update_selection(mesh_instances)
	else:
		push_error("Dock missing update_selection method")
