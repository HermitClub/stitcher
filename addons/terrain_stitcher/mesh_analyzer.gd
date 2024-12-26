@tool
extends Node3D

class_name MeshAnalyzer

signal connection_points_updated

var debug_visualization: Node3D
var current_meshes: Array[MeshInstance3D] = []
var potential_connections: Array[Dictionary] = []

func _ready() -> void:
	debug_visualization = Node3D.new()
	debug_visualization.name = "ConnectionPreview"
	add_child(debug_visualization)

func analyze_meshes(meshes: Array[MeshInstance3D]) -> void:
	clear_visualizations()
	current_meshes = meshes
	
	if meshes.size() < 2:
		return
		
	# Analyze each mesh's boundaries
	var boundaries: Array[Dictionary] = []
	for mesh in meshes:
		boundaries.append(get_mesh_boundary(mesh))
	
	# Find potential connection points between meshes
	potential_connections.clear()
	for i in range(boundaries.size()):
		for j in range(i + 1, boundaries.size()):
			var connections = find_potential_connections(
				boundaries[i], 
				boundaries[j],
				meshes[i],
				meshes[j]
			)
			potential_connections.append_array(connections)
	
	visualize_connections()
	connection_points_updated.emit()

func get_mesh_boundary(mesh: MeshInstance3D) -> Dictionary:
	var mesh_data = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_data[Mesh.ARRAY_VERTEX]
	var boundary_points: Array[Vector3] = []
	
	# Get mesh AABB in local space
	var aabb := mesh.mesh.get_aabb()
	
	# Find vertices near the edges of the AABB
	for vertex in vertices:
		var is_boundary = false
		# Check if vertex is near any AABB face
		if is_near_value(vertex.x, aabb.position.x, 0.1) or \
		   is_near_value(vertex.x, aabb.position.x + aabb.size.x, 0.1) or \
		   is_near_value(vertex.z, aabb.position.z, 0.1) or \
		   is_near_value(vertex.z, aabb.position.z + aabb.size.z, 0.1):
			is_boundary = true
		
		if is_boundary:
			boundary_points.append(vertex)
	
	return {
		"mesh": mesh,
		"boundary_points": boundary_points,
		"aabb": aabb
	}

func find_potential_connections(boundary1: Dictionary, boundary2: Dictionary,
							  mesh1: MeshInstance3D, mesh2: MeshInstance3D) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	var threshold := 1.0  # Distance threshold for potential connections
	
	# Convert points to world space
	var points1 = boundary1.boundary_points.map(
		func(p): return mesh1.to_global(p)
	)
	var points2 = boundary2.boundary_points.map(
		func(p): return mesh2.to_global(p)
	)
	
	# Find close point pairs
	for i in range(points1.size()):
		for j in range(points2.size()):
			var distance = points1[i].distance_to(points2[j])
			if distance <= threshold:
				connections.append({
					"point1": points1[i],
					"point2": points2[j],
					"mesh1": mesh1,
					"mesh2": mesh2,
					"distance": distance
				})
	
	return connections

func visualize_connections() -> void:
	clear_visualizations()
	
	# Create shared materials and meshes
	var materials = {
		"edge": create_debug_material(Color(0.5, 0.5, 0.5, 0.5)),  # Gray for regular edge points
		"connection": create_debug_material(Color(0, 1, 0, 0.8)),  # Bright green for connection points
		"line": create_debug_material(Color(0, 1, 1, 0.3))  # Cyan for connection lines
	}
	
	var debug_sphere = create_debug_sphere(0.05)  # Small spheres for edge points
	
	# First pass: Visualize all edge points
	for i in range(current_meshes.size()):
		var mesh_inst = current_meshes[i]
		var boundary = get_mesh_boundary(mesh_inst)
		
		for point in boundary.boundary_points:
			var global_point = mesh_inst.to_global(point)
			add_debug_point(global_point, debug_sphere, materials.edge)
	
	# Second pass: Visualize active connections
	for connection in potential_connections:
		# Add connection spheres
		add_debug_point(connection.point1, debug_sphere, materials.connection)
		add_debug_point(connection.point2, debug_sphere, materials.connection)
		
		# Add connection line
		var line = ImmediateMesh.new()
		var line_instance = MeshInstance3D.new()
		line_instance.mesh = line
		line_instance.material_override = materials.line
		
		line.clear_surfaces()
		line.surface_begin(Mesh.PRIMITIVE_LINES)
		line.surface_add_vertex(connection.point1)
		line.surface_add_vertex(connection.point2)
		line.surface_end()
		
		debug_visualization.add_child(line_instance)

func create_debug_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_transparent = true
	return material

func create_debug_sphere(radius: float) -> SphereMesh:
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	return sphere

func add_debug_point(position: Vector3, mesh: SphereMesh, material: Material) -> void:
	var point_instance = MeshInstance3D.new()
	point_instance.mesh = mesh
	point_instance.material_override = material
	point_instance.position = position
	debug_visualization.add_child(point_instance)
func clear_visualizations() -> void:
	for child in debug_visualization.get_children():
		child.queue_free()

func is_near_value(a: float, b: float, threshold: float) -> bool:
	return abs(a - b) <= threshold
