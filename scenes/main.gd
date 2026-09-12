extends Node3D

# آموزش کاربری هدست واقعیت مجازی
# محیط: مرکز منابع یادگیری
# اداره آموزش و تعالی منابع انسانی شرکت پالایش نفت اصفهان

var left_controller: XRController3D
var right_controller: XRController3D
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D

var left_ray: MeshInstance3D
var right_ray: MeshInstance3D

var trigger_target: StaticBody3D
var teleport_marker: StaticBody3D
var gate_left: MeshInstance3D
var gate_right: MeshInstance3D
var gate_trigger_area: Area3D
var skip_button: StaticBody3D

# ابزارها و اهداف روی میز کار
var screwdriver_tool: StaticBody3D
var bolt_target: MeshInstance3D
var cutter_tool: StaticBody3D
var wire_target: MeshInstance3D
var movable_object: StaticBody3D
var drop_zone: MeshInstance3D

var grabbables: Array = []
var held_object: Node3D = null
var held_by_controller: XRController3D = null
var bolt_progress: float = 0.0

var step_label: Label3D
var desc_label: Label3D
var hint_label: Label3D

var current_step: int = 0

var stick_directions_done := {"up": false, "down": false, "left": false, "right": false}
var face_buttons_done := {"right_ax": false, "right_by": false, "left_ax": false, "left_by": false}

var locomotion_enabled: bool = false
var teleport_enabled: bool = false
var move_speed: float = 1.6
var turn_cooldown: float = 0.0

var steps_data := [
	{"title": "به مرکز منابع یادگیری خوش آمدید", "desc": "اداره آموزش و تعالی منابع انسانی شرکت پالایش نفت اصفهان\n\nبرای شروع، دکمه‌ی ماشه (Trigger) رو روی هرکدوم از دسته‌ها بزن."},
	{"title": "دکمه‌ی ماشه (Trigger)", "desc": "دکمه‌ی A یا X رو نگه‌دار تا لیزر روشن بشه، دسته رو به‌سمت کره‌ی نورانی نشونه بگیر، و با ماشه شلیک کن."},
	{"title": "دکمه‌ی گریپ (Grip)", "desc": "دکمه‌ی گریپ (کنار دستگیره، زیر انگشتان میانی) رو فشار بده — از این دکمه برای برداشتن وسایل استفاده می‌کنی."},
	{"title": "دسته‌ی آنالوگ (Thumbstick)", "desc": "دسته‌ی آنالوگ سمت چپ رو به هر چهار جهت (بالا، پایین، چپ، راست) فشار بده."},
	{"title": "دکمه‌های A / B / X / Y", "desc": "هر چهار دکمه‌ی روی دسته‌ها رو یکی‌یکی فشار بده."},
	{"title": "دکمه‌ی منو (Menu)", "desc": "دکمه‌ی منو، بالای دسته‌ی چپ، رو فشار بده."},
	{"title": "تله‌پورت", "desc": "دکمه‌ی A دسته‌ی راست رو نگه‌دار تا لیزر روشن بشه، به‌سمت دایره‌ی روی زمین نشونه بگیر، و ماشه رو بزن تا به اونجا منتقل بشی."},
	{"title": "حرکت نرم (Smooth Locomotion)", "desc": "با فشار دادن دسته‌ی آنالوگ چپ به‌سمت جلو، از میان دروازه‌ی نورانی عبور کن."},
	{"title": "پیچ‌گوشتی — بستن پیچ", "desc": "برو کنار میز کار. پیچ‌گوشتی رو با گریپ بردار، نزدیک پیچ نگه‌دار و ماشه رو نگه‌دار تا پیچ سفت بشه."},
	{"title": "قیچی سیم — قطع کردن سیم", "desc": "قیچی سیم رو با گریپ بردار، نزدیک سیم ببر و ماشه رو بزن تا سیم قطع بشه."},
	{"title": "برداشتن و جاگذاری قطعه", "desc": "مکعب کوچیک رو با گریپ بردار و داخل کادر مشخص‌شده روی میز رها کن."},
	{"title": "آفرین! آموزش تمام شد", "desc": "حالا می‌تونی آزادانه توی محیط حرکت کنی.\nمرکز منابع یادگیری — اداره آموزش و تعالی منابع انسانی شرکت پالایش نفت اصفهان"},
]

func _ready() -> void:
	xr_origin = get_node("XROrigin")
	xr_camera = get_node("XROrigin/XRCamera")
	left_controller = get_node("XROrigin/LeftController")
	right_controller = get_node("XROrigin/RightController")

	_build_room()
	_build_decorations()
	_build_desk_and_tools()
	_build_controller_rays()
	_build_trigger_target()
	_build_teleport_marker()
	_build_locomotion_gate()
	_build_hud()
	_build_skip_button()
	_refresh_hud()

	left_controller.button_pressed.connect(_on_button_pressed.bind(left_controller, "left"))
	right_controller.button_pressed.connect(_on_button_pressed.bind(right_controller, "right"))
	left_controller.button_released.connect(_on_button_released.bind(left_controller, "left"))
	right_controller.button_released.connect(_on_button_released.bind(right_controller, "right"))

func _process(delta: float) -> void:
	left_ray.visible = left_controller.is_button_pressed("ax_button")
	right_ray.visible = right_controller.is_button_pressed("ax_button")

	if held_object != null and held_by_controller != null:
		held_object.global_transform.origin = held_by_controller.global_transform.origin

	if current_step == 3:
		_check_stick_directions()
	if current_step == 8:
		_check_screwdriver_task(delta)
	if locomotion_enabled:
		_handle_smooth_locomotion(delta)
	if turn_cooldown > 0.0:
		turn_cooldown -= delta

# ---------- ساخت محیط ----------

func _build_room() -> void:
	# کف سرامیکی
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.8, 0.79, 0.76)
	floor_mat.roughness = 0.15
	floor_mat.metallic = 0.05
	var floor_instance := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24, 24)
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_mat
	add_child(floor_instance)

	# خط‌های کاشی سرامیک
	var grout_mat := StandardMaterial3D.new()
	grout_mat.albedo_color = Color(0.6, 0.59, 0.56)
	var g := -11.0
	while g <= 11.0:
		var line_x := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(24, 0.005, 0.02)
		line_x.mesh = lm
		line_x.material_override = grout_mat
		line_x.position = Vector3(0, 0.003, g)
		add_child(line_x)

		var line_z := MeshInstance3D.new()
		var lm2 := BoxMesh.new()
		lm2.size = Vector3(0.02, 0.005, 24)
		line_z.mesh = lm2
		line_z.material_override = grout_mat
		line_z.position = Vector3(g, 0.003, 0)
		add_child(line_z)
		g += 2.0

	# دیوارها با دیوارکوب چوبی
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.58, 0.4, 0.24)
	wall_mat.roughness = 0.75

	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.48, 0.32, 0.18)

	var back_wall := MeshInstance3D.new()
	var back_wall_mesh := BoxMesh.new()
	back_wall_mesh.size = Vector3(14, 5, 0.15)
	back_wall.mesh = back_wall_mesh
	back_wall.material_override = wall_mat
	back_wall.position = Vector3(0, 2.5, -6)
	add_child(back_wall)

	var left_wall := MeshInstance3D.new()
	var side_wall_mesh := BoxMesh.new()
	side_wall_mesh.size = Vector3(0.15, 5, 16)
	left_wall.mesh = side_wall_mesh
	left_wall.material_override = wall_mat
	left_wall.position = Vector3(-7, 2.5, -1)
	add_child(left_wall)

	var right_wall := MeshInstance3D.new()
	right_wall.mesh = side_wall_mesh
	right_wall.material_override = wall_mat
	right_wall.position = Vector3(7, 2.5, -1)
	add_child(right_wall)

	# نوارهای عمودی دیوارکوب (جلوه‌ی پنل چوبی)
	var pz := -12.5
	while pz <= 6.5:
		for side_x in [-6.92, 6.92]:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(0.02, 4.8, 0.06)
			strip.mesh = strip_mesh
			strip.material_override = panel_mat
			strip.position = Vector3(side_x, 2.5, pz)
			add_child(strip)
		pz += 2.0

	var bx := -6.5
	while bx <= 6.5:
		var strip2 := MeshInstance3D.new()
		var strip2_mesh := BoxMesh.new()
		strip2_mesh.size = Vector3(0.06, 4.8, 0.02)
		strip2.mesh = strip2_mesh
		strip2.material_override = panel_mat
		strip2.position = Vector3(bx, 2.5, -5.92)
		add_child(strip2)
		bx += 2.0

	var title_label := Label3D.new()
	title_label.text = "مرکز منابع یادگیری"
	title_label.position = Vector3(6.8, 3.4, -3.0)
	title_label.rotation_degrees = Vector3(0, -90, 0)
	title_label.pixel_size = 0.006
	title_label.font_size = 56
	title_label.outline_size = 10
	title_label.modulate = Color(1, 0.85, 0.4)
	add_child(title_label)

	var org_label := Label3D.new()
	org_label.text = "اداره آموزش و تعالی منابع انسانی شرکت پالایش نفت اصفهان"
	org_label.position = Vector3(6.8, 3.0, -3.0)
	org_label.rotation_degrees = Vector3(0, -90, 0)
	org_label.pixel_size = 0.0028
	org_label.font_size = 34
	org_label.outline_size = 6
	org_label.modulate = Color(0.85, 0.9, 0.95)
	add_child(org_label)

	var logo_texture: Texture2D = load("res://assets/logo.png")
	if logo_texture:
		var logo_sprite := Sprite3D.new()
		logo_sprite.texture = logo_texture
		logo_sprite.pixel_size = 0.0026
		logo_sprite.position = Vector3(0, 4.3, -5.9)
		add_child(logo_sprite)

func _build_decorations() -> void:
	# پنجره‌های شیشه‌ای رو به منظره‌ی صنعتی
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.75, 0.88, 0.95, 0.35)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.4, 0.27, 0.15)

	for z_pos in [-3.0, -8.0]:
		for wall_x in [-6.9, 6.9]:
			var window_glass := MeshInstance3D.new()
			var glass_mesh := PlaneMesh.new()
			glass_mesh.size = Vector2(1.6, 2.0)
			window_glass.mesh = glass_mesh
			window_glass.material_override = glass_mat
			window_glass.rotation_degrees = Vector3(0, 90, 0)
			window_glass.position = Vector3(wall_x, 2.2, z_pos)
			add_child(window_glass)

			var window_frame := MeshInstance3D.new()
			var frame_mesh := BoxMesh.new()
			frame_mesh.size = Vector3(0.08, 2.1, 1.7)
			window_frame.mesh = frame_mesh
			window_frame.material_override = frame_mat
			window_frame.position = Vector3(wall_x, 2.2, z_pos)
			add_child(window_frame)

	_build_refinery_skyline(-11.0)
	_build_refinery_skyline(11.0)

	# گلدان‌ها: ساسانسیوریا و دیفن‌باخیا
	_make_sansevieria(Vector3(-6.3, 0, -0.5))
	_make_dieffenbachia(Vector3(6.3, 0, -0.5))
	_make_sansevieria(Vector3(6.3, 0, -5.3))
	_make_dieffenbachia(Vector3(-6.3, 0, -5.3))

	_build_wall_posters()

func _build_refinery_skyline(x_side: float) -> void:
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.55, 0.58, 0.6)
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.4, 0.42, 0.45)
	var flare_mat := StandardMaterial3D.new()
	flare_mat.albedo_color = Color(1.0, 0.5, 0.1)
	flare_mat.emission_enabled = true
	flare_mat.emission = Color(1.0, 0.5, 0.1)
	flare_mat.emission_energy_multiplier = 2.0

	var z_positions := [-2.0, -4.5, -7.0, -9.5]
	var heights := [4.0, 6.5, 3.5, 5.5]
	for i in range(z_positions.size()):
		var tower := MeshInstance3D.new()
		var tower_mesh := CylinderMesh.new()
		tower_mesh.top_radius = 0.5
		tower_mesh.bottom_radius = 0.6
		tower_mesh.height = heights[i]
		tower.mesh = tower_mesh
		tower.material_override = tower_mat
		tower.position = Vector3(x_side, heights[i] / 2.0, z_positions[i])
		add_child(tower)

	# دودکش مشعل (فلر)
	var stack := MeshInstance3D.new()
	var stack_mesh := CylinderMesh.new()
	stack_mesh.top_radius = 0.12
	stack_mesh.bottom_radius = 0.18
	stack_mesh.height = 8.0
	stack.mesh = stack_mesh
	stack.material_override = pipe_mat
	stack.position = Vector3(x_side, 4.0, -6.0)
	add_child(stack)

	var flare := MeshInstance3D.new()
	var flare_mesh := SphereMesh.new()
	flare_mesh.radius = 0.35
	flare_mesh.height = 0.7
	flare.mesh = flare_mesh
	flare.material_override = flare_mat
	flare.position = Vector3(x_side, 8.1, -6.0)
	add_child(flare)

func _make_sansevieria(pos: Vector3) -> void:
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.55, 0.52, 0.48)
	var pot := MeshInstance3D.new()
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.2
	pot_mesh.bottom_radius = 0.15
	pot_mesh.height = 0.32
	pot.mesh = pot_mesh
	pot.material_override = pot_mat
	pot.position = pos + Vector3(0, 0.16, 0)
	add_child(pot)

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.15, 0.42, 0.2)
	var blade_count := 6
	for i in range(blade_count):
		var leaf := MeshInstance3D.new()
		var leaf_mesh := BoxMesh.new()
		var h := 0.55 + (i % 3) * 0.12
		leaf_mesh.size = Vector3(0.05, h, 0.012)
		leaf.mesh = leaf_mesh
		leaf.material_override = leaf_mat
		var angle := i * (TAU / blade_count)
		var tilt := 6.0 + (i % 2) * 4.0
		leaf.position = pos + Vector3(cos(angle) * 0.08, 0.32 + h / 2.0, sin(angle) * 0.08)
		leaf.rotation_degrees = Vector3(tilt, rad_to_deg(angle), 0)
		add_child(leaf)

func _make_dieffenbachia(pos: Vector3) -> void:
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.6, 0.3, 0.2)
	var pot := MeshInstance3D.new()
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.22
	pot_mesh.bottom_radius = 0.16
	pot_mesh.height = 0.35
	pot.mesh = pot_mesh
	pot.material_override = pot_mat
	pot.position = pos + Vector3(0, 0.175, 0)
	add_child(pot)

	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.35, 0.5, 0.25)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.45, 0.68, 0.3)

	var leaf_count := 5
	for i in range(leaf_count):
		var angle := i * (TAU / leaf_count)
		var stem_h := 0.3 + (i % 2) * 0.1
		var stem := MeshInstance3D.new()
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.012
		stem_mesh.bottom_radius = 0.016
		stem_mesh.height = stem_h
		stem.mesh = stem_mesh
		stem.material_override = stem_mat
		stem.position = pos + Vector3(cos(angle) * 0.05, 0.35 + stem_h / 2.0, sin(angle) * 0.05)
		stem.rotation_degrees = Vector3(20.0, rad_to_deg(angle), 0)
		add_child(stem)

		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.16
		leaf_mesh.height = 0.32
		leaf.mesh = leaf_mesh
		leaf.material_override = leaf_mat
		leaf.scale = Vector3(1.0, 0.35, 0.65)
		leaf.position = pos + Vector3(cos(angle) * 0.16, 0.62 + stem_h * 0.3, sin(angle) * 0.16)
		leaf.rotation_degrees = Vector3(15.0, rad_to_deg(angle), 0)
		add_child(leaf)

func _build_wall_posters() -> void:
	var poster_texts := [
		"واقعیت مجازی چیست؟\nیک محیط سه‌بعدی شبیه‌سازی‌شده که با هدست تجربه می‌شود",
		"نکته‌ی ایمنی\nهنگام حرکت، فضای اطراف خود در دنیای واقعی را در نظر بگیرید",
		"دسته‌ها را محکم نگه دارید\nاز بند مچی برای جلوگیری از افتادن دسته استفاده کنید",
	]
	var poster_positions := [
		{"pos": Vector3(-6.85, 2.3, -1.5), "rot": 90.0},
		{"pos": Vector3(-6.85, 2.3, -6.5), "rot": 90.0},
		{"pos": Vector3(6.85, 2.3, -1.5), "rot": -90.0},
	]
	var backing_mat := StandardMaterial3D.new()
	backing_mat.albedo_color = Color(0.95, 0.94, 0.9)

	for i in range(poster_positions.size()):
		var info = poster_positions[i]
		var backing := MeshInstance3D.new()
		var backing_mesh := PlaneMesh.new()
		backing_mesh.size = Vector2(1.0, 0.65)
		backing.mesh = backing_mesh
		backing.material_override = backing_mat
		backing.rotation_degrees = Vector3(0, info["rot"], 0)
		backing.position = info["pos"]
		add_child(backing)

		var caption := Label3D.new()
		caption.text = poster_texts[i]
		caption.rotation_degrees = Vector3(0, info["rot"], 0)
		caption.position = info["pos"] + Vector3(0, 0, 0.01) * (1 if info["rot"] > 0 else -1)
		caption.pixel_size = 0.0012
		caption.font_size = 24
		caption.modulate = Color(0.15, 0.15, 0.18)
		caption.width = 380
		add_child(caption)

func _build_desk_and_tools() -> void:
	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.45, 0.32, 0.2)

	var desk := MeshInstance3D.new()
	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(1.6, 0.08, 0.8)
	desk.mesh = desk_mesh
	desk.material_override = desk_mat
	desk.position = Vector3(-4.5, 0.75, -2.0)
	add_child(desk)

	for x_off in [-0.7, 0.7]:
		for z_off in [-0.32, 0.32]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.06, 0.75, 0.06)
			leg.mesh = leg_mesh
			leg.material_override = desk_mat
			leg.position = Vector3(-4.5 + x_off, 0.375, -2.0 + z_off)
			add_child(leg)

	var desk_top_y := 0.79

	# پیچ‌گوشتی شارژی (قابل برداشتن)
	screwdriver_tool = _build_screwdriver(Vector3(-4.9, desk_top_y + 0.03, -2.15))
	grabbables.append({"body": screwdriver_tool, "id": "screwdriver"})

	# پیچ (هدف پیچ‌گوشتی)
	bolt_target = MeshInstance3D.new()
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = 0.03
	bolt_mesh.bottom_radius = 0.03
	bolt_mesh.height = 0.05
	bolt_target.mesh = bolt_mesh
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.6, 0.6, 0.65)
	bolt_target.material_override = bolt_mat
	bolt_target.position = Vector3(-4.5, desk_top_y + 0.03, -2.15)
	add_child(bolt_target)

	# قیچی سیم (قابل برداشتن)
	cutter_tool = _build_wire_cutter(Vector3(-4.1, desk_top_y + 0.03, -2.15))
	grabbables.append({"body": cutter_tool, "id": "cutter"})

	# سیم (هدف قیچی)
	wire_target = MeshInstance3D.new()
	var wire_mesh := CylinderMesh.new()
	wire_mesh.top_radius = 0.012
	wire_mesh.bottom_radius = 0.012
	wire_mesh.height = 0.4
	wire_target.mesh = wire_mesh
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.15, 0.6, 0.2)
	wire_target.material_override = wire_mat
	wire_target.rotation_degrees = Vector3(0, 0, 90)
	wire_target.position = Vector3(-4.3, desk_top_y + 0.02, -1.85)
	add_child(wire_target)

	# مکعب قابل جابه‌جایی
	movable_object = _make_grabbable_tool(Vector3(-4.7, desk_top_y, -1.75), Color(0.3, 0.55, 0.9), Vector3(0.08, 0.08, 0.08))
	grabbables.append({"body": movable_object, "id": "movable"})

	# کادر مقصد
	drop_zone = MeshInstance3D.new()
	var zone_mesh := BoxMesh.new()
	zone_mesh.size = Vector3(0.22, 0.01, 0.22)
	drop_zone.mesh = zone_mesh
	var zone_mat := StandardMaterial3D.new()
	zone_mat.albedo_color = Color(0.3, 0.9, 0.5, 0.6)
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.emission_enabled = true
	zone_mat.emission = Color(0.3, 0.9, 0.5)
	zone_mat.emission_energy_multiplier = 0.5
	drop_zone.material_override = zone_mat
	drop_zone.position = Vector3(-4.2, desk_top_y + 0.005, -1.75)
	add_child(drop_zone)

func _make_grabbable_tool(pos: Vector3, color: Color, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	body.position = pos
	add_child(body)
	return body

func _build_screwdriver(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()

	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.95, 0.7, 0.05)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.022
	handle_mesh.bottom_radius = 0.022
	handle_mesh.height = 0.11
	handle.mesh = handle_mesh
	handle.material_override = handle_mat
	handle.rotation_degrees = Vector3(0, 0, 90)
	handle.position = Vector3(-0.07, 0, 0)
	body.add_child(handle)

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.75, 0.76, 0.78)
	shaft_mat.metallic = 0.6
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.006
	shaft_mesh.bottom_radius = 0.006
	shaft_mesh.height = 0.13
	shaft.mesh = shaft_mesh
	shaft.material_override = shaft_mat
	shaft.rotation_degrees = Vector3(0, 0, 90)
	shaft.position = Vector3(0.05, 0, 0)
	body.add_child(shaft)

	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.015, 0.008, 0.03)
	tip.mesh = tip_mesh
	tip.material_override = shaft_mat
	tip.position = Vector3(0.115, 0, 0)
	body.add_child(tip)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.24, 0.05, 0.05)
	collision.shape = shape
	body.add_child(collision)

	body.position = pos
	add_child(body)
	return body

func _build_wire_cutter(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()

	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.8, 0.15, 0.15)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.8, 0.82, 0.85)
	blade_mat.metallic = 0.7

	for side_sign in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.16, 0.012, 0.018)
		arm.mesh = arm_mesh
		arm.material_override = handle_mat
		arm.rotation_degrees = Vector3(0, 0, side_sign * 6.0)
		arm.position = Vector3(-0.05 * side_sign * 0.3, 0, 0)
		body.add_child(arm)

		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.05, 0.01, 0.012)
		blade.mesh = blade_mesh
		blade.material_override = blade_mat
		blade.rotation_degrees = Vector3(0, 0, side_sign * 6.0)
		blade.position = Vector3(0.105, side_sign * 0.006, 0)
		body.add_child(blade)

	var pivot := MeshInstance3D.new()
	var pivot_mesh := CylinderMesh.new()
	pivot_mesh.top_radius = 0.012
	pivot_mesh.bottom_radius = 0.012
	pivot_mesh.height = 0.02
	pivot.mesh = pivot_mesh
	pivot.rotation_degrees = Vector3(90, 0, 0)
	pivot.material_override = blade_mat
	pivot.position = Vector3(0.04, 0, 0)
	body.add_child(pivot)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.22, 0.04, 0.04)
	collision.shape = shape
	body.add_child(collision)

	body.position = pos
	add_child(body)
	return body

func _build_controller_rays() -> void:
	left_ray = _make_ray_mesh()
	left_controller.add_child(left_ray)
	right_ray = _make_ray_mesh()
	right_controller.add_child(right_ray)

func _make_ray_mesh() -> MeshInstance3D:
	var ray := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 1.0
	ray.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.2
	ray.material_override = mat
	ray.rotation_degrees = Vector3(-90, 0, 0)
	ray.position = Vector3(0, 0, -0.5)
	return ray

func _build_trigger_target() -> void:
	trigger_target = StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.55, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.55, 0.2)
	mat.emission_energy_multiplier = 0.8
	mesh_instance.material_override = mat
	trigger_target.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	collision.shape = shape
	trigger_target.add_child(collision)

	trigger_target.position = Vector3(0, 1.4, -1.0)
	add_child(trigger_target)

func _build_teleport_marker() -> void:
	teleport_marker = StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.5
	mesh_instance.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 0.5)
	mat.emission_energy_multiplier = 0.9
	mesh_instance.material_override = mat
	teleport_marker.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.05
	collision.shape = shape
	teleport_marker.add_child(collision)

	teleport_marker.position = Vector3(2.5, 0.03, -3.5)
	teleport_marker.visible = false
	add_child(teleport_marker)

func _build_locomotion_gate() -> void:
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.3, 0.6, 0.95)
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(0.3, 0.6, 0.95)
	pillar_mat.emission_energy_multiplier = 0.7

	gate_left = MeshInstance3D.new()
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.1, 2.2, 0.1)
	gate_left.mesh = pillar_mesh
	gate_left.material_override = pillar_mat
	gate_left.position = Vector3(-0.9, 1.1, -8.5)
	gate_left.visible = false
	add_child(gate_left)

	gate_right = MeshInstance3D.new()
	gate_right.mesh = pillar_mesh
	gate_right.material_override = pillar_mat
	gate_right.position = Vector3(0.9, 1.1, -8.5)
	gate_right.visible = false
	add_child(gate_right)

	gate_trigger_area = Area3D.new()
	var area_collision := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(2.0, 2.2, 0.3)
	area_collision.shape = area_shape
	gate_trigger_area.add_child(area_collision)
	gate_trigger_area.position = Vector3(0, 1.1, -8.5)
	gate_trigger_area.visible = false
	gate_trigger_area.body_entered.connect(_on_gate_entered)
	add_child(gate_trigger_area)

func _build_hud() -> void:
	step_label = Label3D.new()
	step_label.position = Vector3(0, 2.0, -1.4)
	step_label.pixel_size = 0.0032
	step_label.font_size = 44
	step_label.outline_size = 10
	step_label.modulate = Color(1, 0.85, 0.4)
	add_child(step_label)

	desc_label = Label3D.new()
	desc_label.position = Vector3(0, 1.7, -1.4)
	desc_label.pixel_size = 0.0022
	desc_label.font_size = 32
	desc_label.outline_size = 6
	desc_label.modulate = Color(0.92, 0.92, 0.92)
	desc_label.width = 900
	add_child(desc_label)

	hint_label = Label3D.new()
	hint_label.position = Vector3(0, 1.45, -1.4)
	hint_label.pixel_size = 0.0018
	hint_label.font_size = 26
	hint_label.modulate = Color(0.4, 0.85, 1.0)
	add_child(hint_label)

func _build_skip_button() -> void:
	skip_button = StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.12, 0.02)
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.55)
	mesh_instance.material_override = mat
	skip_button.add_child(mesh_instance)

	var label := Label3D.new()
	label.text = "رد شدن ›"
	label.pixel_size = 0.0012
	label.font_size = 28
	label.position = Vector3(0, 0, 0.02)
	skip_button.add_child(label)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 0.12, 0.02)
	collision.shape = shape
	skip_button.add_child(collision)

	skip_button.position = Vector3(0.85, 1.55, -1.4)
	add_child(skip_button)

func _refresh_hud() -> void:
	var s = steps_data[current_step]
	step_label.text = "مرحله %d از %d — %s" % [current_step + 1, steps_data.size(), s["title"]]
	desc_label.text = s["desc"]

	trigger_target.visible = (current_step == 1)
	teleport_marker.visible = (current_step == 6) or teleport_enabled
	gate_left.visible = (current_step == 7) or locomotion_enabled
	gate_right.visible = (current_step == 7) or locomotion_enabled
	gate_trigger_area.visible = (current_step == 7)
	skip_button.visible = (current_step < steps_data.size() - 1)

	if current_step == 3:
		hint_label.text = "پیشرفت: %d از ۴ جهت" % _count_done(stick_directions_done)
	elif current_step == 4:
		hint_label.text = "پیشرفت: %d از ۴ دکمه" % _count_done(face_buttons_done)
	else:
		hint_label.text = ""

	if current_step == 6:
		teleport_enabled = true
	if current_step == 7:
		locomotion_enabled = true

func _count_done(d: Dictionary) -> int:
	var c := 0
	for k in d:
		if d[k]:
			c += 1
	return c

func _advance_step() -> void:
	current_step += 1
	if current_step >= steps_data.size():
		current_step = steps_data.size() - 1
	bolt_progress = 0.0
	_refresh_hud()

# ---------- کمکی: نشونه‌گیری ----------

func _points_at(controller: XRController3D, target: Node3D) -> bool:
	var origin: Vector3 = controller.global_transform.origin
	var direction: Vector3 = -controller.global_transform.basis.z
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 10.0)
	var result := space_state.intersect_ray(query)
	return not result.is_empty() and result["collider"] == target

# ---------- منطق دکمه‌ها ----------

func _on_button_pressed(button_name: String, controller: XRController3D, side: String) -> void:
	if button_name == "trigger_click":
		if current_step < steps_data.size() - 1 and _points_at(controller, skip_button):
			_advance_step()
			return

	if button_name == "grip_click":
		_try_grab(controller)

	match current_step:
		0:
			if button_name == "trigger_click":
				_advance_step()
		1:
			if button_name == "trigger_click" and _points_at(controller, trigger_target):
				_advance_step()
		2:
			if button_name == "grip_click":
				_advance_step()
		4:
			if button_name == "ax_button" or button_name == "by_button":
				var key := side + "_" + ("ax" if button_name == "ax_button" else "by")
				if face_buttons_done.has(key):
					face_buttons_done[key] = true
					_refresh_hud()
					if _count_done(face_buttons_done) >= 4:
						_advance_step()
		5:
			if button_name == "menu_button":
				_advance_step()
		6:
			if (button_name == "trigger_click" or button_name == "primary_click") and _points_at(controller, teleport_marker):
				var target_pos: Vector3 = teleport_marker.global_transform.origin
				xr_origin.global_transform.origin = Vector3(target_pos.x, xr_origin.global_transform.origin.y, target_pos.z)
				_advance_step()
		9:
			if button_name == "trigger_click" and held_object == cutter_tool:
				if held_object.global_transform.origin.distance_to(wire_target.global_transform.origin) < 0.3:
					wire_target.visible = false
					_advance_step()

func _on_button_released(button_name: String, controller: XRController3D, side: String) -> void:
	if button_name == "grip_click":
		_try_release_grab(controller)

func _try_grab(controller: XRController3D) -> void:
	if held_object != null:
		return
	for entry in grabbables:
		var body: Node3D = entry["body"]
		if body.global_transform.origin.distance_to(controller.global_transform.origin) < 0.35:
			held_object = body
			held_by_controller = controller
			return

func _try_release_grab(controller: XRController3D) -> void:
	if held_by_controller != controller or held_object == null:
		return
	if current_step == 10 and held_object == movable_object:
		if movable_object.global_transform.origin.distance_to(drop_zone.global_transform.origin) < 0.28:
			movable_object.global_transform.origin = drop_zone.global_transform.origin + Vector3(0, 0.04, 0)
			_advance_step()
	held_object = null
	held_by_controller = null

func _check_stick_directions() -> void:
	var v: Vector2 = left_controller.get_vector2("primary")
	var changed := false
	if v.y < -0.6 and not stick_directions_done["up"]:
		stick_directions_done["up"] = true
		changed = true
	if v.y > 0.6 and not stick_directions_done["down"]:
		stick_directions_done["down"] = true
		changed = true
	if v.x < -0.6 and not stick_directions_done["left"]:
		stick_directions_done["left"] = true
		changed = true
	if v.x > 0.6 and not stick_directions_done["right"]:
		stick_directions_done["right"] = true
		changed = true
	if changed:
		_refresh_hud()
		if _count_done(stick_directions_done) >= 4:
			_advance_step()

func _check_screwdriver_task(delta: float) -> void:
	if held_object == screwdriver_tool and held_by_controller != null:
		if held_object.global_transform.origin.distance_to(bolt_target.global_transform.origin) < 0.3:
			if held_by_controller.is_button_pressed("trigger_click"):
				bolt_progress += delta
				bolt_target.rotate_y(delta * 6.0)
				if bolt_progress >= 1.5:
					_advance_step()

func _on_gate_entered(_body: Node3D) -> void:
	if current_step == 7:
		_advance_step()

# ---------- حرکت ----------

func _handle_smooth_locomotion(delta: float) -> void:
	var v: Vector2 = left_controller.get_vector2("primary")
	if v.length() > 0.15:
		var cam_basis: Basis = xr_camera.global_transform.basis
		var forward: Vector3 = -cam_basis.z
		var right: Vector3 = cam_basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		var move_dir: Vector3 = (forward * v.y + right * v.x)
		xr_origin.global_transform.origin += move_dir * move_speed * delta

	if turn_cooldown <= 0.0:
		var rv: Vector2 = right_controller.get_vector2("primary")
		if rv.x > 0.6:
			xr_origin.rotate_y(deg_to_rad(-30))
			turn_cooldown = 0.35
		elif rv.x < -0.6:
			xr_origin.rotate_y(deg_to_rad(30))
			turn_cooldown = 0.35
