# Starfall Vanguard event: Asteroid Rush. Sixty seconds in a drifting ore field above the world. Cut rocks apart with the
# mining beam and scoop up the ore before the rival faction's miner does. Rocks bump you off course. Most ore wins.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends MiniGame

const W := 44.0; const H := 26.0; const TIME := 60.0
var rocks: Array = []           # {node, pos, vel, r, hp}
var ore: Array = []             # {node, pos}
var ships: Array = []           # {node, pos, vel, aim, ore, player, rival, beam, stun}
var rng := RandomNumberGenerator.new()

func title() -> String: return "Asteroid Rush"
func view() -> String: return "orbit"
func help_pad() -> String: return "Left stick fly   Right stick aim   R2 mining beam"
func help_keys() -> String: return "WASD fly   Mouse aim   Left button mining beam"

func build() -> void:
	rng.seed = hash(world_name) + 3
	var g: Color = Galaxy.BIOMES[biome].ground
	var planet := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); planet.mesh = pm
	planet.material_override = mat(g.darkened(.3), 0.0, 1.0, 0.0); planet.position.y = -40; add_child(planet)
	for i in 26: _rock(Vector3(rng.randf_range(-W, W), 0, rng.randf_range(-H, H)), rng.randf_range(1.0, 2.6))
	var spec := [[Game.player_faction, true, false], [rival, false, true], ["neutral", false, false]]
	for i in spec.size():
		var f: String = spec[i][0]; var col: Color = fac_color(f) if f != "neutral" else Color("c9c2b0")
		var node := craft(col, Color("8fe3ff") if spec[i][1] else col.lightened(.4)); node.scale = Vector3.ONE * .8
		var beam := box(Vector3(.12, .12, 1), Color("9ff6ff") if spec[i][1] else col.lightened(.5), Vector3.ZERO, null, 6.0); beam.visible = false
		ships.append({"node": node, "pos": Vector3(-30 + i * 30, 0, H - 4), "vel": Vector3.ZERO, "aim": Vector3(0, 0, -1), "ore": 0,
			"player": spec[i][1], "rival": spec[i][2], "beam": beam, "stun": 0.0, "skill": [1.0, .9, .75][i]})
	cam.position = Vector3(0, 62, 26); cam.look_at(Vector3(0, 0, 2))

func _rock(p: Vector3, r: float) -> void:
	var n := ball(r, Color("6d655c").lerp(Color("8a6a4a"), rng.randf()), p); n.scale = Vector3(1, .75, 1.1)
	var vein := ball(r * .35, Color("ffcf5a"), Vector3(r * .6, r * .2, 0), n, 3.0)
	rocks.append({"node": n, "pos": p, "vel": Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-1.5, 1.5)), "r": r, "hp": r * 2.2})

func _ore(p: Vector3) -> void:
	var n := ball(.35, Color("ffd34d"), p, null, 4.0); ore.append({"node": n, "pos": p, "vel": Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))})

func _wrap(p: Vector3) -> Vector3: return Vector3(wrapf(p.x, -W - 3, W + 3), 0, wrapf(p.z, -H - 3, H + 3))

func step(dt: float) -> void:
	for rk in rocks: rk.pos = _wrap(rk.pos + rk.vel * dt); rk.node.position = rk.pos; rk.node.rotation.y += dt * .3
	for o in ore: o.vel *= .97; o.pos = _wrap(o.pos + o.vel * dt); o.node.position = o.pos + Vector3(0, sin(t * 4.0) * .15, 0)
	for s in ships:
		var thrust := Vector3.ZERO; var firing := false
		if s.player and not autopilot:
			var mv := move_vec(); thrust = Vector3(mv.x, 0, mv.y)
			if Game.using_pad:
				var av := aim_vec()
				if av.length() > .25: s.aim = Vector3(av.x, 0, av.y).normalized()
			else:
				var vp := get_viewport(); var m := vp.get_mouse_position()
				var o := cam.project_ray_origin(m); var d := cam.project_ray_normal(m)
				if abs(d.y) > 1e-3:
					var hit := o + d * (-o.y / d.y); var to: Vector3 = hit - s.pos; to.y = 0
					if to.length() > .5: s.aim = to.normalized()
			firing = pressed("fire")
		else:
			var tgt := _target(s)
			if tgt != Vector3.INF:
				var to: Vector3 = tgt - s.pos; to.y = 0
				var is_ore := ore.any(func(o): return o.pos.is_equal_approx(tgt))
				thrust = to.normalized() * (1.0 if to.length() > (1.0 if is_ore else 6.0) else 0.0) * s.skill
				s.aim = s.aim.slerp(to.normalized(), min(1.0, dt * 6.0 * s.skill))
				firing = not is_ore and to.length() < 9.0
		if s.stun > 0: s.stun -= dt; thrust = Vector3.ZERO; firing = false
		s.vel = (s.vel + thrust * 30.0 * dt) * pow(.25, dt)
		s.pos = _wrap(s.pos + s.vel * dt)
		var n: Node3D = s.node; n.position = s.pos; n.look_at(s.pos + s.aim, Vector3.UP); n.rotate_object_local(Vector3.UP, PI)
		s.beam.visible = firing
		if firing: _beam(s, dt)
		for rk in rocks:                                 # bump into rocks
			var d: Vector3 = s.pos - rk.pos
			if d.length() < rk.r + .9:
				s.vel = d.normalized() * 9.0; s.stun = .4; s.pos = rk.pos + d.normalized() * (rk.r + .95)
		for o in ore.duplicate():                        # scoop up ore
			if (o.pos as Vector3).distance_to(s.pos) < 1.6:
				s.ore += 1; o.node.queue_free(); ore.erase(o)
				if s.player: Game.rumble(.2, 0, .05)
	if rocks.size() < 14: _rock(Vector3(-W - 2, 0, rng.randf_range(-H, H)), rng.randf_range(1.2, 2.6))
	if t >= TIME: _end()

func _beam(s: Dictionary, dt: float) -> void:
	var reach := 9.0; var best = null; var bd := reach
	for rk in rocks:
		var to: Vector3 = rk.pos - s.pos
		var along := to.dot(s.aim)
		if along > 0 and along < bd + rk.r and (to - s.aim * along).length() < rk.r: bd = max(0.0, along - rk.r * .6); best = rk
	var b: MeshInstance3D = s.beam
	b.scale = Vector3(1, 1, bd); b.position = s.pos + s.aim * (bd / 2 + .8); b.look_at(s.pos + s.aim * 20, Vector3.UP)
	if best:
		best.hp -= dt * 2.4
		if best.hp <= 0:
			for k in int(best.r * 2.2) + 1: _ore(best.pos + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
			best.node.queue_free(); rocks.erase(best)

func _target(s: Dictionary) -> Vector3:
	var best := Vector3.INF; var bd := 1e9
	for o in ore:
		var d: float = (o.pos as Vector3).distance_to(s.pos) * .6
		if d < bd: bd = d; best = o.pos
	for rk in rocks:
		var d: float = (rk.pos as Vector3).distance_to(s.pos)
		if d < bd: bd = d; best = rk.pos
	return best

func _end() -> void:
	var me: Dictionary = ships.filter(func(s): return s.player)[0]; var rv: Dictionary = ships.filter(func(s): return s.rival)[0]
	finish(me.ore > rv.ore, "You hauled %d ore, the rival miner %d." % [me.ore, rv.ore])

func score_text() -> String:
	var me: Dictionary = ships.filter(func(s): return s.player)[0]; var rv: Dictionary = ships.filter(func(s): return s.rival)[0]
	return "Ore: you %d   %s %d   Time %d s" % [me.ore, Galaxy.FAC[rival].name, rv.ore, int(max(0.0, TIME - t))]
