# Test probe (not part of the game): every exosuit in the roster side by side, mid-stride, from the front and the back,
# on fixed frames so runs repeat. Writes user://t_suits_front.png and user://t_suits_back.png.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D
var f := 0; var models := []; var cam: Camera3D
func _ready() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("3a3f3c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("9aa0a6"); env.ambient_light_energy = .8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; we.environment = env; add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, 25, 0); key.light_energy = 1.7; key.shadow_enabled = true; add_child(key)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 200, 0); fill.light_energy = .8; add_child(fill)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 12); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("343936"); g.material_override = gm; add_child(g)
	var n := Game.SUIT_ORDER.size()
	for i in n:
		var su: Dictionary = Game.SUITS[Game.SUIT_ORDER[i]]
		var m := Trooper.new(); add_child(m); m.position = Vector3((i - (n - 1) / 2.0) * 1.3, 0, 0)
		m.build(su.kit, su.helm, Game.FACTIONS.wyrm, "--cape" in OS.get_cmdline_user_args(), "rifle"); models.append(m)
	cam = Camera3D.new(); cam.fov = 30; add_child(cam); _cam(0)
func _cam(i: int) -> void:
	var z := 10.4 if i == 0 else -10.4
	cam.position = Vector3(0, 1.4, z); cam.look_at(Vector3(0, 1.0, 0))
func _process(_dt: float) -> void:
	f += 1
	if f <= 40:
		for m in models: (m as Trooper).pose(1.0 / 60.0, {"aim": .35, "moving": true, "speed": 1.2, "move_yaw": .35})
	if f == 43: get_viewport().get_texture().get_image().save_png("user://t_suits_front.png"); _cam(1)
	elif f == 46: get_viewport().get_texture().get_image().save_png("user://t_suits_back.png"); get_tree().quit()
