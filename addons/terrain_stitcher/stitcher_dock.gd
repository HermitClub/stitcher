@tool
extends Control

# Core variables
var selected_meshes: Array[MeshInstance3D] = []
var mesh_analyzer: MeshAnalyzer
var mesh_stitcher: MeshStitcher

# Parameter variables
var preview_visible := true
var blend_distance := 1.0
var smoothing_strength := 0.5
var connection_threshold := 1.0
var direction_bias := 0.5
var edge_resolution := 1.0
var show_connection_points := true
var show_blend_zone := true
var show_seam_line := true

# UI Elements
var mesh_list: ItemList
var blend_distance_slider: HSlider
var smoothing_slider: HSlider
var stitch_button: Button
var preview_button: Button
var reset_button: Button
var auto_align_button: Button
var connection_threshold_slider: HSlider
var direction_bias_slider: HSlider
var edge_resolution_slider: HSlider
var show_connections_check: CheckButton
var show_blend_zone_check: CheckButton
var show_seam_line_check: CheckButton

func _ready() -> void:
	setup_ui()
	setup_analyzer()
	setup_stitcher()

func setup_analyzer() -> void:
	mesh_analyzer = MeshAnalyzer.new()
	add_child(mesh_analyzer)
	mesh_analyzer.connection_points_updated.connect(func(): 
		print("Found %d potential connection points" % mesh_analyzer.potential_connections.size())
	)

func setup_stitcher() -> void:
	mesh_stitcher = MeshStitcher.new()
	add_child(mesh_stitcher)
	mesh_stitcher.stitch_completed.connect(_on_stitch_completed)

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
	
	# Alignment Section
	var alignment_section := VBoxContainer.new()
	main_container.add_child(alignment_section)
	
	var alignment_label := Label.new()
	alignment_label.text = "Alignment"
	alignment_section.add_child(alignment_label)
	
	auto_align_button = Button.new()
	auto_align_button.text = "Auto-Align Edges"
	auto_align_button.pressed.connect(_on_auto_align_pressed)
	alignment_section.add_child(auto_align_button)
	
	# Connection Settings Section
	add_slider_setting(main_container, "Connection Threshold", 0.1, 5.0, connection_threshold,
		func(value): 
			connection_threshold = value
			_on_connection_settings_changed()
	)
	
	add_slider_setting(main_container, "Edge Resolution", 0.1, 1.1, edge_resolution,
		func(value): 
			edge_resolution = value
			_on_connection_settings_changed()
	)
	
	add_slider_setting(main_container, "Direction Bias", 0.0, 1.0, direction_bias,
		func(value): 
			direction_bias = value
			_on_connection_settings_changed()
	)
	
	# Blend Settings Section
	add_slider_setting(main_container, "Smoothing Strength", 0.0, 1.0, smoothing_strength,
	func(value): 
		smoothing_strength = value
		_on_blend_settings_changed(),
	0.01  # Much finer control with 0.01 steps
)
	


	
	# Visualization Options Section
	var viz_section := VBoxContainer.new()
	main_container.add_child(viz_section)
	
	var viz_label := Label.new()
	viz_label.text = "Visualization Options"
	viz_section.add_child(viz_label)
	
	show_connections_check = CheckButton.new()
	show_connections_check.text = "Show Connection Points"
	show_connections_check.button_pressed = show_connection_points
	show_connections_check.toggled.connect(func(pressed): 
		show_connection_points = pressed
		_on_visualization_changed()
	)
	viz_section.add_child(show_connections_check)
	
	show_blend_zone_check = CheckButton.new()
	show_blend_zone_check.text = "Show Blend Zone"
	show_blend_zone_check.button_pressed = show_blend_zone
	show_blend_zone_check.toggled.connect(func(pressed): 
		show_blend_zone = pressed
		_on_visualization_changed()
	)
	viz_section.add_child(show_blend_zone_check)
	
	show_seam_line_check = CheckButton.new()
	show_seam_line_check.text = "Show Seam Line"
	show_seam_line_check.button_pressed = show_seam_line
	show_seam_line_check.toggled.connect(func(pressed): 
		show_seam_line = pressed
		_on_visualization_changed()
	)
	viz_section.add_child(show_seam_line_check)
	
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
	default_val: float, callback: Callable, step: float = 0.1) -> void:
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
	slider.step = step  # Add step control
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	slider_container.add_child(slider)
	
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 40
	value_label.text = "%.3f" % default_val  # Show more decimal places
	slider.value_changed.connect(func(val): value_label.text = "%.3f" % val)
	slider_container.add_child(value_label)
	
func update_selection(meshes: Array) -> void:
	selected_meshes.clear()
	for mesh in meshes:
		if mesh is MeshInstance3D:
			selected_meshes.append(mesh)
			
	mesh_list.clear()
	for mesh in selected_meshes:
		mesh_list.add_item(mesh.name)
	
	if selected_meshes.size() >= 2:
		mesh_analyzer.analyze_meshes(selected_meshes)
	else:
		mesh_analyzer.clear_visualizations()
	
	update_ui_state()

func update_ui_state() -> void:
	var has_meshes = selected_meshes.size() >= 2
	stitch_button.disabled = !has_meshes
	auto_align_button.disabled = !has_meshes
	preview_button.text = "Hide Preview" if preview_visible else "Show Preview"

# Event handlers
func _on_auto_align_pressed() -> void:
	if selected_meshes.size() >= 2:
		# TODO: Implement auto-alignment logic
		pass

func _on_connection_settings_changed() -> void:
	if selected_meshes.size() >= 2:
		mesh_analyzer.update_connection_settings(
			connection_threshold,
			edge_resolution,
			direction_bias
		)

func _on_blend_settings_changed() -> void:
	if selected_meshes.size() >= 2:
		mesh_analyzer.update_blend_preview(
			blend_distance,
			smoothing_strength
		)

func _on_visualization_changed() -> void:
	mesh_analyzer.update_visualization(
		show_connection_points,
		show_blend_zone,
		show_seam_line
	)

func _on_preview_toggled() -> void:
	preview_visible = !preview_visible
	update_ui_state()
	mesh_analyzer.set_preview_visible(preview_visible)

func _on_reset_pressed() -> void:
	selected_meshes.clear()
	mesh_list.clear()
	
	# Reset parameters
	blend_distance = 1.0
	smoothing_strength = 0.5
	connection_threshold = 1.0
	direction_bias = 0.5
	edge_resolution = 1.0
	
	# Reset visualization options
	show_connection_points = true
	show_blend_zone = true
	show_seam_line = true
	preview_visible = true
	
	# Update UI elements
	show_connections_check.button_pressed = show_connection_points
	show_blend_zone_check.button_pressed = show_blend_zone
	show_seam_line_check.button_pressed = show_seam_line
	
	# Clear visualizations
	mesh_analyzer.clear_visualizations()
	update_ui_state()

func _on_stitch_pressed() -> void:
	if selected_meshes.size() < 2:
		return
		
	var new_mesh = mesh_stitcher.stitch_meshes(
		mesh_analyzer.potential_connections,
		blend_distance,
		smoothing_strength
	)
	
	if new_mesh:
		var scene_root = get_tree().get_edited_scene_root()
		scene_root.add_child(new_mesh)
		new_mesh.owner = scene_root
		_on_reset_pressed()

func _on_stitch_completed(new_mesh: MeshInstance3D) -> void:
	print("Mesh stitching completed: ", new_mesh.name)
