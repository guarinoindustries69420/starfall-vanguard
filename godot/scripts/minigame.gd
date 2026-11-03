# Starfall Vanguard: what every hearts-and-minds event shares. Lighting, a 3-2-1 start, a clock, a scoreboard, a result
# banner and the finished signal. The player's controls come through input(), so test mode can hand the wheel to an
# autopilot and the event still runs exactly as it would for a person.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D
class_name MiniGame

signal finished(won: bool, summary: String)

var rival := "swarm"            # the faction competing for the crowd
var biome := "desert"
var world_name := ""
var t := 0.0                    # seconds since the start signal
var countdown := 3.0
var running := false; var done := false
var hud: CanvasLayer; var lbl_title: Label; var lbl_score: Label; var lbl_big: Label; var lbl_help: Label
var autopilot := false          # test mode drives the player with the same logic as a skilled rival
var cam: Camera3D

func title() -> String: return "Event"
func view() -> String: return "ground"      # "ground", "overhead" (high camera, light haze) or "orbit" (space above the world)
func help_pad() -> String: return ""
func help_keys() -> String: return ""

func setup(rival_faction: String, world_biome: String, wname: String) -> void:
	rival = rival_faction; biome = world_biome; world_name = wname; autopilot = Game.test_mode

func _ready() -> void:
	_environment(); _hud(); build()

func build() -> void: pass                 # each event builds its arena here
func step(_dt: float) -> void: pass        # and plays here once the start signal has gone
func score_text() -> String: return ""

func _environment() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	var g: Color = Galaxy.BIOMES[biome].ground
	sm.sky_top_color = Color("1b2a4a"); sm.sky_horizon_color = g.lightened(.35); sm.ground_horizon_color = g; sm.ground_bottom_color = g.darkened(.5)
	if view() == "orbit":
		sm.sky_top_color = Color("02040a"); sm.sky_horizon_color = Color("0b1424"); sm.ground_horizon_color = Color("0b1424"); sm.ground_bottom_color = Color("02040a")
		sm.sky_cover = _starfield()
	sky.sky_material = sm; env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = .5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = .9
	env.glow_enabled = true; env.glow_intensity = .7
	env.fog_enabled = view() != "orbit"; env.fog_light_color = g.lightened(.3); env.fog_density = .006 if view() == "ground" else .0012
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); sun.light_energy = 1.2; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0; add_child(sun)
	cam = Camera3D.new(); cam.fov = 60; cam.far = 600; add_child(cam); cam.make_current()

func _starfield() -> ImageTexture:
	var img := Image.create(1024, 512, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new(); r.seed = 5
	for i in 900:
		var c := r.randf_range(.4, 1.0); img.set_pixel(r.randi() % 1024, r.randi() % 512, Color(c, c, c * 1.05, 1))
	return ImageTexture.create_from_image(img)

func _hud() -> void:
	hud = CanvasLayer.new(); add_child(hud)
	lbl_title = Label.new(); lbl_title.position = Vector2(28, 20); lbl_title.add_theme_font_size_override("font_size", 26); hud.add_child(lbl_title)
	lbl_title.text = "%s  ·  %s" % [title(), world_name]
	lbl_score = Label.new(); lbl_score.position = Vector2(28, 60); lbl_score.add_theme_font_size_override("font_size", 20); hud.add_child(lbl_score)
	lbl_big = Label.new(); lbl_big.set_anchors_preset(Control.PRESET_CENTER); lbl_big.position = Vector2(-300, -60); lbl_big.size = Vector2(600, 120)
	lbl_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_big.add_theme_font_size_override("font_size", 64); hud.add_child(lbl_big)
	lbl_help = Label.new(); lbl_help.anchor_top = 1; lbl_help.anchor_bottom = 1; lbl_help.offset_top = -40; lbl_help.offset_left = 28
	lbl_help.add_theme_font_size_override("font_size", 16); lbl_help.modulate = Color(1, 1, 1, .8); hud.add_child(lbl_help)

func _process(dt: float) -> void:
	lbl_help.text = help_pad() if Game.using_pad else help_keys()
	if done: return
	if not running:
		countdown -= dt
		lbl_big.text = str(int(ceil(countdown))) if countdown > 0 else "GO"
		if countdown <= 0: running = true; Game.say("event_start")
		step_idle(dt); lbl_score.text = score_text(); return
	if t < .8: lbl_big.text = "GO"
	elif lbl_big.text == "GO": lbl_big.text = ""
	t += dt
	step(dt)
	lbl_score.text = score_text()

func step_idle(_dt: float) -> void: pass   # anything that should move before the start (camera framing)

func finish(won: bool, summary: String) -> void:
	if done: return
	done = true; running = false
	lbl_big.text = "YOU WIN" if won else "%s WIN" % Galaxy.FAC[rival].name.to_upper()
	Game.rumble(.5, .5 if won else .2, .4)
	get_tree().create_timer(2.2, false).timeout.connect(func(): finished.emit(won, summary))

# ---- the player's controls, or the autopilot's in test mode ----
func move_vec() -> Vector2: return Input.get_vector("move_left", "move_right", "move_up", "move_down")
func aim_vec() -> Vector2: return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
func pressed(a: String) -> bool: return Input.is_action_pressed(a)
func just(a: String) -> bool: return Input.is_action_just_pressed(a)

# ---- small building blocks ----
func box(size: Vector3, col: Color, pos: Vector3, parent: Node = null, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = mat(col, emissive); mi.position = pos
	(parent if parent else self).add_child(mi); return mi

func ball(r: float, col: Color, pos: Vector3, parent: Node = null, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; mi.mesh = sm; mi.material_override = mat(col, emissive); mi.position = pos
	(parent if parent else self).add_child(mi); return mi

func mat(col: Color, emissive := 0.0, rough := .6, metal := .2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough; m.metallic = metal
	if emissive > 0: m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = emissive
	return m

func ground(size: float, col: Color) -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(size, size); mi.mesh = pm
	var m := mat(col, 0.0, .95, 0.0)
	var n := FastNoiseLite.new(); n.frequency = .02; var tex := NoiseTexture2D.new(); tex.noise = n; tex.seamless = true; tex.as_normal_map = true; tex.bump_strength = 3.0
	m.normal_enabled = true; m.normal_texture = tex; m.uv1_scale = Vector3(size / 12.0, size / 12.0, 1)
	var gt := Game.ground_texture(biome)
	if gt: m.albedo_texture = gt; m.albedo_color = Color(1, 1, 1)
	mi.material_override = m; add_child(mi)

# a small hover craft in a faction's colours: hull, canopy, twin engine pods with glowing exhausts
func craft(fac_color: Color, accent: Color) -> Node3D:
	var n := Node3D.new(); add_child(n)
	box(Vector3(1.0, .35, 2.4), fac_color, Vector3(0, .5, 0), n)
	box(Vector3(.6, .3, .8), Color("10161f"), Vector3(0, .78, .2), n, .0)
	for s in [-1, 1]:
		box(Vector3(.36, .36, 1.5), fac_color.darkened(.35), Vector3(s * .78, .5, -.35), n)
		ball(.16, accent, Vector3(s * .78, .5, -1.12), n, 5.0)
	box(Vector3(2.0, .08, .5), accent, Vector3(0, .55, -.9), n)
	return n

func fac_color(f: String) -> Color: return Galaxy.FAC[f].color
