# Test probe (not part of the game): the Drakeguard in a standing pose under studio light, front three-quarter and back,
# to compare with the concept image. MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3).
extends Node3D
var m: Trooper; var cam: Camera3D; var shot := 0
func _ready() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("c9cbcd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("b8bcc2"); env.ambient_light_energy = .7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; we.environment = env; add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-30, 35, 0); key.light_energy = 1.4; key.shadow_enabled = true; add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20, 160, 0); rim.light_energy = 1.0; add_child(rim)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("b4b7ba"); g.material_override = gm; add_child(g)
	var armor := "drakeguard_hd" if "--hd" in OS.get_cmdline_user_args() else "drakeguard"
	m = Trooper.new(); add_child(m)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shift="):
			var v := a.trim_prefix("--shift=").split_floats(",")
			m.gun_shift = Vector3(v[0], v[1], v[2])
		if a.begins_with("--gscale="): m.gun_scale = float(a.trim_prefix("--gscale="))
	var weapon := "rifle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="): weapon = a.trim_prefix("--weapon=")
	m.build(armor, "dragon", Game.FACTIONS.wyrm, true, weapon)
	cam = Camera3D.new(); cam.fov = 26; add_child(cam); _cam(0)
func _cam(i: int) -> void:
	var a: float = [1.0, PI + .5, .75][i]; var dist: float = [4.6, 4.6, 1.6][i]; var y: float = [1.0, 1.0, 1.6][i]
	cam.position = Vector3(sin(a) * dist, y + .25, cos(a) * dist); cam.look_at(Vector3(0, y, 0))
# shots are taken on fixed frames, not on the clock, so the same command gives the same pictures every run
var f := 0
func _process(_dt: float) -> void:
	f += 1
	var st := {"aim": 0.0, "world_move": Vector3.ZERO}
	var args := OS.get_cmdline_user_args()
	if "--crouchwalk" in args: st.merge({"moving": true, "speed": 2.0, "move_yaw": 0.0, "crouch": 1.0}, true)
	if "--reload" in args: st.merge({"reload": .5}, true)
	if "--climb" in args: st.merge({"climb_kind": "climb", "climb_u": .4, "climb_ledge": Vector3(0, 1.6, .5)}, true)
	if f <= 60: m.pose(1.0 / 60.0, st)
	if f == 60: _grips()
	if f == 63: get_viewport().get_texture().get_image().save_png("user://t_drake_front.png"); _cam(1)
	elif f == 66: get_viewport().get_texture().get_image().save_png("user://t_drake_back.png"); _cam(2)
	elif f == 69: get_viewport().get_texture().get_image().save_png("user://t_drake_close.png"); get_tree().quit()

# how far each hand's grip point (the palm on the HD model) is from the weapon grip it should close on
func _grips() -> void:
	for side in ["r", "l"]:
		var R: Node3D = m.arm_r if side == "r" else m.arm_l
		var F: Node3D = R.get_meta("fore")
		var d: Vector3 = m.hand_dir if side == "r" else m.hand_dir * Vector3(-1, 1, 1)
		var palm: Vector3 = F.global_transform * (d * m.hand_len)
		var tgt: Vector3 = m.gun.get_parent().global_transform * (m.gun.transform * (m.hold.rg if side == "r" else m.hold.lg))
		print("GRIP %s palm to grip %.3f m" % [side, palm.distance_to(tgt)])
	print("GUN scale %.2f at %s" % [m.gun.scale.x, m.gun.position])
