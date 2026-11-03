# Test probe (not part of the game): the four reference troopers from the browser build's before/after image, plus the
# Drakeguard, rendered by the PC build's rig and materials under even studio light.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D
var t := 0.0; var models := []
func _ready() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("3a3f3c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("9aa0a6"); env.ambient_light_energy = .8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.0; we.environment = env; add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, 25, 0); key.light_energy = 1.7; key.shadow_enabled = true; add_child(key)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 200, 0); fill.light_energy = .8; add_child(fill)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 10); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("343936"); g.material_override = gm; add_child(g)
	var reach: Dictionary = Game.FACTIONS.reach; var concord: Dictionary = Game.FACTIONS.concord
	var line := [["vanguard", "visor", reach, false], ["pathfinder", "hood", reach, true], ["warden", "crest", concord, true],
		["vanguard", "mask", reach, false], ["drakeguard", "dragon", Game.FACTIONS.wyrm, true]]
	for i in line.size():
		var m := Trooper.new(); add_child(m); m.position = Vector3((i - 2) * 1.25, 0, 0)
		m.build(line[i][0], line[i][1], line[i][2], line[i][3], "rifle"); models.append(m)
	var cam := Camera3D.new(); cam.fov = 30; add_child(cam); cam.position = Vector3(0, 1.3, 7.9); cam.look_at(Vector3(0, 1.0, 0))
func _process(dt: float) -> void:
	t += dt
	for m in models: (m as Trooper).pose(1.0 / 60.0, {"aim": .45})
	if t > 1.2:
		get_viewport().get_texture().get_image().save_png("user://t_lineup.png"); get_tree().quit()
