# Starfall Vanguard event: Marksman Gala. A shooting exhibition in the town square. Drone targets pop up across three rows
# for a moment each; gold ones score, far rows score double, and the painted civilian cut-outs cost you two points.
# The rival faction's marksman shoots the same course. Most points in 45 seconds wins.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends MiniGame

const TIME := 45.0
var slots: Array = []           # {pos, node, up, life, civ, row}
var score := 0; var rival_score := 0; var shots := 0; var hits := 0
var cross := Vector2(800, 450); var cool := 0.0; var spawn_t := 0.0
var reticle: Control
var rng := RandomNumberGenerator.new()
var rival_skill := .6

func title() -> String: return "Marksman Gala"
func help_pad() -> String: return "Either stick aim   R2 fire"
func help_keys() -> String: return "Mouse aim   Left button fire"

func build() -> void:
	rng.seed = hash(world_name) + 21
	var g: Color = Galaxy.BIOMES[biome].ground
	ground(200, g)
	for row in 3:
		var z := -10.0 - row * 9.0
		box(Vector3(26 + row * 6, .6 + row * 1.2, 1.2), Color("5b4a3a"), Vector3(0, .3 + row * .6, z + .8))
		for k in 5 + row:
			var x := (k - (4 + row) / 2.0) * (4.4 + row * .6)
			var node := Node3D.new(); node.position = Vector3(x, row * 1.2, z); add_child(node)
			box(Vector3(.12, 1.4, .12), Color("3a3a3a"), Vector3(0, .7, 0), node)
			var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = .7; cm.bottom_radius = .7; cm.height = .12; disc.mesh = cm
			disc.rotation.x = PI / 2; disc.position = Vector3(0, 1.8, 0); node.add_child(disc)
			node.visible = false
			slots.append({"pos": node.position + Vector3(0, 1.8, 0), "node": node, "disc": disc, "up": false, "life": 0.0, "civ": false, "row": row})
	for i in 30:                                     # a crowd along the sides
		var side := -1 if i % 2 == 0 else 1
		box(Vector3(.6, 1.7, .5), Color.from_hsv(rng.randf(), .4, .7), Vector3(side * rng.randf_range(16, 22), .85, rng.randf_range(-30, 4)))
	cam.position = Vector3(0, 3.2, 8); cam.look_at(Vector3(0, 1.8, -16)); cam.fov = 55
	reticle = Control.new(); reticle.size = Vector2(40, 40); hud.add_child(reticle); reticle.draw.connect(_draw_reticle)
	rival_skill = .55 + .1 * rng.randf()

func _draw_reticle() -> void:
	reticle.draw_arc(Vector2(20, 20), 14, 0, TAU, 32, Color(1, .9, .5), 2.0)
	reticle.draw_line(Vector2(20, 2), Vector2(20, 12), Color(1, .9, .5), 2.0); reticle.draw_line(Vector2(20, 28), Vector2(20, 38), Color(1, .9, .5), 2.0)
	reticle.draw_line(Vector2(2, 20), Vector2(12, 20), Color(1, .9, .5), 2.0); reticle.draw_line(Vector2(28, 20), Vector2(38, 20), Color(1, .9, .5), 2.0)

func _pop() -> void:
	var free := slots.filter(func(s): return not s.up)
	if free.is_empty(): return
	var s: Dictionary = free[rng.randi() % free.size()]
	s.up = true; s.life = rng.randf_range(1.2, 2.0) - s.row * .15; s.civ = rng.randf() < .22; s.node.visible = true
	(s.disc as MeshInstance3D).material_override = mat(Color("e8e0d0") if s.civ else Color("ffcf3a"), .0 if s.civ else 1.2)
	if not s.civ and rng.randf() < rival_skill: rival_score += 1 + s.row / 2   # the rival shoots the same course

func step(dt: float) -> void:
	spawn_t -= dt
	if spawn_t <= 0: _pop(); spawn_t = rng.randf_range(.35, .7)
	for s in slots:
		if s.up:
			s.life -= dt
			if s.life <= 0: s.up = false; s.node.visible = false
	var vs := get_viewport().get_visible_rect().size
	var fire := false
	if autopilot:
		var tgt = null
		for s in slots:
			if s.up and not s.civ: tgt = s; break
		if tgt:
			var sp := cam.unproject_position(tgt.pos); cross = cross.move_toward(sp, 1600.0 * dt); fire = cross.distance_to(sp) < 6.0
	elif Game.using_pad:
		var v: Vector2 = move_vec() + aim_vec(); cross = (cross + v.limit_length(1.0) * 900.0 * dt).clamp(Vector2.ZERO, vs); fire = pressed("fire")
	else:
		cross = get_viewport().get_mouse_position(); fire = pressed("fire")
	reticle.position = cross - Vector2(20, 20)
	cool -= dt
	if fire and cool <= 0:
		cool = .28; shots += 1; Game.rumble(.2, .1, .05)
		for s in slots:
			if not s.up: continue
			if cam.unproject_position(s.pos).distance_to(cross) < 34.0 - s.row * 6.0:
				s.up = false; s.node.visible = false
				if s.civ: score -= 2
				else: score += 1 + s.row / 2; hits += 1
				break
	if t >= TIME: finish(score > rival_score, "You scored %d (%d hits from %d shots); the rival marksman %d." % [score, hits, shots, rival_score])

func score_text() -> String: return "Points: you %d   %s %d   Time %d s" % [score, Galaxy.FAC[rival].name, rival_score, int(max(0.0, TIME - t))]
