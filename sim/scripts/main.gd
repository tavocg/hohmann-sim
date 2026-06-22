extends Node3D

const MU := 3.9845571e5
const R_EARTH := 6378.137
const R1 := 6678.137
const R2 := 42159.036216630644
const KM_TO_UNIT := 0.001
const EARTH_RADIUS_U := R_EARTH * KM_TO_UNIT
const R1_U := R1 * KM_TO_UNIT
const R2_U := R2 * KM_TO_UNIT
const TRANSFER_DURATION := 26.0
const INITIAL_ORBIT_DURATION := 8.0
const TARGET_ORBIT_DURATION := 14.0
const CYCLE_DURATION := INITIAL_ORBIT_DURATION + TRANSFER_DURATION + TARGET_ORBIT_DURATION
const MOUSE_ORBIT_SENSITIVITY := 0.008
const TOUCH_ORBIT_SENSITIVITY := 0.0022

# Parametros de la elipse: periapsis en R1 y apoapsis en R2.
var transfer_a := 0.5 * (R1 + R2)
var transfer_epsilon := (R2 - R1) / (R2 + R1)
var transfer_p := transfer_a * (1.0 - transfer_epsilon * transfer_epsilon)
var dv1 := 0.0
var dv2 := 0.0
var transfer_time_hours := 0.0
var elapsed := 0.0
var yaw := 0.0
var pitch := -0.35
var camera_distance := 4.2
var dragging := false
var touch_dragging := false

@onready var camera: Camera3D = $Camera3D
@onready var satellite_pivot: Node3D = $SatellitePivot
@onready var satellite_mount: Node3D = $SatellitePivot/SatelliteMount
@onready var info_label: Label = $Hud/InfoPanel/InfoLabel


func _ready() -> void:
	_calculate_hohmann()
	_setup_environment()
	_create_earth()
	_create_orbit_lines()
	_create_satellite()
	_update_satellite(0.0)
	_update_camera()


func _process(delta: float) -> void:
	# El tiempo se recicla para mostrar continuamente la maniobra completa.
	elapsed = fmod(elapsed + delta, CYCLE_DURATION)
	_update_satellite(elapsed)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = max(2.5, camera_distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = min(28.0, camera_distance + 0.7)
	elif event is InputEventMouseMotion and dragging:
		_orbit_camera(event.relative, MOUSE_ORBIT_SENSITIVITY)
	elif event is InputEventScreenTouch:
		if event.index == 0:
			touch_dragging = event.pressed
	elif event is InputEventScreenDrag and touch_dragging and event.index == 0:
		_orbit_camera(event.relative, TOUCH_ORBIT_SENSITIVITY)


func _orbit_camera(delta: Vector2, sensitivity: float) -> void:
	yaw -= delta.x * sensitivity
	pitch = clamp(pitch - delta.y * sensitivity, -1.25, 1.1)


func _calculate_hohmann() -> void:
	# Los mismos calculos del reporte se repiten aqui para mostrar valores en pantalla.
	var vc1 := sqrt(MU / R1)
	var vc2 := sqrt(MU / R2)
	var vt1 := sqrt(MU * (2.0 / R1 - 1.0 / transfer_a))
	var vt2 := sqrt(MU * (2.0 / R2 - 1.0 / transfer_a))
	dv1 = vt1 - vc1
	dv2 = vc2 - vt2
	transfer_time_hours = PI * sqrt(pow(transfer_a, 3.0) / MU) / 3600.0


func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.017, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.36, 0.42)
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_energy = 2.7
	sun.rotation_degrees = Vector3(-38.0, -34.0, 0.0)
	add_child(sun)


func _create_earth() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Earth"
	var sphere := SphereMesh.new()
	sphere.radius = EARTH_RADIUS_U
	sphere.height = EARTH_RADIUS_U * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.33, 0.74)
	material.roughness = 0.86
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _create_satellite() -> void:
	var dawn_scene: PackedScene = load("res://assets/models/Dawn_uncompressed.glb")
	var dawn: Node3D = dawn_scene.instantiate()
	dawn.name = "Dawn"
	dawn.scale = Vector3.ONE * 0.18
	dawn.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	satellite_mount.add_child(dawn)


func _create_orbit_lines() -> void:
	# Se dibujan las dos orbitas circulares y la media elipse de transferencia.
	add_child(_make_orbit_line("OrbitaInicial", R1_U, Color(0.24, 0.72, 1.0, 0.72)))
	add_child(_make_orbit_line("OrbitaObjetivoGEO", R2_U, Color(0.38, 0.9, 0.52, 0.65)))
	add_child(_make_transfer_line())


func _make_orbit_line(line_name: String, radius: float, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := _line_material(color)
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for i in range(241):
		var theta := TAU * float(i) / 240.0
		mesh.surface_add_vertex(Vector3(cos(theta) * radius, 0.0, sin(theta) * radius))
	mesh.surface_end()

	var line := MeshInstance3D.new()
	line.name = line_name
	line.mesh = mesh
	return line


func _make_transfer_line() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := _line_material(Color(1.0, 0.74, 0.22, 0.95))
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	# Solo se necesita media elipse: de theta=0 en R1 a theta=pi en R2.
	for i in range(181):
		var theta := PI * float(i) / 180.0
		mesh.surface_add_vertex(_orbital_position(transfer_radius(theta), theta))
	mesh.surface_end()

	var line := MeshInstance3D.new()
	line.name = "ElipseTransferenciaHohmann"
	line.mesh = mesh
	return line


func _line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _update_satellite(t: float) -> void:
	var theta := 0.0
	var radius_km := R1
	var phase := ""
	var elapsed_transfer_hours := 0.0

	# La animacion se divide en tres fases: orbita inicial, transferencia y GEO.
	if t < INITIAL_ORBIT_DURATION:
		var u := t / INITIAL_ORBIT_DURATION
		theta = u * TAU
		radius_km = R1
		phase = "Orbita circular baja"
	elif t < INITIAL_ORBIT_DURATION + TRANSFER_DURATION:
		var u := (t - INITIAL_ORBIT_DURATION) / TRANSFER_DURATION
		theta = PI * u
		radius_km = transfer_radius(theta)
		elapsed_transfer_hours = transfer_time_hours * u
		phase = "Transferencia eliptica de Hohmann"
	else:
		var u := (t - INITIAL_ORBIT_DURATION - TRANSFER_DURATION) / TARGET_ORBIT_DURATION
		theta = PI + u * TAU
		radius_km = R2
		elapsed_transfer_hours = transfer_time_hours
		phase = "Orbita circular GEO"

	satellite_pivot.position = _orbital_position(radius_km * KM_TO_UNIT, theta)
	# El modelo apunta hacia la Tierra para que su orientacion sea legible durante el recorrido.
	satellite_mount.look_at(Vector3.ZERO, Vector3.UP)
	satellite_mount.rotate_y(PI * 0.5)
	_update_info(phase, radius_km, theta, elapsed_transfer_hours)


func transfer_radius(theta: float) -> float:
	return transfer_p / (1.0 + transfer_epsilon * cos(theta))


func _orbital_position(radius: float, theta: float) -> Vector3:
	return Vector3(cos(theta) * radius, 0.0, sin(theta) * radius)


func _update_camera() -> void:
	# La camara orbita alrededor del satelite, no alrededor del origen.
	var offset := Vector3(
		cos(pitch) * cos(yaw),
		sin(pitch),
		cos(pitch) * sin(yaw)
	) * camera_distance
	camera.global_position = satellite_pivot.global_position + offset
	camera.look_at(satellite_pivot.global_position, Vector3.UP)


func _update_info(phase: String, radius_km: float, theta: float, elapsed_transfer_hours: float) -> void:
	var vc1 := sqrt(MU / R1)
	var vc2 := sqrt(MU / R2)
	var current_hours: float = clamp(elapsed_transfer_hours, 0.0, transfer_time_hours)
	info_label.text = (
		"Transferencia Tierra-GEO\n"
		+ "Fase: %s\n" % phase
		+ "r1 = %.3f km | r2 = %.0f km | mu = %.4f km^3/s^2\n" % [R1, R2, MU]
		+ "a_t = (r1 + r2) / 2 = %.3f km | epsilon_t = %.4f\n" % [transfer_a, transfer_epsilon]
		+ "v_c1 = %.4f km/s | v_c2 = %.4f km/s\n" % [vc1, vc2]
		+ "Delta v1 = %.5f km/s | Delta v2 = %.5f km/s\n" % [dv1, dv2]
		+ "T_t = pi * sqrt(a_t^3 / mu) = %.3f h | t = %.3f h\n" % [transfer_time_hours, current_hours]
		+ "r actual = %.2f km | theta = %.1f grados\n" % [radius_km, rad_to_deg(theta)]
	)
