class_name OrbitCam
extends Node3D
## Odyssey-style free camera: mouse, right stick or touch drag orbit it; it eases back behind
## Bolo when you stop steering it, keeps its height steady during jumps and avoids walls.

var target: CharacterBody3D
var yaw := 0.0
var pitch := -0.32
var arm: SpringArm3D
var cam: Camera3D
var idle_t := 10.0
var follow_y := 0.0
var shake := 0.0


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = 6.2
	arm.margin = 0.25
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	arm.shape = shape
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.1
	arm.add_child(cam)
	arm.add_excluded_object(target.get_rid())
	follow_y = target.global_position.y
	global_position = target.global_position + Vector3.UP * 1.1
	yaw = target.facing_yaw()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and not Controls.touch_active and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if e is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (e.button_mask & MOUSE_BUTTON_MASK_RIGHT)):
		yaw -= e.relative.x * 0.0035
		pitch -= e.relative.y * 0.0028
		idle_t = 0.0


func _process(d: float) -> void:
	var st := Controls.camera_stick()
	if st != Vector2.ZERO:
		yaw -= st.x * 2.6 * d
		pitch -= st.y * 1.8 * d
		idle_t = 0.0
	if Controls.touch_cam != Vector2.ZERO:
		yaw -= Controls.touch_cam.x * 0.007
		pitch -= Controls.touch_cam.y * 0.005
		Controls.touch_cam = Vector2.ZERO
		idle_t = 0.0
	idle_t += d
	pitch = clamp(pitch, -1.15, 0.35)

	# ease back behind Bolo while he runs and nobody is steering the camera
	var hv := Vector2(target.velocity.x, target.velocity.z)
	# only when running away from the camera or across it; running toward it would spin the view
	var cam_fwd := Vector2(-sin(yaw), -cos(yaw))
	if idle_t > 1.2 and hv.length() > 2.0 and target.state != "hang" and hv.normalized().dot(cam_fwd) > 0.2:
		var want := atan2(-hv.x, -hv.y)
		yaw = lerp_angle(yaw, want, clamp(d * 1.2, 0.0, 1.0))

	# vertical follow: steady while jumping, quick when grounded or falling far below
	var ty := target.global_position.y
	var grounded: bool = target.is_on_floor() or target.state == "hang"
	var rate := 8.0 if grounded or ty < follow_y - 2.0 else 1.5
	follow_y = lerp(follow_y, ty, clamp(d * rate, 0.0, 1.0))
	var p := target.global_position
	global_position = global_position.lerp(Vector3(p.x, follow_y + 1.1, p.z), clamp(d * 12.0, 0.0, 1.0))
	rotation = Vector3(pitch, yaw, 0)

	shake = move_toward(shake, 0.0, d * 3.0)
	cam.h_offset = randf_range(-1, 1) * shake * 0.12
	cam.v_offset = randf_range(-1, 1) * shake * 0.12


func add_shake(a: float) -> void:
	shake = max(shake, a)


## Camera-relative movement on the ground plane.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw)
