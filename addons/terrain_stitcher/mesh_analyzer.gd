@tool
extends Node3D

class_name MeshAnalyzer

signal connection_points_updated

var debug_visualization: Node3D
var current_meshes: Array[MeshInstance3D] = []
var potential_connections: Array[Dictionary] = []
var connection_threshold: float = 1.0
var edge_resolution: float = 1.0

func _ready() -> void:
	debug_visualization = Node3D.new()
	debug_visualization.name = "ConnectionPreview"
	add_child(debug_visualization)

func update_connection_settings(threshold: float, resolution: float, _direction_bias: float) -> void:
	connection_threshold = threshold
	edge_resolution = resolution
	if current_meshes.size() >= 2:
		analyze_meshes(current_meshes)

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
	var indices: PackedInt32Array = mesh_data[Mesh.ARRAY_INDEX]
	
	# Create edge map to find boundary edges
	var edge_map := {}
	var boundary_edges: Array[Dictionary] = []
	
	# First pass: count how many times each edge appears
	for i in range(0, indices.size(), 3):
		var tri = [indices[i], indices[i + 1], indices[i + 2]]
		for j in range(3):
			var v1 = tri[j]
			var v2 = tri[(j + 1) % 3]
			var edge_key = '%d_%d' % [min(v1, v2), max(v1, v2)]
			
			if not edge_map.has(edge_key):
				edge_map[edge_key] = 0
			edge_map[edge_key] += 1
	
	# Second pass: find edges that appear only once (boundary edges)
	for edge_key in edge_map:
		if edge_map[edge_key] == 1:
			var v_indices = edge_key.split('_')
			boundary_edges.append({
				"start": vertices[int(v_indices[0])],
				"end": vertices[int(v_indices[1])],
				"start_idx": int(v_indices[0]),
				"end_idx": int(v_indices[1])
			})
	
	# Order boundary edges into a continuous chain
	var ordered_edges = order_boundary_edges(boundary_edges)
	
	# Generate evenly spaced points along the boundary
	var boundary_points = generate_boundary_points(ordered_edges)
	
	return {
		"mesh": mesh,
		"boundary_edges": ordered_edges,
		"boundary_points": boundary_points
	}

func order_boundary_edges(edges: Array[Dictionary]) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = []  # Explicit typing here
	var used := {}
	var current_edge = edges[0]
	
	while ordered.size() < edges.size():
		ordered.append(current_edge)
		used[current_edge] = true
		
		var found_next = false
		var end_point = current_edge.end
		
		# Find edge that connects to current edge's endpoint
		for next_edge in edges:
			if not used.has(next_edge) and (next_edge.start.is_equal_approx(end_point) or next_edge.end.is_equal_approx(end_point)):
				# Orient the edge correctly
				if next_edge.end.is_equal_approx(end_point):
					var temp = next_edge.end
					next_edge.end = next_edge.start
					next_edge.start = temp
				
				current_edge = next_edge
				found_next = true
				break
		
		if not found_next:
			break  # Handle discontinuity
	
	return ordered

func find_potential_connections(boundary1: Dictionary, boundary2: Dictionary,
							  mesh1: MeshInstance3D, mesh2: MeshInstance3D) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	var vertical_threshold := 0.1  # Strict vertical alignment
	
	# Create properly typed arrays for our points
	var points1: Array[Vector3] = []
	var points2: Array[Vector3] = []
	
	# Manually populate arrays to maintain type safety
	for p in boundary1.boundary_points:
		points1.append(mesh1.to_global(p))
	
	for p in boundary2.boundary_points:
		points2.append(mesh2.to_global(p))
	
	# Find closest point pairs vertically
	var bridge_segments: Array[Dictionary] = []
	var used_points := {}
	
	for i in range(points1.size()):
		var p1 = points1[i]
		var match_result = find_best_vertical_match(p1, points2, vertical_threshold, used_points)
		
		if match_result.point != null:  # Only add if we found a valid match
			bridge_segments.append({
				"point1": p1,
				"point2": match_result.point,
				"mesh1": mesh1,
				"mesh2": mesh2,
				"y_delta": match_result.point.y - p1.y
			})
			used_points[match_result.point] = true
	
	# Fill gaps between bridge segments
	connections = fill_bridge_gaps(bridge_segments)  # Direct assignment instead of append_array
	return connections



func update_blend_preview(blend_distance: float, smoothing_strength: float) -> void:
	if current_meshes.size() < 2 or potential_connections.is_empty():
		return
		
	# Clear any existing blend preview
	for child in debug_visualization.get_children():
		if child.name.begins_with("BlendPreview"):
			child.queue_free()
			
	# Create material for blend zone visualization
	var blend_material = StandardMaterial3D.new()
	blend_material.albedo_color = Color(1, 1, 0, 0.2)  # Semi-transparent yellow
	blend_material.flags_transparent = true
	blend_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# For each connection, create a cylinder to show blend area
	for connection in potential_connections:
		var center = (connection.point1 + connection.point2) / 2.0
		
		# Create a cylinder to represent blend zone
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = blend_distance
		cylinder.bottom_radius = blend_distance
		cylinder.height = 0.1  # Thin disk
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "BlendPreview"
		mesh_instance.mesh = cylinder
		mesh_instance.material_override = blend_material
		
		# Position and rotate the cylinder
		mesh_instance.position = center
		mesh_instance.rotation.x = PI/2  # Lay flat
		
		debug_visualization.add_child(mesh_instance)

func visualize_stitch_progression() -> void:
	# Material for showing the intended stitch path
	var path_material = StandardMaterial3D.new()
	path_material.albedo_color = Color(1, 0, 1, 0.8)  # Magenta, mostly opaque
	path_material.flags_transparent = true
	
	# Material for showing the actual stitch points
	var stitch_material = StandardMaterial3D.new()
	stitch_material.albedo_color = Color(1, 1, 0, 0.8)  # Yellow, mostly opaque
	stitch_material.flags_transparent = true
	
	# Draw the intended stitch path
	for connection in potential_connections:
		var midpoint = (connection.point1 + connection.point2) / 2.0
		
		# Draw a sphere at the intended stitch point
		var sphere = SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		
		var sphere_instance = MeshInstance3D.new()
		sphere_instance.mesh = sphere
		sphere_instance.material_override = path_material
		sphere_instance.position = midpoint
		sphere_instance.name = "StitchProgressionPoint"
		
		debug_visualization.add_child(sphere_instance)
		
		# Draw vertical lines to show height difference
		var line = ImmediateMesh.new()
		var line_instance = MeshInstance3D.new()
		line_instance.mesh = line
		line_instance.material_override = stitch_material
		line_instance.name = "StitchProgressionLine"
		
		line.clear_surfaces()
		line.surface_begin(Mesh.PRIMITIVE_LINES)
		line.surface_add_vertex(connection.point1)
		line.surface_add_vertex(midpoint)
		line.surface_add_vertex(midpoint)
		line.surface_add_vertex(connection.point2)
		line.surface_end()
		
		debug_visualization.add_child(line_instance)

func visualize_connections() -> void:
	clear_visualizations()
	
	# Create debug points at each boundary point
	var debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color.BLUE
	debug_material.flags_transparent = true
	debug_material.albedo_color.a = 0.5
	
	# Original connection visualization
	for connection in potential_connections:
		# Draw line between connection points
		var line = ImmediateMesh.new()
		var mesh_instance = MeshInstance3D.new()
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0, 1, 0, 0.5)  # Semi-transparent green
		material.flags_transparent = true
		
		mesh_instance.mesh = line
		mesh_instance.material_override = material
		mesh_instance.name = "ConnectionLine"
		
		line.clear_surfaces()
		line.surface_begin(Mesh.PRIMITIVE_LINES)
		line.surface_add_vertex(connection.point1)
		line.surface_add_vertex(connection.point2)
		line.surface_end()
		
		debug_visualization.add_child(mesh_instance)
		
		# Add small spheres at connection points
		for point in [connection.point1, connection.point2]:
			var sphere = SphereMesh.new()
			sphere.radius = 0.1
			sphere.height = 0.2
			
			var sphere_instance = MeshInstance3D.new()
			sphere_instance.mesh = sphere
			sphere_instance.material_override = debug_material
			sphere_instance.position = point
			sphere_instance.name = "ConnectionPoint"
			
			debug_visualization.add_child(sphere_instance)
	
	# Add our new stitch progression visualization
	visualize_stitch_progression()

func clear_visualizations() -> void:
	for child in debug_visualization.get_children():
		child.queue_free()



func generate_boundary_points(edges: Array[Dictionary], point_spacing: float = 0.5) -> Array[Vector3]:
	var points: Array[Vector3] = []
	
	for edge in edges:
		var length = edge.start.distance_to(edge.end)
		var segments = max(1, int(length / point_spacing))
		
		for i in range(segments + 1):
			var t = float(i) / segments
			points.append(edge.start.lerp(edge.end, t))
	
	return points



func find_best_vertical_match(point: Vector3, candidates: Array[Vector3], threshold: float, used: Dictionary) -> Dictionary:
	var best_match := {
		"point": null,
		"distance": 999999.0
	}
	
	for candidate in candidates:
		if used.has(candidate):
			continue
			
		var xz_offset = Vector2(
			abs(point.x - candidate.x),
			abs(point.z - candidate.z)
		)
		
		if xz_offset.length() <= threshold:
			var distance = xz_offset.length()
			if distance < best_match.distance:
				best_match.point = candidate
				best_match.distance = distance
	
	return best_match

func fill_bridge_gaps(segments: Array[Dictionary]) -> Array[Dictionary]:
	var filled_connections: Array[Dictionary] = []  # Already properly typed
	
	# If we have no segments or just one, return what we have
	if segments.size() <= 1:
		return segments  # Early return for empty or single-segment case
	
	segments.sort_custom(func(a, b): return a.point1.x < b.point1.x)
	
	# Add first segment if we have any
	if not segments.is_empty():
		filled_connections.append(segments[0])
	
	# Process gaps between segments
	for i in range(segments.size() - 1):
		var current = segments[i]
		var next = segments[i + 1]
		
		var gap_size = current.point1.distance_to(next.point1)
		if gap_size > 2.0:  # gap_threshold
			# Fill large gap with interpolated points
			var steps = ceil(gap_size / 2.0)
			for step in range(1, steps):
				var t = float(step) / steps
				var interpolated_p1 = current.point1.lerp(next.point1, t)
				var interpolated_p2 = current.point2.lerp(next.point2, t)
				
				filled_connections.append({
					"point1": interpolated_p1,
					"point2": interpolated_p2,
					"mesh1": current.mesh1,
					"mesh2": current.mesh2,
					"y_delta": interpolated_p2.y - interpolated_p1.y,
					"is_interpolated": true
				})
		
		# Add the next segment
		filled_connections.append(next)
	
	return filled_connections




func is_near_value(a: float, b: float, threshold: float) -> bool:
	return abs(a - b) <= threshold
