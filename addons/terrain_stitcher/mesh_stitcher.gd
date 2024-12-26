@tool
extends Node3D

class_name MeshStitcher

signal stitch_completed(new_mesh: MeshInstance3D)
func stitch_meshes(connections: Array[Dictionary], blend_distance: float, smoothing_strength: float) -> MeshInstance3D:
	if connections.is_empty():
		push_error("No connection points found")
		return null
		
	var mesh1: MeshInstance3D = connections[0].mesh1
	var mesh2: MeshInstance3D = connections[0].mesh2
	
	# Get complete mesh data including colors
	var data1 = get_mesh_data(mesh1)
	var data2 = get_mesh_data(mesh2)
	
	var combined_vertices := PackedVector3Array()
	var combined_indices := PackedInt32Array()
	var combined_colors := PackedColorArray()  # Add color support
	var vertex_mapping := {}
	
	# Copy mesh1 data
	for i in range(data1.vertices.size()):
		vertex_mapping[combined_vertices.size()] = i
		combined_vertices.append(mesh1.to_global(data1.vertices[i]))
		combined_colors.append(data1.colors[i] if data1.colors.size() > 0 else Color.WHITE)
	
	# Add mesh2 data with mapping
	var mesh2_start_idx = combined_vertices.size()
	for i in range(data2.vertices.size()):
		var global_pos = mesh2.to_global(data2.vertices[i])
		vertex_mapping[mesh2_start_idx + i] = combined_vertices.size()
		combined_vertices.append(global_pos)
		combined_colors.append(data2.colors[i] if data2.colors.size() > 0 else Color.WHITE)
	
	# Combine indices with mapping
	combined_indices.append_array(data1.indices)
	for i in range(0, data2.indices.size(), 3):
		var idx1 = vertex_mapping[mesh2_start_idx + data2.indices[i]]
		var idx2 = vertex_mapping[mesh2_start_idx + data2.indices[i + 1]]
		var idx3 = vertex_mapping[mesh2_start_idx + data2.indices[i + 2]]
		combined_indices.append_array([idx1, idx2, idx3])
	
	# Enhanced smoothing with color blending
	smooth_connection_area(combined_vertices, combined_colors, connections, blend_distance, smoothing_strength)
	
	# Create new mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = combined_vertices
	arrays[Mesh.ARRAY_INDEX] = combined_indices
	arrays[Mesh.ARRAY_COLOR] = combined_colors
	
	var normals := calculate_normals(combined_vertices, combined_indices)
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Setup material to use vertex colors
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	new_mesh.surface_set_material(0, material)
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = new_mesh
	mesh_instance.name = "StitchedMesh"
	
	# Add collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = new_mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	return mesh_instance

func get_mesh_data(mesh_instance: MeshInstance3D) -> Dictionary:
	var arrays = mesh_instance.mesh.surface_get_arrays(0)
	return {
		"vertices": arrays[Mesh.ARRAY_VERTEX],
		"indices": arrays[Mesh.ARRAY_INDEX],
		"colors": arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] else PackedColorArray()
	}

func smooth_connection_area(vertices: PackedVector3Array, colors: PackedColorArray,
						  connections: Array[Dictionary], blend_distance: float, 
						  smoothing_strength: float) -> void:
	var blend_map = {}
	
	# First pass: Find all connection regions and calculate influence
	for connection in connections:
		var center = (connection.point1 + connection.point2) / 2.0
		var direction = (connection.point2 - connection.point1).normalized()
		var perp_direction = Vector3(-direction.z, 0, direction.x)  # Perpendicular to connection line
		
		# Extended blend radius for smoother transition
		var extended_radius = blend_distance * 2.5
		
		# Calculate target height and color at connection
		var color1 = colors[vertices.find(connection.point1)]
		var color2 = colors[vertices.find(connection.point2)]
		var target_color = color1.lerp(color2, 0.5)
		var target_height = (connection.point1.y + connection.point2.y) / 2.0
		
		# Analyze each vertex for potential blending
		for i in range(vertices.size()):
			var vertex = vertices[i]
			var to_vertex = vertex - center
			
			# Calculate distance along and perpendicular to connection line
			var along_distance = abs(to_vertex.dot(direction))
			var perp_distance = abs(to_vertex.dot(perp_direction))
			
			# Only blend vertices within our extended radius
			if along_distance <= extended_radius and perp_distance <= extended_radius:
				# Calculate blend weight using smooth falloff
				var radial_distance = sqrt(along_distance * along_distance + perp_distance * perp_distance)
				var blend_weight = 1.0 - smooth_step(0.0, extended_radius, radial_distance)
				blend_weight *= smoothing_strength
				
				# Apply additional falloff based on perpendicular distance
				var perp_falloff = 1.0 - smooth_step(0.0, extended_radius * 0.7, perp_distance)
				blend_weight *= perp_falloff
				
				if !blend_map.has(i):
					blend_map[i] = {
						"weight": 0.0,
						"target_height": 0.0,
						"target_color": Color.TRANSPARENT,
						"normal_influence": Vector3.ZERO
					}
				
				var entry = blend_map[i]
				entry.weight += blend_weight
				entry.target_height += target_height * blend_weight
				entry.target_color += target_color * blend_weight
				
				# Store normal influence for smoother transitions
				var normal_influence = perp_direction * blend_weight
				entry.normal_influence += normal_influence
	
	# Second pass: Apply blending with smooth transitions
	for vertex_idx in blend_map:
		var blend_data = blend_map[vertex_idx]
		if blend_data.weight > 0:
			var weight = clamp(blend_data.weight, 0.0, 1.0)
			
			# Apply height blending with easing
			var target_height = blend_data.target_height / blend_data.weight
			var height_delta = target_height - vertices[vertex_idx].y
			vertices[vertex_idx].y += height_delta * ease(weight, 0.5)
			
			# Smooth color transition
			var target_color = blend_data.target_color / blend_data.weight
			colors[vertex_idx] = colors[vertex_idx].lerp(target_color, ease(weight, 0.3))
			
			# Apply normal influence for smoother mesh flow
			var normal_influence = blend_data.normal_influence / blend_data.weight
			vertices[vertex_idx] += normal_influence * 0.1 * weight
			
			# Propagate changes to nearby vertices for continuity
			var neighbor_radius = blend_distance * 0.8
			for j in range(vertices.size()):
				if j != vertex_idx:
					var dist = vertices[j].distance_to(vertices[vertex_idx])
					if dist <= neighbor_radius:
						var fade = (1.0 - (dist / neighbor_radius)) * weight * 0.4
						var height_interp = lerp(vertices[j].y, vertices[vertex_idx].y, fade)
						vertices[j].y = height_interp
						colors[j] = colors[j].lerp(colors[vertex_idx], fade * 0.7)

func ease(x: float, factor: float) -> float:
	# Custom easing function for smoother transitions
	return 1.0 - pow(1.0 - x, 2.0 + factor)
func calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	
	# Calculate face normals and accumulate
	for i in range(0, indices.size(), 3):
		var v1 = vertices[indices[i]]
		var v2 = vertices[indices[i + 1]]
		var v3 = vertices[indices[i + 2]]
		
		var normal = (v2 - v1).cross(v3 - v1).normalized()
		
		# Add to all vertices of this face
		normals[indices[i]] += normal
		normals[indices[i + 1]] += normal
		normals[indices[i + 2]] += normal
	
	# Normalize accumulated normals
	for i in range(normals.size()):
		if normals[i] != Vector3.ZERO:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	
	return normals

func smooth_step(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3 - 2 * t)
