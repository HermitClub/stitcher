# edge_analyzer.gd
@tool
extends Node3D

var debug_material: StandardMaterial3D
var debug_lines: Node3D
var connection_range := 2.0
var line_meshes: Array[Node3D] = []  # Array to hold line meshes


func _ready() -> void:
	debug_print("Edge Analyzer initializing")
	setup_debug_visualization()

func setup_debug_visualization() -> void:
	debug_print("Setting up debug visualization")
	if debug_lines:  # Clear existing if any
		debug_lines.queue_free()
		
	debug_lines = Node3D.new()
	debug_lines.name = "DebugLines"
	add_child(debug_lines)
	
	debug_material = StandardMaterial3D.new()
	debug_material.vertex_color_use_as_albedo = true
	debug_material.flags_unshaded = true
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func clear_debug_visualizations():
	# Clear spheres:
	for child in debug_lines.get_children():
		child.queue_free()

	# Clear lines:
	for mesh in line_meshes:
		mesh.queue_free()
	line_meshes.clear() # Clear the array itself
func visualize_potential_connections(mesh1: MeshInstance3D, mesh2: MeshInstance3D) -> void:
	if not mesh1 or not mesh2:
		push_error("Invalid mesh instances provided")
		return
		
	if not debug_lines:
		debug_print("Debug lines node not initialized, setting up now")
		setup_debug_visualization()
		
	debug_print("Starting potential connection visualization")
	clear_debug_visualizations()

	
	var edges1 = get_mesh_edges(mesh1)
	var edges2 = get_mesh_edges(mesh2)
	
	# Visualize edge vertices
	visualize_edge_vertices(mesh1, edges1)
	visualize_edge_vertices(mesh2, edges2)
	
	# Check each combination of edges
	for edge1_name in edges1:
		for edge2_name in edges2:
			if are_edges_compatible(edge1_name, edge2_name):
				var edge1_points = edges1[edge1_name]
				var edge2_points = edges2[edge2_name]
				
				if are_edges_close(edge1_points, edge2_points, mesh1, mesh2):
					draw_connection(edge1_points, edge2_points, mesh1, mesh2)

func get_mesh_edges(mesh_instance: MeshInstance3D) -> Dictionary:
	if not mesh_instance or not mesh_instance.mesh:
		push_error("Invalid mesh instance")
		return {}
		
	var mesh = mesh_instance.mesh
	var vertices = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var aabb = mesh.get_aabb()
	
	debug_print("Analyzing edges for mesh: " + mesh_instance.name)
	debug_print("AABB bounds: %s to %s" % [aabb.position, aabb.position + aabb.size])
	
	var edges = {
		"east": [],
		"west": [],
		"north": [],
		"south": []
	}
	
	var edge_threshold = 0.1
	
	for vertex in vertices:
		if abs(vertex.x - aabb.position.x) < edge_threshold:
			edges["west"].append(vertex)
			debug_print("Found west edge vertex: " + str(vertex))
		elif abs(vertex.x - (aabb.position.x + aabb.size.x)) < edge_threshold:
			edges["east"].append(vertex)
			debug_print("Found east edge vertex: " + str(vertex))
			
		if abs(vertex.z - aabb.position.z) < edge_threshold:
			edges["north"].append(vertex)
			debug_print("Found north edge vertex: " + str(vertex))
		elif abs(vertex.z - (aabb.position.z + aabb.size.z)) < edge_threshold:
			edges["south"].append(vertex)
			debug_print("Found south edge vertex: " + str(vertex))
	
	return edges

func are_edges_compatible(edge1: String, edge2: String) -> bool:
	# Each case needs to be a separate pattern
	match [edge1, edge2]:
		["east", "west"]:
			return true
		["west", "east"]:
			return true
		["north", "south"]:
			return true
		["south", "north"]:
			return true
		_:  # Default case
			return false

func are_edges_close(edge1_points: Array, edge2_points: Array, 
					mesh1: MeshInstance3D, mesh2: MeshInstance3D) -> bool:
	var global_points1 = edge1_points.map(func(p): return mesh1.to_global(p))
	var global_points2 = edge2_points.map(func(p): return mesh2.to_global(p))
	
	for p1 in global_points1:
		for p2 in global_points2:
			if p1.distance_to(p2) < connection_range:
				return true
	return false

func visualize_edge_vertices(mesh_instance: MeshInstance3D, edges: Dictionary) -> void:
	debug_print("Visualizing edges for mesh: " + mesh_instance.name)
	
	var mesh_markers = Node3D.new()
	mesh_markers.name = "Markers_" + mesh_instance.name
	debug_lines.add_child(mesh_markers)
	
	for edge_name in edges:
		var color = Color.RED if edge_name in ["east", "west"] else Color.BLUE
		
		var edge_container = Node3D.new()
		edge_container.name = edge_name.capitalize() + "_Edge"
		mesh_markers.add_child(edge_container)
		
		debug_print("Adding %d markers for %s edge" % [edges[edge_name].size(), edge_name])
		
		for vertex in edges[edge_name]:
			var sphere = CSGSphere3D.new()
			sphere.radius = 0.1
			sphere.position = mesh_instance.to_global(vertex)
			
			var material = StandardMaterial3D.new()
			material.albedo_color = color
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.7
			sphere.material = material
			
			edge_container.add_child(sphere)

# Add this function to edge_analyzer.gd

func stitch_meshes(mesh1: MeshInstance3D, mesh2: MeshInstance3D) -> void:
	# Get the edges of both meshes
	var edges1 = get_mesh_edges(mesh1)
	var edges2 = get_mesh_edges(mesh2)
	
	# Find compatible edges
	for edge1_name in edges1:
		for edge2_name in edges2:
			if are_edges_compatible(edge1_name, edge2_name):
				var edge1_points = edges1[edge1_name]
				var edge2_points = edges2[edge2_name]
				
				if are_edges_close(edge1_points, edge2_points, mesh1, mesh2):
					# Align the meshes based on their edges
					align_meshes(mesh1, mesh2, edge1_points, edge2_points)
					return  # Stop after first valid connection is made

func align_meshes(mesh1: MeshInstance3D, mesh2: MeshInstance3D, 
				 edge1_points: Array, edge2_points: Array) -> void:
	# Convert points to global space
	var global_points1 = edge1_points.map(func(p): return mesh1.to_global(p))
	var global_points2 = edge2_points.map(func(p): return mesh2.to_global(p))
	
	# Calculate average positions for alignment
	var avg_pos1 = Vector3.ZERO
	var avg_pos2 = Vector3.ZERO
	
	for p in global_points1:
		avg_pos1 += p
	for p in global_points2:
		avg_pos2 += p
	
	avg_pos1 /= global_points1.size()
	avg_pos2 /= global_points2.size()
	
	# Calculate the offset needed to align the edges
	var offset = avg_pos1 - avg_pos2
	
	# Move mesh2 to align with mesh1
	mesh2.global_position += offset

func draw_connection(edge1_points: Array, edge2_points: Array,
					mesh1: MeshInstance3D, mesh2: MeshInstance3D) -> void:
	# Create a line mesh to visualize the connection
	var immediate_mesh = ImmediateMesh.new()
	var mesh_instance = MeshInstance3D.new()
	
	mesh_instance.mesh = immediate_mesh
	mesh_instance.material_override = debug_material
	add_child(mesh_instance)
	
	# Draw lines between corresponding points
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for i in range(min(edge1_points.size(), edge2_points.size())):
		var p1 = mesh1.to_global(edge1_points[i])
		var p2 = mesh2.to_global(edge2_points[i])
		
		immediate_mesh.surface_set_color(Color(0, 1, 0, 0.5))  # Semi-transparent green
		immediate_mesh.surface_add_vertex(p1)
		immediate_mesh.surface_add_vertex(p2)
	
	immediate_mesh.surface_end()

	line_meshes.append(mesh_instance) # Add the mesh instance to the array

func debug_print(message: String) -> void:
	print("[EdgeAnalyzer] ", message)
