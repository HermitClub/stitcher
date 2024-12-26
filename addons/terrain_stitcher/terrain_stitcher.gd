@tool
extends EditorPlugin

var dock: Control = null

func _enter_tree() -> void:
	print("Plugin entering tree")
	
	# Wait a frame to ensure proper initialization
	await get_tree().process_frame
	
	# Create the dock instance
	dock = preload("res://addons/terrain_stitcher/stitcher_dock.tscn").instantiate()
	if not dock:
		push_error("Failed to instantiate dock scene")
		return
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	# Connect to selection changes AFTER dock is added
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null

func _on_selection_changed() -> void:
	if not dock:
		push_error("Dock not available for selection update")
		return
		
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	# Convert the filtered array to the correct type
	var mesh_instances: Array[MeshInstance3D] = []
	for node in selection:
		if node is MeshInstance3D:
			mesh_instances.append(node)
	
	if dock.has_method("update_selection"):
		dock.update_selection(mesh_instances)
	else:
		push_error("Dock missing update_selection method")
