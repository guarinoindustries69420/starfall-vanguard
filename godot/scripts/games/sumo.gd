# Starfall Vanguard event: Cargo Sumo. Four heavy cargo tugs on a floating loading platform. Shove the others off the edge
# and stay on yourself; Cross rams forward. The platform starts shrinking after twenty seconds. You win if the rival
# faction's tug goes over before yours does.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends MiniGame

var R := 15.0
var tugs: Array = []            # {node, pos, vel, player, rival, out, cd, fall, skill, name}
var deck: MeshInstance3D
var out_order: Array = []

func title() -> String: return "Cargo Sumo"
func view() -> String: return "orbit"
func help_pad() -> String: return "Left stick drive   Cross ram"
func help_keys() -> String: return "WASD drive   Space ram"

func build() -> void:
	var g: Color = Galaxy.BIOMES[biome].ground
	var planet := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(500, 500); planet.mesh = pm
	planet.material_override = mat(g, 0.0, 1.0, 0.0); planet.position.y = -60; add_child(planet)
	deck = MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = R; cm.bottom_radius = R * .9; cm.height = 1.2; deck.mesh = cm
	deck.material_override = mat(Color("4a525c"), 0.0, .7, .5); deck.position.y = -.6; add_child(deck)
	var rim := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = R - .25; tm.outer_radius = R; rim.mesh = tm
	rim.material_override = mat(Color("ffb347"), 2.0); deck.add_child(rim); rim.position.y = .6
	var spec := [["You", Game.player_faction, true, false, 1.0], [Galaxy.FAC[rival].name.split(" ")[-1] + " hauler", rival, false, true, .9],
		["Dock crew", "neutral", false, false, .7], ["Freight guild", "neutral", false, false, .75]]
	for i in spec.size():
		var e: Array = spec[i]; var col: Color = fac_color(e[1]) if e[1] != "neutral" else Color("c9c2b0").lerp(Color("7a9a6a"), i * .3)
		var n := craft(col, Color("8fe3ff") if e[2] else col.lightened(.4)); n.scale = Vector3(1.4, 1.2, 1.2)
		var a := TAU * i / spec.size() + PI / 4
		tugs.append({"node": n, "pos": Vector3(cos(a), 0, sin(a)) * R * .6, "vel": Vector3.ZERO, "player": e[2], "rival": e[3], "out": false,
			"cd": 0.0, "fall": 0.0, "skill": e[4], "name": e[0], "face": -Vector3(cos(a), 0, sin(a))})
	cam.position = Vector3(0, 30, 24); cam.look_at(Vector3(0, -1, 0))
	_draw_tugs()

func _draw_tugs() -> void:
	for u in tugs:
		var n: Node3D = u.node; n.position = u.pos + Vector3(0, -u.fall * u.fall * 4.0, 0)
		n.look_at(n.position + u.face, Vector3.UP); n.rotate_object_local(Vector3.UP, PI)

func step(dt: float) -> void:
	if t > 20.0: R = max(7.0, 15.0 - (t - 20.0) * .12); deck.scale = Vector3(R / 15.0, 1, R / 15.0)
	var alive := tugs.filter(func(u): return not u.out)
	for u in tugs:
		if u.out: u.fall += dt; continue
		var want := Vector3.ZERO; var ram := false
		if u.player and not autopilot:
			var mv := move_vec(); want = Vector3(mv.x, 0, mv.y); ram = just("roll")
		else:
			var best = null; var bd := 1e9
			for v in alive:
				if v == u: continue
				var d: float = (v.pos as Vector3).distance_to(u.pos) - (6.0 if v.player or v.rival else 0.0)
				if d < bd: bd = d; best = v
			if best:
				var to: Vector3 = best.pos - u.pos
				var push_from: Vector3 = best.pos + best.pos.normalized() * -2.5      # come at them from the centre side
				want = ((push_from if u.pos.length() > best.pos.length() else best.pos) - u.pos).limit_length(1.0) * u.skill
				ram = u.cd <= 0 and to.length() < 6.0 and u.face.dot(to.normalized()) > .9
			if u.pos.length() > R - 3.0: want += -u.pos.normalized() * 1.2                  # stay off the edge
		u.cd = max(0.0, u.cd - dt)
		if want.length() > .1: u.face = u.face.slerp(want.normalized(), min(1.0, dt * 8.0)).normalized()
		u.vel = (u.vel + want.limit_length(1.0) * 22.0 * dt) * pow(.3, dt)
		if ram and u.cd <= 0:
			u.vel += u.face * 16.0; u.cd = 1.3
			if u.player: Game.rumble(.3, .5, .15)
		u.pos += u.vel * dt
	for a in alive:                                     # collisions: momentum trades, rams hit hard
		for b in alive:
			if a == b: continue
			var d: Vector3 = a.pos - b.pos; var dist := d.length()
			if dist < 2.6 and dist > .01:
				var n := d / dist; var rel: float = (b.vel - a.vel).dot(n)
				if rel > 0: a.vel += n * rel * 1.1; b.vel -= n * rel * .1
				a.pos += n * (2.6 - dist) * .5
	for u in alive:
		if (u.pos as Vector3).length() > R:
			u.out = true; out_order.append(u)
			if u.player: Game.rumble(.6, .8, .4)
	_draw_tugs()
	var me: Dictionary = tugs.filter(func(u): return u.player)[0]; var rv: Dictionary = tugs.filter(func(u): return u.rival)[0]
	if me.out or rv.out or t > 120.0:
		var won: bool = rv.out and not me.out or (rv.out and me.out and out_order.find(rv) < out_order.find(me))
		finish(won, "The rival hauler went over first." if won else ("You went over first." if me.out else "Time ran out with both of you still on the deck."))

func score_text() -> String:
	var still := tugs.filter(func(u): return not u.out).map(func(u): return u.name)
	return "On the deck: %s   Platform %d m across" % [", ".join(still), int(R * 2)]
