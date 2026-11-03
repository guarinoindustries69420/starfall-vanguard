# Starfall Vanguard event: Skimmer Rally. A point-to-point rally stage across open country, one run from the start gate
# to the finish arch, in hover skimmers against local pilots and the rival faction's ace. Take a bend too fast and you
# slide wide; leave the course and you bog down. Boost has a recharge. Win by finishing in the top two and ahead of the
# rival's ace. Anyone still out on the course after 100 seconds does not finish.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends MiniGame

const HALF_W := 6.0
const LIMIT := 100.0
var curve := Curve3D.new()
var length := 0.0
var racers: Array = []           # {node, off, lat, speed, boost, boost_t, player, rival, name, skill, done_t}
var order_done: Array = []

func title() -> String: return "Skimmer Rally"
func help_pad() -> String: return "R2 throttle   L2 brake   Left stick steer   Cross boost"
func help_keys() -> String: return "W throttle   S brake   A / D steer   Space boost"

func build() -> void:
	var g: Color = Galaxy.BIOMES[biome].ground
	ground(1800, g)
	var r := RandomNumberGenerator.new(); r.seed = hash(world_name)
	# the stage: open country from west to east, sweeping bends and the odd tight one, never crossing itself
	var n := 15; var z := 0.0
	for i in n:
		z = clamp(z + r.randf_range(-60, 60) * (1.8 if r.randf() < .25 else 1.0), -170.0, 170.0)
		curve.add_point(Vector3(-630.0 + i * 90.0, 0, z if i > 0 and i < n - 1 else z * .3))
	for i in curve.point_count:                       # smooth handles so the stage flows
		var p0 := curve.get_point_position(max(i - 1, 0)); var p2 := curve.get_point_position(min(i + 1, n - 1))
		var h := (p2 - p0) * .25; curve.set_point_in(i, -h); curve.set_point_out(i, h)
	curve.bake_interval = .5; length = curve.get_baked_length()
	_track_mesh(g); _scenery(r, g)
	var grid := [["You", Game.player_faction, true, false, 1.0], [Galaxy.FAC[rival].name.split(" ")[-1] + " ace", rival, false, true, .97],
		["Local: Dust Jockey", "neutral", false, false, .9], ["Local: Red Kestrel", "neutral", false, false, .93]]
	for i in grid.size():
		var e: Array = grid[i]
		var col: Color = fac_color(e[1]) if e[1] != "neutral" else Color("c9c2b0").lerp(Color("d67b3a"), i * .3)
		var node := craft(col, Color("8fe3ff") if e[2] else col.lightened(.4))
		racers.append({"node": node, "off": 6.0 - 6.0 * (i / 2), "lat": -2.4 if i % 2 == 0 else 2.4, "speed": 0.0, "boost": 1.0,
			"boost_t": 0.0, "player": e[2], "rival": e[3], "name": e[0], "skill": e[4], "done_t": -1.0, "last_off": 0.0})
	_place_all()

func _track_mesh(g: Color) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int(length / 2.0)
	for i in steps:
		var a := _frame(i * length / steps); var b := _frame((i + 1) * length / steps)
		var v := [a.p - a.side * HALF_W, a.p + a.side * HALF_W, b.p - b.side * HALF_W, b.p + b.side * HALF_W]
		for k in [0, 2, 1, 1, 2, 3]: st.add_vertex(v[k] + Vector3(0, .03, 0))
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat(g.darkened(.45), 0.0, .9, 0.0); add_child(mi)
	var d := 0.0                                      # course marker posts every 12 m
	while d < length:
		var f := _frame(d)
		for s in [-1, 1]: box(Vector3(.3, .8, .3), Color("ffb347") if s < 0 else Color("6fd3ff"), f.p + f.side * s * (HALF_W + .3) + Vector3(0, .4, 0), null, 2.0)
		d += 12.0
	for at in [0.0, length * .25, length * .5, length * .75, length - 1.0]:   # start gate, split arches, finish arch
		var fg := _frame(at); var col := Color("ffe08a") if at == 0.0 or at > length - 2.0 else Color("8fe3ff")
		for s in [-1, 1]: box(Vector3(.8, 6, .8), Color("2a2f38"), fg.p + fg.side * s * (HALF_W + 1.0) + Vector3(0, 3, 0))
		var bar := box(Vector3(HALF_W * 2 + 2.8, .6, .6), col, fg.p + Vector3(0, 6, 0), null, 3.0)
		bar.look_at(bar.position + fg.side, Vector3.UP); bar.rotate_object_local(Vector3.UP, PI / 2)

func _scenery(r: RandomNumberGenerator, g: Color) -> void:
	for i in 320:                                      # lone spires and boulders across open ground, kept off the course
		var p := Vector3(r.randf_range(-700, 700), 0, r.randf_range(-260, 260))
		var near := curve.get_closest_point(p)
		if near.distance_to(p) < HALF_W + 9: continue
		var h := r.randf_range(2, 9) if r.randf() < .8 else r.randf_range(12, 22)
		var rock := box(Vector3(r.randf_range(2, 7), h, r.randf_range(2, 7)), g.darkened(r.randf_range(.1, .4)), p + Vector3(0, h / 2, 0))
		rock.rotation.y = r.randf() * TAU

func _frame(off: float) -> Dictionary:
	off = clamp(off, 0.0, length - 1.0)
	var p := curve.sample_baked(off); var q := curve.sample_baked(off + 1.0)
	var fwd := (q - p).normalized(); var side := fwd.cross(Vector3.UP).normalized()
	return {"p": p, "fwd": fwd, "side": side}

func _curvature(off: float) -> float:
	var a: Vector3 = _frame(off).fwd; var b: Vector3 = _frame(off + 12.0).fwd
	return a.signed_angle_to(b, Vector3.UP) / 12.0

func _place_all() -> void:
	for rc in racers:
		var f := _frame(rc.off)
		var n: Node3D = rc.node
		n.position = f.p + f.side * rc.lat + Vector3(0, .35 + sin(t * 9.0 + rc.off) * .05, 0)
		n.look_at(n.position + f.fwd, Vector3.UP); n.rotate_object_local(Vector3.UP, PI)
		n.rotation.z = -clamp(rc.get("steer", 0.0) * .5, -.4, .4)

func step_idle(_dt: float) -> void: _place_all(); _camera(1.0)

func step(dt: float) -> void:
	for rc in racers:
		if rc.done_t >= 0: rc.speed = move_toward(rc.speed, 0.0, dt * 20.0); rc.off = min(rc.off + rc.speed * dt, length - 1.0); continue
		var throttle := 0.0; var brake := 0.0; var steer := 0.0; var boost := false
		if rc.player and not autopilot:
			throttle = max(Input.get_action_strength("fire"), Input.get_action_strength("move_up"))
			brake = max(Input.get_action_strength("steady"), Input.get_action_strength("move_down"))
			steer = Input.get_axis("move_left", "move_right"); boost = just("roll")
		else:
			var look: float = abs(_curvature(rc.off + rc.speed * .6))
			var target_v: float = clamp(sqrt(22.0 / max(look, .002)), 18.0, 48.0) * rc.skill
			throttle = 1.0 if rc.speed < target_v else 0.0; brake = 1.0 if rc.speed > target_v + 3.0 else 0.0
			var line := -_curvature(rc.off + 10.0) * 160.0   # take the inside of the next bend
			steer = clamp((clamp(line, -3.5, 3.5) - rc.lat) * .5, -1.0, 1.0)
			# boost on a straight, at a steady rate per second rather than a chance per frame
			boost = rc.boost >= 1.0 and look < .006 and randf() < 1.0 - exp(-(1.2 + (2.4 if rc.player else 0.0)) * dt)
		if boost and rc.boost >= 1.0: rc.boost = 0.0; rc.boost_t = 1.4
		rc.boost = min(1.0, rc.boost + dt / 6.0); rc.boost_t = max(0.0, rc.boost_t - dt)
		var top := 46.0 * (1.35 if rc.boost_t > 0 else 1.0)
		var off_track: bool = abs(rc.lat) > HALF_W
		if off_track: top = 16.0
		rc.speed = clamp(rc.speed + throttle * 26.0 * dt - brake * 40.0 * dt - (8.0 if throttle == 0 else 0.0) * dt, 0.0, top)
		rc.steer = steer
		# too fast for the bend and you slide to the outside
		var slide: float = _curvature(rc.off) * rc.speed * rc.speed * .028
		rc.lat += (steer * 9.0 + slide) * dt
		rc.lat = clamp(rc.lat, -HALF_W - 4.0, HALF_W + 4.0)
		rc.off += rc.speed * dt
		if rc.off >= length - 2.0 and rc.done_t < 0:
			rc.done_t = t; order_done.append(rc)
			if rc.player: _player_done()
	# racers side by side push each other apart
	for a in racers:
		for b in racers:
			if a == b: continue
			if abs(a.off - b.off) < 2.6 and abs(a.lat - b.lat) < 1.6:
				var s: float = sign(a.lat - b.lat) if a.lat != b.lat else 1.0
				a.lat += s * 2.5 * dt; a.speed *= pow(.74, dt)
	_place_all(); _camera(dt)
	if t > LIMIT and not done: _player_done()

func _player_done() -> void:
	var me: Dictionary = racers.filter(func(r): return r.player)[0]
	var rv: Dictionary = racers.filter(func(r): return r.rival)[0]
	if me.done_t < 0:
		finish(false, "Did not finish inside %d seconds." % int(LIMIT)); return
	var place := order_done.find(me) + 1
	var ahead: bool = rv.done_t < 0 or me.done_t < rv.done_t
	var won := place <= 2 and ahead
	finish(won, "Finished %s in %.1f s%s." % [["first", "second", "third", "fourth"][place - 1], me.done_t, ", ahead of the rival ace" if ahead else ", behind the rival ace"])

func score_text() -> String:
	var me: Dictionary = racers.filter(func(r): return r.player)[0]
	var ranked := racers.duplicate(); ranked.sort_custom(func(a, b): return a.off > b.off)
	return "Stage %d%%   Position %d / %d   Boost %s   %d km/h" % [int(clamp(me.off / length, 0.0, 1.0) * 100), ranked.find(me) + 1, racers.size(),
		"ready" if me.boost >= 1.0 else "%d%%" % int(me.boost * 100), int(me.speed * 3.6)]

func _camera(dt: float) -> void:
	var me: Dictionary = racers.filter(func(r): return r.player)[0]
	var f := _frame(me.off); var n: Node3D = me.node
	var want: Vector3 = n.position - f.fwd * 10.0 + Vector3(0, 4.5, 0)
	cam.position = cam.position.lerp(want, min(1.0, dt * 6.0)) if t > 0 else want
	cam.look_at(n.position + f.fwd * 8.0 + Vector3(0, 1, 0), Vector3.UP)
