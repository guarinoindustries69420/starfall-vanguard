# Starfall Vanguard event: Gravball. Two against two in a walled low-gravity arena: you and a local player against the
# rival faction's pair. Drive the pod into the ball to push it, or pulse it hard with Cross. Most goals in 90 seconds;
# a draw goes to a golden goal.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends MiniGame

const AW := 30.0; const AH := 17.0; const GOAL := 5.5; const TIME := 90.0
var pods: Array = []            # {node, pos, vel, team, player, cd, skill, home}
var bpos := Vector3.ZERO; var bvel := Vector3.ZERO; var bnode: MeshInstance3D
var goals := [0, 0]             # [yours, theirs]
var golden := false
var pause_t := 0.0

func title() -> String: return "Gravball"
func view() -> String: return "overhead"
func help_pad() -> String: return "Left stick drive   Cross pulse the ball"
func help_keys() -> String: return "WASD drive   Space pulse the ball"

func build() -> void:
	var g: Color = Galaxy.BIOMES[biome].ground
	ground(300, g.darkened(.2))
	box(Vector3(AW * 2, .1, AH * 2), Color("1d2a33"), Vector3(0, .05, 0))
	box(Vector3(.15, .12, AH * 2), Color("7fd4ff"), Vector3(0, .12, 0), null, 1.5)
	for s in [-1, 1]:
		box(Vector3(AW * 2 + 2, 1.6, 1), Color("3b4652"), Vector3(0, .8, s * (AH + .5)))
		for side in [-1, 1]: box(Vector3(1, 1.6, AH - GOAL), Color("3b4652"), Vector3(s * (AW + .5), .8, side * (GOAL + (AH - GOAL) / 2)))
		box(Vector3(.4, 3, GOAL * 2), fac_color(Game.player_faction) if s > 0 else fac_color(rival), Vector3(s * (AW + 2), 1.5, 0), null, 1.2)
	bnode = ball(.9, Color("f2f2f2"), Vector3(0, .9, 0), null, .6)
	var spec := [[0, true, Vector3(-12, 0, 0)], [0, false, Vector3(-20, 0, 7)], [1, false, Vector3(12, 0, 0)], [1, false, Vector3(20, 0, -7)]]
	for e in spec:
		var col: Color = fac_color(Game.player_faction) if e[0] == 0 else fac_color(rival)
		if e[0] == 0 and not e[1]: col = Color("c9c2b0")
		var node := craft(col, Color("8fe3ff") if e[1] else col.lightened(.4)); node.scale = Vector3.ONE * 1.1
		pods.append({"node": node, "pos": e[2], "vel": Vector3.ZERO, "team": e[0], "player": e[1], "cd": 0.0, "skill": .85 if e[0] == 1 else .8, "home": e[2]})
	cam.position = Vector3(0, 40, 30); cam.look_at(Vector3(0, 0, 2))
	_draw_pods()

func _draw_pods() -> void:
	for p in pods:
		var n: Node3D = p.node; n.position = p.pos
		if p.vel.length() > .5: n.look_at(p.pos + p.vel, Vector3.UP); n.rotate_object_local(Vector3.UP, PI)
	bnode.position = bpos + Vector3(0, .9, 0)

func step(dt: float) -> void:
	if pause_t > 0:
		pause_t -= dt
		if pause_t <= 0: _kickoff()
		return
	for p in pods:
		var want := Vector3.ZERO; var pulse := false
		if p.player and not autopilot:
			var mv := move_vec(); want = Vector3(mv.x, 0, mv.y); pulse = just("roll")
		else:
			var attack_goal := Vector3(AW + 2, 0, 0) if p.team == 0 else Vector3(-AW - 2, 0, 0)
			var behind := bpos - (attack_goal - bpos).normalized() * 1.6         # get behind the ball, then drive through it
			var defend: bool = p.home.length() > 15 and bpos.x * (1 if p.team == 0 else -1) > 6
			var target: Vector3 = (p.home + Vector3(bpos.x * .3, 0, bpos.z * .5)) if defend else behind
			want = (target - p.pos).limit_length(1.0) * p.skill
			if (p.pos - behind).length() < 1.8: want = (attack_goal - p.pos).normalized() * p.skill
			pulse = p.cd <= 0 and p.pos.distance_to(bpos) < 3.0 and (attack_goal - p.pos).normalized().dot((bpos - p.pos).normalized()) > .7
		p.cd = max(0.0, p.cd - dt)
		p.vel = (p.vel + want * 40.0 * dt) * pow(.15, dt)
		p.pos += p.vel * dt
		p.pos.x = clamp(p.pos.x, -AW + 1, AW - 1); p.pos.z = clamp(p.pos.z, -AH + 1, AH - 1)
		var to_b: Vector3 = bpos - p.pos; var d := to_b.length()
		if d < 2.1:                                      # pods shove the ball
			bvel += to_b.normalized() * max(2.0, p.vel.dot(to_b.normalized()) * 1.3) ; bpos = p.pos + to_b.normalized() * 2.1
		if pulse and p.cd <= 0 and d < 4.0:
			bvel += to_b.normalized() * 22.0; p.cd = 1.2
			if p.player: Game.rumble(.3, .4, .12)
	for a in pods:                                   # pods bounce off each other
		for b in pods:
			if a == b: continue
			var d: Vector3 = a.pos - b.pos
			if d.length() < 2.2 and d.length() > .01: a.pos += d.normalized() * (2.2 - d.length()) * .5; a.vel += d.normalized() * 3.0
	bvel *= pow(.55, dt); bpos += bvel * dt
	if abs(bpos.z) > AH - .9: bvel.z = -bvel.z * .8; bpos.z = sign(bpos.z) * (AH - .9)
	if abs(bpos.x) > AW - .9:
		if abs(bpos.z) < GOAL: _goal(0 if bpos.x > 0 else 1); return
		bvel.x = -bvel.x * .8; bpos.x = sign(bpos.x) * (AW - .9)
	_draw_pods()
	if t >= TIME and not golden:
		if goals[0] != goals[1]: _end()
		else: golden = true; lbl_big.text = "GOLDEN GOAL"
	if golden and t >= TIME + 60.0: _end()

func _goal(team: int) -> void:
	goals[team] += 1; lbl_big.text = "GOAL" if team == 0 else "%s SCORE" % Galaxy.FAC[rival].name.split(" ")[-1].to_upper()
	Game.rumble(.4, .4 if team == 0 else .1, .3)
	if golden or goals[team] >= 5: _draw_pods(); _end(); return
	pause_t = 1.5; bvel = Vector3.ZERO

func _kickoff() -> void:
	lbl_big.text = ""; bpos = Vector3.ZERO; bvel = Vector3.ZERO
	for p in pods: p.pos = p.home; p.vel = Vector3.ZERO

func _end() -> void: finish(goals[0] > goals[1], "Gravball ended %d to %d." % [goals[0], goals[1]])

func score_text() -> String:
	return "You %d : %d %s   %s" % [goals[0], goals[1], Galaxy.FAC[rival].name, "Golden goal" if golden else "%d s" % int(max(0.0, TIME - t))]
