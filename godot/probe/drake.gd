# Test probe (not part of the game): the Drakeguard in a standing pose under studio light, front three-quarter and back,
# to compare with the concept image. MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3).
extends Node3D
var t := 0.0; var m: Trooper; var cam: Camera3D; var shot := 0
func _ready() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("c9cbcd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("b8bcc2"); env.ambient_light_energy = .7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; we.environment = env; add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-30, 35, 0); key.light_energy = 1.4; key.shadow_enabled = true; add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20, 160, 0); rim.light_energy = 1.0; add_child(rim)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("b4b7ba"); g.material_override = gm; add_child(g)
	var armor := "drakeguard_hd" if "--hd" in OS.get_cmdline_user_args() else "drakeguard"
	m = Trooper.new(); add_child(m); m.build(armor, "dragon", Game.FACTIONS.wyrm, true, "rifle")
	cam = Camera3D.new(); cam.fov = 26; add_child(cam); _cam(0)
func _cam(i: int) -> void:
	var a: float = [1.0, PI + .5, .75][i]; var dist: float = [4.6, 4.6, 1.6][i]; var y: float = [1.0, 1.0, 1.6][i]
	cam.position = Vector3(sin(a) * dist, y + .25, cos(a) * dist); cam.look_at(Vector3(0, y, 0))
func _process(dt: float) -> void:
	t += dt; m.pose(1.0 / 60.0, {"aim": 0.0, "world_move": Vector3.ZERO})
	if t > 1.0 and shot == 0: get_viewport().get_texture().get_image().save_png("user://t_drake_front.png"); shot = 1; _cam(1)
	elif t > 1.3 and shot == 1: get_viewport().get_texture().get_image().save_png("user://t_drake_back.png"); shot = 2; _cam(2)
	elif t > 1.6 and shot == 2: get_viewport().get_texture().get_image().save_png("user://t_drake_close.png"); get_tree().quit()
