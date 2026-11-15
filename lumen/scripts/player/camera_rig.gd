class_name CameraRig
extends Node3D
## Camera em terceira pessoa: orbita o heroi com o mouse (ou analogico direito),
## encurta quando ha parede no caminho e treme com impactos.

var target: Node3D
var yaw := 0.0
var pitch := -0.32
var distance := 5.6
var height := 1.45
var shoulder := 0.55
var cam: Camera3D
var trauma := 0.0
var _cur_dist := 5.6
var _pivot := Vector3.ZERO
var _noise_t := 0.0
var orbit_mode := false       # usado no guarda-roupa: camera de frente para o heroi
var orbit_angle := 0.0
var fov_kick := 0.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 68.0
	cam.near = 0.1
	cam.far = 400.0
	add_child(cam)
	cam.current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.0026 * float(Save.setting("sens"))
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, -1.25, 0.55)

func add_trauma(t: float) -> void:
	trauma = minf(1.0, trauma + t * float(Save.setting("shake")))

func forward() -> Vector3:
	return -Basis(Vector3.UP, yaw).z

func aim_dir() -> Vector3:
	return -cam.global_transform.basis.z

## Ponto para onde a mira aponta (raio do centro da tela contra o mundo).
func aim_point(max_dist: float = 40.0) -> Vector3:
	var from := cam.global_position
	var to := from + aim_dir() * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if hit else to

## Ponto no chao sob a mira, limitado a 'max_range' metros do heroi.
func ground_point(max_range: float) -> Vector3:
	var from := cam.global_position
	var d := aim_dir()
	var p: Vector3
	if d.y < -0.02:
		p = from + d * (from.y / -d.y)
	else:
		p = target.global_position + forward() * max_range
	p.y = 0.0
	var base := target.global_position
	base.y = 0.0
	var off := p - base
	if off.length() > max_range:
		p = base + off.normalized() * max_range
	return p

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var look_v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_v.length() > 0.05 and not orbit_mode:
		yaw -= look_v.x * 2.6 * delta
		pitch = clampf(pitch - look_v.y * 1.8 * delta, -1.25, 0.55)
	var want := target.global_position + Vector3(0, height, 0)
	_pivot = _pivot.lerp(want, 1.0 - exp(-18.0 * delta)) if _pivot != Vector3.ZERO else want
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var sh := shoulder
	var dist := distance
	if orbit_mode:
		basis = Basis(Vector3.UP, orbit_angle) * Basis(Vector3.RIGHT, -0.1)
		sh = 1.1
		dist = 3.0
		_pivot = target.global_position + Vector3(0, 0.78, 0)
	var origin := _pivot + basis.x * sh
	var desired := origin + basis.z * dist
	var q := PhysicsRayQueryParameters3D.create(_pivot, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var d := dist
	if hit:
		d = maxf(0.6, _pivot.distance_to(hit["position"]) - 0.3)
	_cur_dist = d if d < _cur_dist else lerpf(_cur_dist, d, 1.0 - exp(-6.0 * delta))
	var pos := origin + basis.z * _cur_dist
	pos.y = maxf(pos.y, 0.25)
	# tremor: ruido suave proporcional ao trauma ao quadrado
	trauma = maxf(0.0, trauma - delta * 1.6)
	_noise_t += delta * 34.0
	var s := trauma * trauma
	var jitter := Vector3(sin(_noise_t * 1.3), sin(_noise_t * 1.7 + 1.0), 0.0) * s * 0.22
	global_transform = Transform3D(basis, pos + basis * jitter)
	cam.rotation = Vector3(sin(_noise_t * 1.1 + 2.0) * s * 0.03, sin(_noise_t * 0.9) * s * 0.03, sin(_noise_t * 1.9) * s * 0.035)
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-7.0 * delta))
	cam.fov = 68.0 + fov_kick
