# stitcher_dock.gd
@tool
extends Control

var edge_analyzer: Node3D = null
var mesh_list: ItemList = null
var stitch_button: Button = null
var connection_range_slider: HSlider = null
var selected_meshes: Array[Node] = []
var debug_mode := true
var ui_container: VBoxContainer = null

func debug_print(message: String) -> void:
	if debug_mode:
		print("[StitcherDock] ", message)

func _init() -> void:
	debug_print("Dock initializing")

func _ready() -> void:
	# Wait a frame to ensure proper initialization
	await get_tree().process_frame
	initialize_dock()
	
	mesh_list = ItemList.new()  # Initialize the mesh list here
	mesh_list.custom_minimum_size = Vector2(200, 150)

func initialize_dock() -> void:
	debug_print("Initializing dock")
	
	if ui_container:
		debug_print("UI already initialized")
		return
		
	setup_ui()
	setup_edge_analyzer()
	debug_print("Dock initialization complete")

func setup_ui() -> void:
	debug_print("Setting up UI elements")
	
	ui_container = VBoxContainer.new()
	ui_container.name = "UIContainer"
	add_child(ui_container)
	
	# Add descriptive label
	var description = Label.new()
	description.text = "Select two meshes to stitch their edges"
	ui_container.add_child(description)
	
	# Mesh list setup
	mesh_list = ItemList.new()
	mesh_list.custom_minimum_size = Vector2(200, 150)
	mesh_list.select_mode = ItemList.SELECT_MULTI
	ui_container.add_child(mesh_list)
	
	# Stitch button setup
	stitch_button = Button.new()
	stitch_button.text = "Stitch Selected"
	stitch_button.pressed.connect(_on_stitch_pressed)
	stitch_button.disabled = true
	ui_container.add_child(stitch_button)
	
	# Clear visualization button
	var clear_button = Button.new()
	clear_button.text = "Clear Visualization"
	clear_button.pressed.connect(func(): 
		if edge_analyzer:
			edge_analyzer.clear_debug_visualizations()
	)
	ui_container.add_child(clear_button)
	
	debug_print("UI setup complete")

func setup_edge_analyzer() -> void:
	debug_print("Setting up edge analyzer")
	
	if edge_analyzer:
		edge_analyzer.queue_free()
		
	var EdgeAnalyzer = load("res://addons/terrain_stitcher/edge_analyzer.gd")
	edge_analyzer = EdgeAnalyzer.new()
	add_child(edge_analyzer)
	
	debug_print("Edge analyzer setup complete")

func update_selection(meshes: Array) -> void:
	debug_print("Updating selection with %d meshes" % meshes.size())
	
	if not mesh_list:
		push_error("Mesh list not initialized")
		return
		
	selected_meshes = meshes
	mesh_list.clear()
	
	for mesh in meshes:
		if mesh is MeshInstance3D:
			mesh_list.add_item(mesh.name)
	
	if stitch_button:
		stitch_button.disabled = meshes.size() != 2
	
	if edge_analyzer:
		if meshes.size() == 2:
			edge_analyzer.clear_debug_visualizations()
			edge_analyzer.visualize_potential_connections(meshes[0], meshes[1])
		else:
			edge_analyzer.clear_debug_visualizations()

func _on_stitch_pressed() -> void:
	debug_print("Stitch button pressed")
	if not edge_analyzer:
		push_error("Edge analyzer not initialized")
		return
		
	if selected_meshes.size() != 2:
		push_error("Need exactly 2 meshes selected for stitching")
		return
		
	edge_analyzer.stitch_meshes(selected_meshes[0], selected_meshes[1])
	debug_print("Stitch operation completed")
