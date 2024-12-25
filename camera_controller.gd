extends Node3D

@export var target_distance := 20.0
@export var min_distance := 5.0
@export var max_distance := 100.0
@export var orbit_speed := 0.005
@export var pan_speed := 0.01
@export var zoom_speed := 0.1
@export var free_mode := false  # Toggle between orbital and free camera

var camera: Camera3D
var target_position := Vector3.ZERO
var rotation_x := 0.0
var rotation_y := 0.0
var current_distance: float
var dragging := false
var last_mouse_pos := Vector2.ZERO

func _ready():
	# Setup camera
	camera = Camera3D.new()
	add_child(camera)
	current_distance = target_distance
	update_camera_transform()

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			# Toggle camera mode
			free_mode = !free_mode
	
	elif event is InputEventMouseMotion and dragging:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		if free_mode:
			handle_free_camera_movement(delta)
		else:
			handle_orbital_movement(delta)
		
	elif event is InputEventKey and event.pressed:
		if free_mode:
			handle_free_camera_keys(event)

func handle_orbital_movement(delta: Vector2):
	rotation_x -= delta.x * orbit_speed
	rotation_y -= delta.y * orbit_speed
	rotation_y = clamp(rotation_y, -PI/2 + 0.1, PI/2 - 0.1)
	update_camera_transform()

func handle_free_camera_movement(delta: Vector2):
	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	# Rotate around global Y axis for left/right
	rotate_y(-delta.x * orbit_speed)
	
	# Rotate around local X axis for up/down
	var pitch = -delta.y * orbit_speed
	rotate_object_local(Vector3.RIGHT, pitch)

func handle_free_camera_keys(event: InputEventKey):
	var move_speed = 0.5
	var move_dir = Vector3.ZERO
	
	match event.keycode:
		KEY_W: move_dir.z = -1
		KEY_S: move_dir.z = 1
		KEY_A: move_dir.x = -1
		KEY_D: move_dir.x = 1
		KEY_Q: move_dir.y = -1
		KEY_E: move_dir.y = 1
	
	if move_dir != Vector3.ZERO:
		move_camera(move_dir * move_speed)

func move_camera(direction: Vector3):
	if free_mode:
		# Move in camera's local space
		camera.global_translate(camera.global_transform.basis * direction)

func zoom(amount: float):
	if free_mode:
		# In free mode, move camera forward/backward
		move_camera(Vector3(0, 0, amount * 2))
	else:
		# In orbit mode, adjust distance
		current_distance = clamp(
			current_distance + amount * current_distance,
			min_distance,
			max_distance
		)
		update_camera_transform()

func update_camera_transform():
	if not free_mode:
		# Orbital camera update
		var offset = Vector3(
			cos(rotation_x) * cos(rotation_y),
			sin(rotation_y),
			sin(rotation_x) * cos(rotation_y)
		)
		camera.global_transform.origin = target_position + offset * current_distance
		camera.look_at(target_position)
