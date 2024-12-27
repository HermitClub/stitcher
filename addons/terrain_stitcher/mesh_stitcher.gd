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
	print("\n=== Starting Smooth Connection Area ===")
	print("Initial vertices: ", vertices.size())
	print("Blend distance: ", blend_distance)
	print("Smoothing strength: ", smoothing_strength)
	
	var blend_map = {}
	var stats = {
		"total_original_height": 0.0,
		"total_target_height": 0.0,
		"points_processed": 0
	}
	
	# First pass: analyze the seam to establish baseline heights
	for connection in connections:
		var center = (connection.point1 + connection.point2) / 2.0
		print("\nConnection point:")
		print("  Point1 height: %.3f" % connection.point1.y)
		print("  Point2 height: %.3f" % connection.point2.y)
		print("  Target height: %.3f" % center.y)
		
		# Find base heights of both meshes near the seam
		var mesh1_base = connection.point1.y
		var mesh2_base = connection.point2.y
		
		# Calculate local height variations
		for i in range(vertices.size()):
			var vertex_pos = vertices[i]
			var dist_to_seam = vertex_pos.distance_to(center)
			
			if dist_to_seam <= blend_distance:
				stats.points_processed += 1
				stats.total_original_height += vertex_pos.y
				
				# Calculate sharper falloff
				var sharp_falloff = pow(1.0 - (dist_to_seam / blend_distance), 2.0)
				sharp_falloff *= smoothing_strength
				
				if !blend_map.has(i):
					blend_map[i] = {
						"weight": 0.0,
						"target_base": 0.0,
						"target_color": Color.TRANSPARENT
					}
				
				var entry = blend_map[i]
				entry.weight += sharp_falloff
				entry.target_base += center.y * sharp_falloff
				stats.total_target_height += center.y

	print("\n=== Blend Statistics ===")
	var avg_original = stats.total_original_height / stats.points_processed if stats.points_processed > 0 else 0
	var avg_target = stats.total_target_height / stats.points_processed if stats.points_processed > 0 else 0
	print("Points processed: ", stats.points_processed)
	print("Average original height: %.3f" % avg_original)
	print("Average target height: %.3f" % avg_target)
	print("Height difference: %.3f" % (avg_target - avg_original))
	
	# Second pass: apply blending while preserving local detail
	var vertices_modified = 0
	var total_height_change = 0.0
	
	for vertex_idx in blend_map:
		var blend_data = blend_map[vertex_idx]
		if blend_data.weight > 0:
			vertices_modified += 1
			var old_height = vertices[vertex_idx].y
			
			# Calculate new height
			var target_base = blend_data.target_base / blend_data.weight
			vertices[vertex_idx].y = target_base
			
			total_height_change += abs(vertices[vertex_idx].y - old_height)

	print("\nFinal modifications:")
	print("Vertices modified: ", vertices_modified)
	print("Average height change: %.3f" % (total_height_change / vertices_modified if vertices_modified > 0 else 0))
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
