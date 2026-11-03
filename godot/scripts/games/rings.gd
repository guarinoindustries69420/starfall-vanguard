# Starfall Vanguard event: Ring Run. A time trial through a canyon of beacon rings at full throttle. Every ring you miss
# costs two seconds, every rock you clip costs one. Beat the time the rival faction's pilot set; their ghost flies beside you.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends MiniGame

const SPEED := 38.0; const GAP := 34.0; const N := 24; const RING_R := 2.6
var rings: Array = []           # {pos, node, done}
var rocks: Array = []           # {pos, r}
var ship: Node3D; var ghost: Node3D
var pos := Vector3(0, 8, 0); var vel2 := Vector2.ZERO
var penalty := 0.0; var hits := 0; var misses := 0; var passed := 0
var rival_time := 0.0; var boost := 1.0; var boost_t := 0.0
var rng := RandomNumberGenerator.new()

func title() -> String: return "Ring Run"
func help_pad() -> String: return "Left stick steer   Cross boost"
func help_keys() -> String: return "WASD steer   Space boost"

func build() -> void:
	rng.seed = hash(world_name) + 9
	var g: Color = Galaxy.BIOMES[biome].ground
	ground(900, g)
	var p := Vector2.ZERO
	for i in N:
		p += Vector2(rng.randf_range(-6, 6), rng.randf_range(-3.5, 3.5)); p = p.clamp(Vector2(-10, -4), Vector2(10, 5))
		var rp := Vector3(p.x, 8 + p.y, (i + 1) * GAP)
		var tor := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = RING_R; tm.outer_radius = RING_R + .35; tor.mesh = tm
		tor.material_override = mat(Color("ffd34d"), 3.0); tor.position = rp; tor.rotation.x = PI / 2; add_child(tor)
		rings.append({"pos": rp, "node": tor, "done": false})
		for k in 2:                                  # rocks drifting between rings, never right on the ring line
			var rk := Vector3(rng.randf_range(-14, 14), rng.randf_range(2, 15), (i + 1) * GAP + GAP * .5)
			if Vector2(rk.x - rp.x, rk.y - rp.y).length() < 4.5: rk.x += 7.0 * sign(rk.x - rp.x + .01)
			var r := rng.randf_range(1.0, 2.2); ball(r, Color("6d655c"), rk); rocks.append({"pos": rk, "r": r})
	for s in [-1, 1]:                                # canyon walls
		for i in N + 3:
			var h := rng.randf_range(14, 30); box(Vector3(8, h, GAP), g.darkened(rng.randf_range(.1, .35)), Vector3(s * 24, h / 2, i * GAP))
	ship = craft(fac_color(Game.player_faction), Color("8fe3ff")); ghost = craft(fac_color(rival), fac_color(rival).lightened(.4))
	for m in ghost.find_children("*", "MeshInstance3D", true, false):
		var gm: StandardMaterial3D = (m as MeshInstance3D).material_override.duplicate(); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color.a = .4; m.material_override = gm
	# the rival's time: a clean run plus a little, tighter on harder worlds
	rival_time = (N + 1) * GAP / SPEED + {"low": 2.2, "med": 1.6, "high": 1.1, "fort": .8}.get(res, 1.6)
	_place()

func _place() -> void:
	ship.position = pos; ship.rotation = Vector3(-vel2.y * .04, PI, -vel2.x * .05)
	var gz := t / rival_time * (N + 1) * GAP
	var gi: int = clamp(int(gz / GAP), 0, N - 1)
	var a: Vector3 = rings[max(gi - 1, 0)].pos if gi > 0 else Vector3(0, 8, 0); var b: Vector3 = rings[gi].pos
	var u: float = clamp((gz - a.z) / max(1.0, b.z - a.z), 0.0, 1.0)
	ghost.position = Vector3(lerp(a.x, b.x, u) + 3.0, lerp(a.y, b.y, u) + 1.0, gz); ghost.rotation.y = PI
	cam.position = pos + Vector3(0, 3.2, -9.0); cam.look_at(pos + Vector3(0, 1, 12), Vector3.UP)

func step_idle(_dt: float) -> void: _place()

func step(dt: float) -> void:
	var steer := Vector2.ZERO; var want_boost := false
	if autopilot:
		var nxt = null
		for r in rings:
			if not r.done: nxt = r; break
		if nxt:                                      # aim to arrive on the ring's line, without overshooting on a long frame
			var need := Vector2(nxt.pos.x - pos.x, -(nxt.pos.y - pos.y))
			var frames_left: float = max(1.0, (nxt.pos.z - pos.z) / (SPEED * max(dt, .001)))
			steer = (need / max(16.0 * dt * frames_left * .6, 16.0 * dt)).limit_length(1.0)
	else:
		var mv := move_vec(); steer = Vector2(mv.x, mv.y); want_boost = just("roll")
	if want_boost and boost >= 1.0: boost = 0.0; boost_t = 1.5
	boost = min(1.0, boost + dt / 7.0); boost_t = max(0.0, boost_t - dt)
	vel2 = vel2.lerp(Vector2(steer.x, -steer.y) * 16.0, min(1.0, dt * 6.0))
	pos.x = clamp(pos.x + vel2.x * dt, -18, 18); pos.y = clamp(pos.y + vel2.y * dt, 2, 18)
	var z0 := pos.z; pos.z += SPEED * (1.3 if boost_t > 0 else 1.0) * dt
	for r in rings:
		if r.done or r.pos.z > pos.z or r.pos.z <= z0: continue
		r.done = true
		if Vector2(pos.x - r.pos.x, pos.y - r.pos.y).length() <= RING_R: passed += 1; (r.node as MeshInstance3D).material_override = mat(Color("6dff9c"), 3.0); Game.rumble(.2, 0, .05)
		else: misses += 1; penalty += 2.0; (r.node as MeshInstance3D).material_override = mat(Color("ff5a4a"), 2.0)
	for rk in rocks:
		if rk.get("hit", false): continue
		if (rk.pos as Vector3).distance_to(pos) < rk.r + .8: rk.hit = true; hits += 1; penalty += 1.0; Game.rumble(.3, .5, .2)
	_place()
	if pos.z >= (N + 1) * GAP:
		var total := t + penalty
		finish(total < rival_time, "Your time %.1f s (%d rings, %d missed, %d rocks hit) against the rival's %.1f s." % [total, passed, misses, hits, rival_time])

func score_text() -> String:
	return "Time %.1f s  +%.0f s penalties   Rival %.1f s   Rings %d / %d   Boost %s" % [t, penalty, rival_time, passed, N, "ready" if boost >= 1.0 else "%d%%" % int(boost * 100)]
