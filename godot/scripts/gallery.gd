# Starfall Vanguard: pose gallery. A close-up line of troopers frozen in each movement pose, so the crouch, vault and
# climb animations can be checked by eye. Run: godot --path . res://scenes/gallery.tscn -- --sv-test
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D

var models := []
var t := 0.0

func _ready() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("30343c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("8a8f99"); env.ambient_light_energy = .7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -40, 0); sun.shadow_enabled = true; sun.light_energy = 1.2; add_child(sun)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("57534c")
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); g.mesh = pm; g.material_override = gm; add_child(g)
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color("8a8478")
	# label, x, state, obstacle height (0 = none). Each trooper faces +x and its obstacle sits just ahead of it;
	# the camera looks from the side so forward runs left to right across the frame.
	var poses := [
		["stand", -12.0, {}, 0.0],
		["crouch", -8.0, {"crouch": 1.0}, 0.0],
		["vault", -4.0, {"climb_kind": "vault", "climb_u": .45}, .85],
		["climb 30%", 1.5, {"climb_kind": "climb", "climb_u": .3}, 1.6],
		["climb 75%", 7.0, {"climb_kind": "climb", "climb_u": .75}, 1.6],
	]
	for p in poses:
		var x: float = p[1]; var st: Dictionary = p[2]; var oh: float = p[3]
		var root := Vector3(x, 0, 0)
		if oh > 0:
			var ob := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(2.0, oh, 1.2); ob.mesh = b; ob.material_override = bm
			ob.position = Vector3(x + .75 + .6, oh / 2, 0); ob.rotation.y = PI / 2; add_child(ob)
			st.climb_ledge = Vector3(x + .75, oh, 0); st.climb_h = oh
			var u: float = st.climb_u
			if st.climb_kind == "vault": root = Vector3(x + lerp(0.0, 2.6, smoothstep(0.0, 1.0, u)), (oh + .08) * sin(PI * min(1.0, u * 1.15)), 0)
			elif u < .55: root = Vector3(x + .37, (oh + .05) * smoothstep(0.0, 1.0, u / .55), 0)
			else: root = Vector3(x + lerp(.37, 1.3, smoothstep(0.0, 1.0, (u - .55) / .45)), oh, 0)
		var m := Trooper.new(); add_child(m); m.position = root
		m.build("drakeguard", "dragon", Game.FACTIONS.wyrm, false, "rifle")
		st.aim = PI / 2; models.append([m, st])
	var cam := Camera3D.new(); cam.fov = 40; add_child(cam); cam.position = Vector3(-2, 2.2, 17); cam.look_at(Vector3(-2, 1.0, 0))

func _process(dt: float) -> void:
	t += dt
	for p in models: (p[0] as Trooper).pose(1.0 / 60.0, p[1])
	if t > 1.0 and not has_meta("one"):
		set_meta("one", true); get_viewport().get_texture().get_image().save_png("user://t_gallery.png")
		var cam: Camera3D = get_viewport().get_camera_3d(); cam.position = Vector3(-6, 3.0, -9); cam.look_at(Vector3(-2, 1.0, 0))
	if t > 1.4:
		get_viewport().get_texture().get_image().save_png("user://t_gallery2.png"); get_tree().quit()
