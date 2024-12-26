@tool
extends Control

var selected_meshes: Array[MeshInstance3D] = []
var preview_visible := true
var blend_distance := 1.0
var smoothing_strength := 0.5

# UI Elements
var mesh_list: ItemList
var blend_distance_slider: HSlider
var smoothing_slider: HSlider
var stitch_button: Button
var preview_button: Button
var reset_button: Button

# Add to stitcher_dock.gd

var mesh_analyzer: MeshAnalyzer
# Add to stitcher_dock.gd

var mesh_stitcher: MeshStitcher

func setup_stitcher() -> void:
	mesh_stitcher = MeshStitcher.new()
	add_child(mesh_stitcher)
	mesh_stitcher.stitch_completed.connect(_on_stitch_completed)
	
func _on_stitch_pressed() -> void:
	if selected_meshes.size() < 2:
		return
		
	var new_mesh = mesh_stitcher.stitch_meshes(
		mesh_analyzer.potential_connections,
		blend_distance,
		smoothing_strength
	)
	
	if new_mesh:
		# Add to scene
		var scene_root = get_tree().get_edited_scene_root()
		scene_root.add_child(new_mesh)
		new_mesh.owner = scene_root
		
		# Clear selection and reset
		_on_reset_pressed()

func _on_stitch_completed(new_mesh: MeshInstance3D) -> void:
	print("Mesh stitching completed: ", new_mesh.name)
	
func _ready() -> void:
	setup_ui()
	setup_analyzer()
	setup_stitcher()  # Add this line

func setup_analyzer() -> void:
	mesh_analyzer = MeshAnalyzer.new()
	add_child(mesh_analyzer)
	mesh_analyzer.connection_points_updated.connect(func(): 
		print("Found %d potential connection points" % mesh_analyzer.potential_connections.size())
	)

func update_selection(meshes: Array) -> void:
	# Create a properly typed array
	selected_meshes.clear()  # Clear our typed array
	for mesh in meshes:
		if mesh is MeshInstance3D:
			selected_meshes.append(mesh)
			
	# Update UI
	mesh_list.clear()
	for mesh in selected_meshes:
		mesh_list.add_item(mesh.name)
	
	if selected_meshes.size() >= 2:
		mesh_analyzer.analyze_meshes(selected_meshes)
	else:
		mesh_analyzer.clear_visualizations()
	
	update_ui_state()
	
func setup_ui() -> void:
	# Main container
	var main_container := VBoxContainer.new()
	main_container.custom_minimum_size = Vector2(250, 0)
	add_child(main_container)
	
	# Title
	var title := Label.new()
	title.text = "Terrain Stitcher"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_constant_override("margin_bottom", 10)
	main_container.add_child(title)
	
	# Selected Meshes Section
	var mesh_section := VBoxContainer.new()
	main_container.add_child(mesh_section)
	
	var mesh_label := Label.new()
	mesh_label.text = "Selected Meshes"
	mesh_section.add_child(mesh_label)
	
	mesh_list = ItemList.new()
	mesh_list.custom_minimum_size = Vector2(0, 100)
	mesh_list.select_mode = ItemList.SELECT_MULTI
	mesh_section.add_child(mesh_list)
	
	# Blend Settings Section
	add_slider_setting(main_container, "Blend Distance", 0.1, 5.0, blend_distance, 
		func(value): blend_distance = value)
	
	add_slider_setting(main_container, "Smoothing Strength", 0.0, 1.0, smoothing_strength,
		func(value): smoothing_strength = value)
	
	# Action Buttons
	var button_container := VBoxContainer.new()
	main_container.add_child(button_container)
	
	stitch_button = Button.new()
	stitch_button.text = "Stitch Meshes"
	stitch_button.pressed.connect(_on_stitch_pressed)
	button_container.add_child(stitch_button)
	
	var horizontal_buttons := HBoxContainer.new()
	button_container.add_child(horizontal_buttons)
	
	preview_button = Button.new()
	preview_button.text = "Hide Preview"
	preview_button.pressed.connect(_on_preview_toggled)
	horizontal_buttons.add_child(preview_button)
	
	reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_on_reset_pressed)
	horizontal_buttons.add_child(reset_button)
	
	update_ui_state()

func add_slider_setting(parent: Control, label_text: String, min_val: float, max_val: float, 
	default_val: float, callback: Callable) -> void:
	var container := VBoxContainer.new()
	parent.add_child(container)
	
	var label := Label.new()
	label.text = label_text
	container.add_child(label)
	
	var slider_container := HBoxContainer.new()
	container.add_child(slider_container)
	
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	slider_container.add_child(slider)
	
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 40
	value_label.text = "%.1f" % default_val
	slider.value_changed.connect(func(val): value_label.text = "%.1f" % val)
	slider_container.add_child(value_label)

func update_ui_state() -> void:
	stitch_button.disabled = selected_meshes.size() < 2
	preview_button.text = "Hide Preview" if preview_visible else "Show Preview"



func _on_preview_toggled() -> void:
	preview_visible = !preview_visible
	update_ui_state()
	# TODO: Implement preview visibility logic

func _on_reset_pressed() -> void:
	selected_meshes.clear()
	blend_distance = 1.0
	smoothing_strength = 0.5
	preview_visible = true
	update_ui_state()
	# TODO: Implement reset logic
