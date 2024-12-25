extends Node3D


@export var terrain_color := Color(0.2, 0.6, 0.3)
var color_picker: ColorPickerButton
@export var random_height_min := -2.0
@export var random_height_max := 2.0
@export var noise_scale := 50.0


var width_spinbox: SpinBox
var height_spinbox: SpinBox
var random_min_slider: HSlider
var random_max_slider: HSlider
var noise_scale_slider: HSlider

var pending_changes = false
var last_mesh_update = 0.0
var mesh_update_interval = 0.05  # 20 updates per second max
var changes_buffer = []  # Track what vertices changed


func print_scene_info():
	var root = get_tree().get_edited_scene_root()
	print("Scene Debug Info:")
	print("- Root node: ", root.name if root else "None")
	print("- Current scene file: ", root.scene_file_path if root else "None")
	print("- Our parent: ", get_parent().name if get_parent() else "None")


func print_scene_hierarchy():
	print("\nScene Hierarchy Debug:")
	var scene_root = get_tree().get_edited_scene_root()
	print("Scene root: ", scene_root.name if scene_root else "NULL")
	print("Owner: ", owner.name if owner else "NULL")
	print("Parent: ", get_parent().name if get_parent() else "NULL")
	print("Current node: ", name)


func duplicate_terrain_to_scene() -> void:
	# Create a new packed scene
	var packed_scene = PackedScene.new()
	
	# Create a root node for our terrain
	var terrain_container = Node3D.new()
	var timestamp = Time.get_datetime_string_from_system().replace(":", "_")
	terrain_container.name = "TerrainMesh_" + timestamp
	
	# Create the mesh instance with our current terrain
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = terrain_mesh.mesh.duplicate()
	terrain_container.add_child(mesh_instance)
	
	# Add collision if it exists
	if terrain_mesh.has_node("StaticBody3D"):
		var static_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		collision_shape.shape = terrain_mesh.mesh.create_trimesh_shape()
		static_body.add_child(collision_shape)
		mesh_instance.add_child(static_body)
		collision_shape.owner = terrain_container
		static_body.owner = terrain_container
	
	# Set ownership
	mesh_instance.owner = terrain_container
	
	# Pack the scene
	var error = packed_scene.pack(terrain_container)
	if error != OK:
		push_error("Failed to pack scene")
		return
		
	# Save to res:// directory
	var filename = "res://generated_terrains/terrain_%s.tscn" % timestamp
	
	# Make sure the directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("generated_terrains"):
		dir.make_dir("generated_terrains")
	
	# Save the scene file
	error = ResourceSaver.save(packed_scene, filename)
	if error == OK:
		print("Terrain saved successfully to: ", filename)
	else:
		push_error("Failed to save scene file: ", error)
		
		
func print_scene_context():
	print("\nScene Context:")
	print("Our node: ", name)
	print("Our parent: ", get_parent().name if get_parent() else "None")
	print("Scene file: ", scene_file_path if scene_file_path else "None")
	print("Node path: ", get_path())
# Just to help us verify the scene structure
func print_current_tree():
	var parent = get_parent()
	print("\nCurrent Tree Structure:")
	print("- Parent: ", parent.name if parent else "None")
	for child in parent.get_children():
		print("  - Child: ", child.name)
		if child == self:
			print("    (This is us!)")
	# Get scene references - ensure we're calling this after _ready
	if not is_inside_tree():
		push_error("Node not in scene tree!")
		return null
		
	# Get root using owner which should be valid if we're properly instanced
	var scene_root = owner
	if not scene_root:
		push_error("No owner found - are we properly instanced?")
		return null
		
	print("DEBUG - Owner found: ", scene_root.name)
	print("DEBUG - Our name: ", name)
	print("DEBUG - Our parent: ", get_parent().name if get_parent() else "None")
	
	# Create terrain container as child of our node first
	var terrain_container = Node3D.new()
	var timestamp = Time.get_datetime_string_from_system().replace(":", "_")
	terrain_container.name = "TerrainMesh_" + timestamp
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = terrain_mesh.mesh.duplicate()
	mesh_instance.transform = terrain_mesh.transform
	
	# Add collision
	if terrain_mesh.has_node("StaticBody3D"):
		var static_body = terrain_mesh.get_node("StaticBody3D").duplicate()
		mesh_instance.add_child(static_body)
	
	# Add mesh to container
	terrain_container.add_child(mesh_instance)
	
	# Add to our parent
	add_sibling(terrain_container)
	
	# Position with offset from our current position
	terrain_container.global_transform = terrain_mesh.global_transform
	terrain_container.translate(Vector3(grid_size.x * grid_spacing, 0, 0))
	
	print("Terrain duplicated at: ", terrain_container.name)
	
	return terrain_container
	# First verify we have a scene to work with

	if not scene_root:
		push_error("No valid scene root found!")
		return null

	print("Scene root found: ", scene_root.name)
	print("Current script owner: ", owner.name if owner else "None")
	
	# Create terrain container

	terrain_container.name = "TerrainMesh_" + timestamp
	
	# Create mesh instance

	mesh_instance.name = "Terrain"
	mesh_instance.mesh = terrain_mesh.mesh.duplicate()
	mesh_instance.transform = terrain_mesh.transform
	
	# Add collision
	if terrain_mesh.has_node("StaticBody3D"):
		var static_body = terrain_mesh.get_node("StaticBody3D").duplicate()
		mesh_instance.add_child(static_body)
		static_body.owner = scene_root  # Set owner before adding to tree
	
	# Build the node hierarchy before adding to scene
	terrain_container.add_child(mesh_instance)
	
	# Try to add at the same level as our current node

	parent.add_child(terrain_container)
	
	# Set ownership after adding to the tree
	terrain_container.owner = scene_root
	mesh_instance.owner = scene_root
	
	# Position with offset
	terrain_container.global_transform = terrain_mesh.global_transform
	terrain_container.translate(Vector3(grid_size.x * grid_spacing, 0, 0))
	
	print("Terrain duplicated at: ", terrain_container.name)
	print("Parent is: ", terrain_container.get_parent().name)
	
	return terrain_container




func update_grid_dimensions(new_width: int, new_height: int):
	grid_size = Vector2i(new_width, new_height)
	
	# Resize height values array
	var old_values = height_values.duplicate()
	height_values.resize(grid_size.x * grid_size.y)
	
	# Fill new values with 0 or copy existing values where possible
	for i in range(height_values.size()):
		if i < old_values.size():
			height_values[i] = old_values[i]
		else:
			height_values[i] = 0.0
	
	# Resize vertex colors array
	vertex_colors.resize(grid_size.x * grid_size.y)
	for i in range(vertex_colors.size()):
		if i >= old_values.size():
			vertex_colors[i] = paint_color
	
	# Regenerate terrain
	generate_terrain()
	setup_debug_markers()
	
	# Update camera distance
	var camera_controller = get_node_or_null("CameraController")
	if camera_controller:
		camera_controller.target_distance = grid_size.x * grid_spacing


func randomize_terrain():
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()  # Random seed each time
	noise.frequency = 1.0 / noise_scale
	
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			var index = z * grid_size.x + x
			var noise_val = noise.get_noise_2d(x, z)  # Range: -1 to 1
			
			# Map noise to our desired height range
			var height = lerpf(random_height_min, random_height_max, (noise_val + 1) / 2.0)
			height_values[index] = height
	
	update_mesh_from_heights()
	save_state()  # Add to undo history



func export_heightmap():
	var image = Image.new()
	image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGB8)
	
	# Convert height values to grayscale with bounds checking
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var index = y * grid_size.x + x
			if index < height_values.size():
				var height = height_values[index]
				var normalized_height = (height - min_height) / (max_height - min_height)
				normalized_height = clamp(normalized_height, 0.0, 1.0)
				if x < grid_size.x and y < grid_size.y:  # Extra bounds check
					image.set_pixel(x, y, Color(normalized_height, normalized_height, normalized_height))
	
	# Save with timestamp
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "terrain_heightmap_%d%02d%02d_%02d%02d%02d.png" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	var err = image.save_png(filename)
	if err != OK:
		print("Failed to save heightmap: ", err)
	else:
		print("Heightmap saved to: ", filename)

# Add brush indicator variables at top of script with other vars:
var brush_indicator: MeshInstance3D





func save_terrain_scene():
	# Create a new packed scene
	var packed_scene = PackedScene.new()
	
	# Create a root node for our scene
	var root = Node3D.new()
	root.name = "TerrainMesh"
	
	# Create a copy of our current terrain mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = terrain_mesh.mesh.duplicate()
	
	# The StaticBody and CollisionShape should already be children of the terrain_mesh
	# We'll copy them over too
	if terrain_mesh.has_node("StaticBody3D"):
		var static_body = terrain_mesh.get_node("StaticBody3D").duplicate()
		mesh_instance.add_child(static_body)
		static_body.owner = root  # Important: Set the owner for the scene to save properly
	
	# Add the mesh instance to our root node
	root.add_child(mesh_instance)
	mesh_instance.owner = root  # Important: Set the owner for the scene to save properly
	
	# Pack the scene
	var error = packed_scene.pack(root)
	if error != OK:
		push_error("Failed to pack scene.")
		return
	
	# Generate a filename with timestamp
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "user://terrain_%d%02d%02d_%02d%02d%02d.tscn" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	# Save the packed scene
	error = ResourceSaver.save(packed_scene, filename)
	if error == OK:
		print("Terrain scene saved successfully to: ", filename)
	else:
		push_error("An error occurred while saving the scene.")


func setup_brush_indicator():
	# Create circle mesh for brush
	var circle_mesh = ImmediateMesh.new()
	brush_indicator = MeshInstance3D.new()
	brush_indicator.mesh = circle_mesh
	add_child(brush_indicator)
	
	# Setup material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.3)
	material.flags_transparent = true
	material.flags_unshaded = true
	brush_indicator.material_override = material

func update_brush_position(pos: Vector3):
	if not brush_indicator or not brush_indicator.mesh:
		return
		
	var circle_mesh = brush_indicator.mesh as ImmediateMesh
	circle_mesh.clear_surfaces()
	circle_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	# Draw circle at mouse position
	var segments = 32
	for i in range(segments + 1):
		var angle = i * TAU / segments
		var point = pos + Vector3(
			cos(angle) * influence_radius,
			0.1,  # Slight offset to prevent z-fighting
			sin(angle) * influence_radius
		)
		circle_mesh.surface_add_vertex(point)
	
	circle_mesh.surface_end()

# Add to _input or _process:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	if camera:
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
		var plane = Plane(Vector3.UP, 0)
		var hit = plane.intersects_ray(from, to - from)
		if hit:
			update_brush_position(hit)







# Terrain parameters

@export var ui_visible := true
@export var grid_size := Vector2i(20, 20)
@export var grid_spacing := 1.0
@export var influence_radius := 6.0
@export var height_step := 0.2
@export var smoothing_strength := 0.08
@export var max_height := 60.0
@export var min_height := -5.0
@export var falloff_curve := 2.0
@export var mouse_sensitivity := 0.5
@export var height_change_deadzone := 0.05
@export var vertex_colors: PackedColorArray
@export var paint_color := Color(0.2, 0.6, 0.3)  # Default green color
@export var paint_strength := 0.5  # How quickly to blend colors
var is_color_painting := false  # Are we in color paint mode?
var debug_dots_visible := true  # Track debug dots visibility state
# UI References
var ui_panel: PanelContainer
var influence_slider: HSlider
var height_step_slider: HSlider
var sensitivity_slider: HSlider
var smoothing_slider: HSlider
var undo_button: Button
var redo_button: Button
var export_button: Button

# Mesh and state variables
var terrain_mesh: MeshInstance3D
var vertices: PackedVector3Array
var height_values: Array
var current_vertex := -1
var is_dragging := false
var last_mouse_y := 0.0
var accumulated_delta := 0.0
var debug_markers := {}

# Undo/Redo system
var history: Array = []
var current_history_index := -1
var max_history_steps := 50


func toggle_ui():
	ui_visible = !ui_visible
	ui_panel.visible = ui_visible


func _ready() -> void:
	# Wait a frame to print debug info
	get_tree().create_timer(0.1).timeout.connect(func():
		print("\nScene Debug Info:")
		print("Node ready - our name: ", name)
		print("Our parent: ", get_parent().name if get_parent() else "None")
		print("Our owner: ", owner.name if owner else "None")
		print("In tree: ", is_inside_tree())
	)
	print(OS.get_user_data_dir())
	# Setup basic terrain
	terrain_mesh = MeshInstance3D.new()
	add_child(terrain_mesh)
	
	# Setup camera
	var camera_controller = preload("res://camera_controller.gd").new()
	add_child(camera_controller)
	camera_controller.target_distance = grid_size.x * grid_spacing
	
	# Initialize terrain
	height_values = []
	height_values.resize(grid_size.x * grid_size.y)
	for i in range(height_values.size()):
		height_values[i] = randf_range(-0.1, 0.1)
	
	# Initialize vertex colors with default green
	vertex_colors = PackedColorArray()
	vertex_colors.resize(grid_size.x * grid_size.y)
	for i in range(vertex_colors.size()):
		vertex_colors[i] = paint_color  # Initialize with default green
	
	generate_terrain()
	setup_debug_markers()
	setup_ui()
	
	# Initialize history with first state
	save_state()
func print_grid_debug():
	print("\nCurrent Grid Heights:")
	for y in range(grid_size.y):
		var row = ""
		for x in range(grid_size.x):
			var index = y * grid_size.x + x
			row += "%.2f " % height_values[index]
		print(row)
	print("\nGrid Size: ", grid_size)
	print("Total vertices: ", height_values.size())

func update_terrain_color(new_color: Color):
	terrain_color = new_color
	# CHANGE: Update all vertex colors to the new base color
	for i in range(vertex_colors.size()):
		vertex_colors[i] = terrain_color
	update_mesh_from_heights()

func setup_ui():
	# 1. Main UI Container Setup
	ui_panel = PanelContainer.new()
	ui_panel.position = Vector2(10, 10)
	ui_panel.custom_minimum_size = Vector2(300, 600)
	
	# 2. Scroll Container Setup
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 600)
	ui_panel.add_child(scroll)
	
	# 3. Main VBox Container Setup
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	# Add padding to main container
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# 4. Add UI Sections
	add_utility_section(vbox)
	add_dimensions_section(vbox)
	add_brush_controls_section(vbox)
	add_terrain_randomization_section(vbox)
	add_history_controls_section(vbox)
	add_paint_controls_section(vbox)
	add_visibility_controls_section(vbox)
	add_edge_controls_section(vbox)
	
	# 5. Add panel to scene and set visibility
	add_child(ui_panel)
	ui_panel.visible = ui_visible
	update_ui_state()

# Helper functions for each UI section
func add_utility_section(vbox: VBoxContainer) -> void:
	var utility_buttons = VBoxContainer.new()
	vbox.add_child(utility_buttons)
	
	# Debug button
	var debug_button = Button.new()
	debug_button.text = "Print Grid Debug"
	debug_button.pressed.connect(print_grid_debug)
	utility_buttons.add_child(debug_button)
	
	# Scene buttons
	var scene_buttons = HBoxContainer.new()
	utility_buttons.add_child(scene_buttons)
	
	var duplicate_button = Button.new()
	duplicate_button.text = "Duplicate to Scene"
	duplicate_button.pressed.connect(duplicate_terrain_to_scene)
	duplicate_button.custom_minimum_size.x = 120
	scene_buttons.add_child(duplicate_button)
	
	var save_button = Button.new()
	save_button.text = "Save as Scene File"
	save_button.pressed.connect(save_terrain_scene)
	save_button.custom_minimum_size.x = 120
	scene_buttons.add_child(save_button)
	
	add_separator(vbox)

func add_dimensions_section(vbox: VBoxContainer) -> void:
	var dimensions_label = Label.new()
	dimensions_label.text = "Grid Dimensions"
	vbox.add_child(dimensions_label)
	
	var dimensions_hbox = HBoxContainer.new()
	vbox.add_child(dimensions_hbox)
	
	# Width control
	var width_label = Label.new()
	width_label.text = "Width:"
	dimensions_hbox.add_child(width_label)
	
	width_spinbox = SpinBox.new()
	width_spinbox.min_value = 2
	width_spinbox.max_value = 200
	width_spinbox.value = grid_size.x
	width_spinbox.value_changed.connect(func(value): update_grid_dimensions(int(value), grid_size.y))
	dimensions_hbox.add_child(width_spinbox)
	
	# Height control
	var height_label = Label.new()
	height_label.text = "Height:"
	dimensions_hbox.add_child(height_label)
	
	height_spinbox = SpinBox.new()
	height_spinbox.min_value = 2
	height_spinbox.max_value = 200
	height_spinbox.value = grid_size.y
	height_spinbox.value_changed.connect(func(value): update_grid_dimensions(grid_size.x, int(value)))
	dimensions_hbox.add_child(height_spinbox)
	
	add_separator(vbox)

func add_brush_controls_section(vbox: VBoxContainer) -> void:
	var brush_label = Label.new()
	brush_label.text = "Brush Controls"
	vbox.add_child(brush_label)
	
	# Influence radius slider
	var influence_container = create_slider("Influence Radius", 1.0, 20.0, influence_radius)
	influence_slider = influence_container.get_node("Slider")
	influence_slider.value_changed.connect(func(value): influence_radius = value)
	vbox.add_child(influence_container)
	
	# Height step slider
	var height_step_container = create_slider("Height Step", 0.01, 1.0, height_step)
	height_step_slider = height_step_container.get_node("Slider")
	height_step_slider.value_changed.connect(func(value): height_step = value)
	vbox.add_child(height_step_container)
	
	# Sensitivity slider
	var sensitivity_container = create_slider("Mouse Sensitivity", 0.1, 2.0, mouse_sensitivity)
	sensitivity_slider = sensitivity_container.get_node("Slider")
	sensitivity_slider.value_changed.connect(func(value): mouse_sensitivity = value)
	vbox.add_child(sensitivity_container)
	
	# Smoothing slider
	var smoothing_container = create_slider("Smoothing", 0.01, 0.5, smoothing_strength)
	smoothing_slider = smoothing_container.get_node("Slider")
	smoothing_slider.value_changed.connect(func(value): smoothing_strength = value)
	vbox.add_child(smoothing_container)
	
	add_separator(vbox)

func add_terrain_randomization_section(vbox: VBoxContainer) -> void:
	var random_label = Label.new()
	random_label.text = "Terrain Randomization"
	vbox.add_child(random_label)
	
	# Min height slider
	var random_min_container = create_slider("Min Height", -10.0, 0.0, random_height_min)
	random_min_slider = random_min_container.get_node("Slider")
	random_min_slider.value_changed.connect(func(value): random_height_min = value)
	vbox.add_child(random_min_container)
	
	# Max height slider
	var random_max_container = create_slider("Max Height", 0.0, 10.0, random_height_max)
	random_max_slider = random_max_container.get_node("Slider")
	random_max_slider.value_changed.connect(func(value): random_height_max = value)
	vbox.add_child(random_max_container)
	
	# Noise scale slider
	var noise_scale_container = create_slider("Noise Scale", 10.0, 100.0, noise_scale)
	noise_scale_slider = noise_scale_container.get_node("Slider")
	noise_scale_slider.value_changed.connect(func(value): noise_scale = value)
	vbox.add_child(noise_scale_container)
	
	var randomize_button = Button.new()
	randomize_button.text = "Randomize Terrain"
	randomize_button.pressed.connect(randomize_terrain)
	vbox.add_child(randomize_button)
	
	add_separator(vbox)

func add_history_controls_section(vbox: VBoxContainer) -> void:
	var history_label = Label.new()
	history_label.text = "History Controls"
	vbox.add_child(history_label)
	
	var history_hbox = HBoxContainer.new()
	vbox.add_child(history_hbox)
	
	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.pressed.connect(undo)
	history_hbox.add_child(undo_button)
	
	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.pressed.connect(redo)
	history_hbox.add_child(redo_button)
	
	export_button = Button.new()
	export_button.text = "Export Heightmap"
	export_button.pressed.connect(export_heightmap)
	vbox.add_child(export_button)
	
	add_separator(vbox)

func add_paint_controls_section(vbox: VBoxContainer) -> void:
	var paint_label = Label.new()
	paint_label.text = "Paint Controls"
	vbox.add_child(paint_label)
	
	var paint_picker = ColorPickerButton.new()
	paint_picker.custom_minimum_size = Vector2(50, 30)
	paint_picker.color = paint_color
	paint_picker.color_changed.connect(func(color): paint_color = color)
	vbox.add_child(paint_picker)
	
	var paint_strength_container = create_slider("Paint Strength", 0.0, 1.0, paint_strength)
	var paint_strength_slider = paint_strength_container.get_node("Slider")
	paint_strength_slider.value_changed.connect(func(value): paint_strength = value)
	vbox.add_child(paint_strength_container)
	
	var paint_toggle = Button.new()
	paint_toggle.text = "Toggle Paint Mode"
	paint_toggle.toggle_mode = true
	paint_toggle.toggled.connect(func(button_pressed): is_color_painting = button_pressed)
	vbox.add_child(paint_toggle)
	
	add_separator(vbox)

func add_visibility_controls_section(vbox: VBoxContainer) -> void:
	var visibility_label = Label.new()
	visibility_label.text = "Visibility Controls"
	vbox.add_child(visibility_label)
	
	var toggle_ui_button = Button.new()
	toggle_ui_button.text = "Toggle UI"
	toggle_ui_button.pressed.connect(toggle_ui)
	vbox.add_child(toggle_ui_button)
	
	var debug_dots_toggle = Button.new()
	debug_dots_toggle.text = "Toggle Debug Dots"
	debug_dots_toggle.pressed.connect(func():
		debug_dots_visible = !debug_dots_visible
		for marker in debug_markers.values():
			marker.visible = debug_dots_visible
	)
	vbox.add_child(debug_dots_toggle)
	
	add_separator(vbox)

func add_edge_controls_section(vbox: VBoxContainer) -> void:
	var edge_controls_label = Label.new()
	edge_controls_label.text = "Edge Controls"
	vbox.add_child(edge_controls_label)
	
	var edge_buttons = HBoxContainer.new()
	vbox.add_child(edge_buttons)
	
	var drop_sides_button = Button.new()
	drop_sides_button.text = "Drop Sides"
	drop_sides_button.pressed.connect(drop_sides)
	drop_sides_button.custom_minimum_size.x = 120
	edge_buttons.add_child(drop_sides_button)
	
	var raise_sides_button = Button.new()
	raise_sides_button.text = "Raise Sides"
	raise_sides_button.pressed.connect(raise_sides)
	raise_sides_button.custom_minimum_size.x = 120
	edge_buttons.add_child(raise_sides_button)
	
	add_separator(vbox)
# Helper function to add separators between sections
func add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 10
	parent.add_child(sep)

func modify_edges(raise: bool):
	# Keep track of changed vertices for undo history
	var original_heights = height_values.duplicate()
	
	# Target height will be either max_height or min_height
	var target_height = max_height if raise else min_height
	
	# Common parameters for edge modification
	var falloff_distance = 3  # How many vertices in to affect
	var falloff_strength = 0.7  # How strongly to modify near-edge vertices
	
	
	
	# Modify edges and create falloff
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			# Check if we're on any edge
			if x == 0 or x == grid_size.x - 1 or z == 0 or z == grid_size.y - 1:
				var index = z * grid_size.x + x
				height_values[index] = target_height
				
				# Process neighboring vertices within falloff distance
				for nx in range(max(0, x - falloff_distance), min(grid_size.x, x + falloff_distance + 1)):
					for nz in range(max(0, z - falloff_distance), min(grid_size.y, z + falloff_distance + 1)):
						if nx == x and nz == z:
							continue  # Skip the edge vertex itself
							
						var neighbor_index = nz * grid_size.x + nx
						var distance = Vector2(nx - x, nz - z).length()
						
						if distance <= falloff_distance:
							var falloff = pow(1.0 - (distance / falloff_distance), 2)  # Quadratic falloff
							var current_height = height_values[neighbor_index]
							var new_height = lerp(current_height, target_height, falloff * falloff_strength)
							
							# If multiple edges affect this vertex, take the most extreme value
							if raise:
								height_values[neighbor_index] = max(new_height, height_values[neighbor_index])
							else:
								height_values[neighbor_index] = min(new_height, height_values[neighbor_index])
	
	# Update the mesh
	update_mesh_from_heights()
	
	# Save state for undo
	save_state()

func drop_sides():
	# Keep track of changed vertices for undo history
	var original_heights = height_values.duplicate()
	
	# Drop edges to minimum height
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			# Check if we're on any edge
			if x == 0 or x == grid_size.x - 1 or z == 0 or z == grid_size.y - 1:
				var index = z * grid_size.x + x
				height_values[index] = min_height
				
				# Also drop vertices near the edge for a smoother transition
				var falloff_distance = 3  # How many vertices in to affect
				var falloff_strength = 0.7  # How strongly to drop near-edge vertices
				
				# Process neighboring vertices within falloff distance
				for nx in range(max(0, x - falloff_distance), min(grid_size.x, x + falloff_distance + 1)):
					for nz in range(max(0, z - falloff_distance), min(grid_size.y, z + falloff_distance + 1)):
						if nx == x and nz == z:
							continue  # Skip the edge vertex itself
							
						var neighbor_index = nz * grid_size.x + nx
						var distance = Vector2(nx - x, nz - z).length()
						
						if distance <= falloff_distance:
							var falloff = pow(1.0 - (distance / falloff_distance), 2)  # Quadratic falloff
							var target_height = lerp(height_values[neighbor_index], min_height, falloff * falloff_strength)
							height_values[neighbor_index] = target_height
	
	# Update the mesh
	update_mesh_from_heights()
	
	# Save state for undo
	save_state()
	
func raise_sides():
	modify_edges(true)



func apply_color_at_vertex(vertex_index: int):
	if vertex_index < 0 or vertex_index >= vertex_colors.size():
		return
		
	var current_color = vertex_colors[vertex_index]
	vertex_colors[vertex_index] = current_color.lerp(paint_color, paint_strength)
	
	# Update surrounding vertices based on influence radius
	var center_pos = vertices[vertex_index]
	for i in range(vertices.size()):
		if i == vertex_index:
			continue
			
		var distance = vertices[i].distance_to(center_pos)
		if distance <= influence_radius:
			var falloff = 1.0 - pow(distance / influence_radius, falloff_curve)
			falloff = clamp(falloff, 0.0, 1.0)
			
			var blend_strength = paint_strength * falloff
			vertex_colors[i] = vertex_colors[i].lerp(paint_color, blend_strength)
	
	update_mesh_from_heights()  # We'll modify this to update colors too


func create_slider(label: String, min_value: float, max_value: float, default_value: float) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 50)
	
	# Create a horizontal container for label and value
	var header = HBoxContainer.new()
	container.add_child(header)
	
	var label_node = Label.new()
	label_node.text = label
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label_node)
	
	# Add value label
	var value_label = Label.new()
	value_label.name = "Value"
	value_label.text = "%.2f" % default_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(50, 0)
	header.add_child(value_label)
	
	var slider = HSlider.new()
	slider.name = "Slider"
	slider.min_value = min_value
	slider.max_value = max_value
	slider.value = default_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 20)
	slider.step = 0.1 if (max_value - min_value) > 10 else 0.01
	container.add_child(slider)
	
	return container

func save_state():
	# Create a copy of current height values
	var state = height_values.duplicate()
	
	# If we're not at the end of the history, truncate the future states
	if current_history_index < history.size() - 1:
		history.resize(current_history_index + 1)
	
	# Add new state
	history.append(state)
	current_history_index = history.size() - 1
	
	# Limit history size
	if history.size() > max_history_steps:
		history.pop_front()
		current_history_index -= 1
	
	update_ui_state()

func undo():
	if current_history_index > 0:
		current_history_index -= 1
		height_values = history[current_history_index].duplicate()
		update_mesh_from_heights()
		update_ui_state()

func redo():
	if current_history_index < history.size() - 1:
		current_history_index += 1
		height_values = history[current_history_index].duplicate()
		update_mesh_from_heights()
		update_ui_state()

func update_ui_state():
	undo_button.disabled = current_history_index <= 0
	redo_button.disabled = current_history_index >= history.size() - 1

func _process(delta: float):
	if pending_changes and Time.get_ticks_msec() - last_mesh_update > mesh_update_interval * 1000:
		update_mesh_from_heights()
		last_mesh_update = Time.get_ticks_msec()
		pending_changes = false

func handle_drag(event: InputEventMouseMotion):
	if current_vertex == -1 or ui_panel.get_global_rect().has_point(event.position):
		return
	
	if is_color_painting:
		apply_color_at_vertex(current_vertex)
		return

	
	var mouse_delta = (last_mouse_y - event.position.y) * mouse_sensitivity
	last_mouse_y = event.position.y
	
	accumulated_delta += mouse_delta
	
	if abs(accumulated_delta) > height_change_deadzone:
		var change_direction = sign(accumulated_delta)
		var change_magnitude = height_step * abs(accumulated_delta)
		
		var new_height = height_values[current_vertex] + (change_magnitude * change_direction)
		height_values[current_vertex] = clamp(new_height, min_height, max_height)
		
		apply_height_changes(current_vertex)
		accumulated_delta = 0.0
		
		# Save state after significant changes
		save_state()

func apply_height_changes(center_vertex: int):

	var center_pos = vertices[center_vertex]
	var center_height = height_values[center_vertex]
	
	changes_buffer.clear()  # Track this batch of changes
	changes_buffer.append(center_vertex)
	
	for i in range(vertices.size()):
		if i == center_vertex:
			continue
			
		var distance = vertices[i].distance_to(center_pos)
		if distance <= influence_radius:
			var falloff = 1.0 - pow(distance / influence_radius, falloff_curve)
			falloff = clamp(falloff, 0.0, 1.0)
			
			var target_height = lerp(
				height_values[i],
				center_height,
				falloff * smoothing_strength
			)
			
			if abs(height_values[i] - target_height) > 0.001:  # Threshold for significant change
				height_values[i] = lerp(height_values[i], target_height, 0.3)
				changes_buffer.append(i)
	
	pending_changes = true  # Flag that we need an update

	
	for i in range(vertices.size()):
		if i == center_vertex:
			continue
			
		var distance = vertices[i].distance_to(center_pos)
		if distance <= influence_radius:
			var falloff = 1.0 - pow(distance / influence_radius, falloff_curve)
			falloff = clamp(falloff, 0.0, 1.0)
			
			var target_height = lerp(
				height_values[i],
				center_height,
				falloff * smoothing_strength
			)
			
			height_values[i] = lerp(height_values[i], target_height, 0.3)
	
	update_mesh_from_heights()

# ... [Previous terrain generation and mesh update code remains the same] ...

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:  # 'H' for hide/show
			toggle_ui()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not ui_panel.get_global_rect().has_point(event.position):
				handle_click(event)
			else:
				is_dragging = false
				current_vertex = -1
				if debug_markers:
					update_debug_markers()
	
	elif event is InputEventMouseMotion and is_dragging:
		handle_drag(event)
	
	# Add keyboard shortcuts
	elif event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_Z and event.ctrl_pressed:
				undo()
			elif event.keycode == KEY_Y and event.ctrl_pressed:
				redo()










func handle_click(event: InputEventMouseButton):
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = event.position
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	# Find closest vertex with improved precision
	var min_dist = INF
	current_vertex = -1
	for i in range(vertices.size()):
		var vertex_pos = terrain_mesh.global_transform * vertices[i]
		var dist = Geometry3D.get_closest_point_to_segment_uncapped(
			vertex_pos,
			from,
			to
		).distance_to(vertex_pos)
		if dist < min_dist and dist < 1.0:
			min_dist = dist
			current_vertex = i
	
	if current_vertex != -1:
		is_dragging = true
		last_mouse_y = event.position.y
		accumulated_delta = 0.0  # Reset accumulator on new click
		update_debug_markers()

		if current_vertex != -1:
			is_dragging = true
			last_mouse_y = event.position.y
			accumulated_delta = 0.0
		
		if is_color_painting:
			apply_color_at_vertex(current_vertex)
		
		update_debug_markers()


func generate_terrain():
	# Create basic mesh arrays
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	# Generate vertices
	vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Create vertex grid
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			vertices.append(Vector3(
				x * grid_spacing - (grid_size.x * grid_spacing) / 2,
				0,
				z * grid_spacing - (grid_size.y * grid_spacing) / 2
			))
			uvs.append(Vector2(float(x) / grid_size.x, float(z) / grid_size.y))
			normals.append(Vector3.UP)
	
	# Create triangles
	for z in range(grid_size.y - 1):
		for x in range(grid_size.x - 1):
			var base = z * grid_size.x + x
			indices.push_back(base)
			indices.push_back(base + 1)
			indices.push_back(base + grid_size.x)
			indices.push_back(base + 1)
			indices.push_back(base + grid_size.x + 1)
			indices.push_back(base + grid_size.x)
	
	# Set up mesh arrays
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_COLOR] = vertex_colors
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	# Create new mesh
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	# Material setup using vertex colors
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	array_mesh.surface_set_material(0, material)
	
	terrain_mesh.mesh = array_mesh
	
	# Add collision
	if terrain_mesh.has_node("StaticBody3D"):
		terrain_mesh.get_node("StaticBody3D").queue_free()
	
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = array_mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	terrain_mesh.add_child(static_body)
	
	
func setup_debug_markers():
	# Clear existing markers
	for marker in debug_markers.values():
		marker.queue_free()
	debug_markers.clear()
	
	# Create new markers
	for i in range(vertices.size()):
		var marker = CSGSphere3D.new()
		marker.radius = 0.1
		marker.material = StandardMaterial3D.new()
		marker.material.albedo_color = Color.WHITE
		marker.visible = debug_dots_visible  # Set initial visibility
		add_child(marker)
		debug_markers[str(i)] = marker
	
	update_debug_markers()

func update_debug_markers():
	for i in range(vertices.size()):
		var marker = debug_markers.get(str(i))
		if marker:
			marker.position = vertices[i]
			
			# Color coding
			var material = marker.material as StandardMaterial3D
			if i == current_vertex:
				material.albedo_color = Color.RED
			elif is_dragging and vertices[i].distance_to(vertices[current_vertex]) <= influence_radius:
				var distance = vertices[i].distance_to(vertices[current_vertex])
				var intensity = 1.0 - (distance / influence_radius)
				material.albedo_color = Color.YELLOW * intensity + Color.WHITE * (1 - intensity)
			else:
				material.albedo_color = Color.WHITE

func update_mesh_from_heights():
	
	for vertex_idx in changes_buffer:
		vertices[vertex_idx].y = float(height_values[vertex_idx])
	# Update vertices based on height values
	for i in range(vertices.size()):
		var base_height = height_values[i]
		vertices[i].y = float(base_height)
		
		# Apply smooth interpolation for visual mesh
		if is_dragging and i != current_vertex:
			var distance = vertices[i].distance_to(vertices[current_vertex])
			if distance <= influence_radius:
				var factor = cos((distance / influence_radius) * PI) * 0.5 + 0.5
				var target_height = height_values[current_vertex]
				vertices[i].y = lerp(float(base_height), float(target_height), factor * smoothing_strength)
	
	# Update mesh geometry
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	# Create normals and UVs
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	for i in range(vertices.size()):
		normals.append(Vector3.UP)
		uvs.append(Vector2(
			float(i % grid_size.x) / grid_size.x,
			float(i / grid_size.x) / grid_size.y
		))
	
	# Create indices
	var indices = PackedInt32Array()
	for z in range(grid_size.y - 1):
		for x in range(grid_size.x - 1):
			var base = z * grid_size.x + x
			indices.push_back(base)
			indices.push_back(base + 1)
			indices.push_back(base + grid_size.x)
			indices.push_back(base + 1)
			indices.push_back(base + grid_size.x + 1)
			indices.push_back(base + grid_size.x)
	
	# Update mesh arrays
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_COLOR] = vertex_colors  # Make sure vertex colors are used
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	# Create new mesh
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	# CHANGE: Consistent material setup using only vertex colors
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	array_mesh.surface_set_material(0, material)
	
	terrain_mesh.mesh = array_mesh
	
	# Update collision
	var static_body = terrain_mesh.get_child(0)
	var collision_shape = static_body.get_child(0)
	collision_shape.shape = array_mesh.create_trimesh_shape()
	
	update_debug_markers()

# Add to _input or _process:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	if camera:
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
		var plane = Plane(Vector3.UP, 0)
		var hit = plane.intersects_ray(from, to - from)
		if hit:
			update_brush_position(hit)
	changes_buffer.clear()
