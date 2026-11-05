# Starfall Vanguard: the player trooper. Move, aim with the mouse or right stick, fire, reload, dive, crouch, sprint,
# vault and climb over rubble, throw grenades and call in artillery. The exosuit (Game.suit) sets pace, protection,
# the dive and one passive; its numbers come from Game.suit_mod.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Unit

var aim_dir := Vector3(0, 0, 1)
var mag := 32; var ammo := 32; var fire_t := 0.0; var reload_t := 0.0
var suit := ""; var mods: Dictionary = Game.suit_mod("vanguard")   # the exosuit and its numbers (set again by wear)
var calm_t := 0.0                                  # time since the last hit (Trauma Injector)
var plate_t := 0.0; var plate_cd := 0.0            # Reactive Plating: hardened time left, and recharge
var dodge_t := 0.0; var dodge_cd := 0.0; var dodge_dir := Vector3.ZERO
var fired := false; var dead_t := -1.0
var grenades := 4; var barrage_cd := 0.0
var test_input := Vector2.ZERO; var test_fire := false; var test_aim := Vector3.ZERO
var aim_point := Vector3.ZERO

func _ready() -> void:
	_unit_body(2, 1 | 4)
	wear(Game.suit)

# put on an exosuit: its look and its numbers (also used by the tests to try each passive)
func wear(id: String) -> void:
	suit = id if Game.SUITS.has(id) else "vanguard"; mods = Game.suit_mod(suit); grenades = mods.grenades
	plate_t = 0.0; plate_cd = 0.0; calm_t = 0.0; dodge_cd = 0.0
	if model: model.queue_free()
	var su: Dictionary = Game.SUITS[suit]
	model = Trooper.new(); add_child(model)
	model.build(su.kit, su.helm, Game.suit_palette(suit), true, "rifle")

func _input_vec() -> Vector2:
	if Game.test_mode and test_input != Vector2.ZERO: return test_input
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

# where the player is aiming, on the ground plane at chest height
func _aim_point() -> Vector3:
	var base := global_position + Vector3(0, chest(), 0)
	if Game.test_mode and test_aim != Vector3.ZERO: return test_aim
	if Game.using_pad:
		var rs := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if rs.length() > .2: aim_dir = _assist(Vector3(rs.x, 0, rs.y).normalized())
		return base + aim_dir * 12.0
	var vp := get_viewport(); var cam := vp.get_camera_3d()
	if cam == null or Game.test_mode: return base + aim_dir * 10.0
	var m := vp.get_mouse_position(); var o := cam.project_ray_origin(m); var d := cam.project_ray_normal(m)
	if abs(d.y) < 1e-4: return base + aim_dir
	var tt := (base.y - o.y) / d.y; return o + d * tt

# light aim assist for the stick: bend toward an enemy inside a narrow cone
func _assist(dir: Vector3) -> Vector3:
	var best := dir; var best_a := deg_to_rad(9.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp <= 0: continue
		var to: Vector3 = e.global_position - global_position; to.y = 0
		if to.length() > 34.0: continue
		var a := dir.angle_to(to.normalized())
		if a < best_a: best_a = a; best = dir.slerp(to.normalized(), .45)
	return best

# the bolt goes at the chest of an enemy near the aim line, or flat when there is none
func _shot_dir(muzzle: Vector3) -> Vector3:
	var flat := aim_dir
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp <= 0: continue
		var to: Vector3 = e.global_position - global_position; to.y = 0
		var along := to.dot(flat)
		if along < 1.0 or along > 45.0: continue
		if (to - flat * along).length() < 1.1:
			var tgt: Vector3 = e.global_position + Vector3(0, e.chest(), 0)
			return (tgt - muzzle).normalized()
	return flat

func _physics_process(dt: float) -> void:
	if hp <= 0:
		dead_t += dt; velocity = Vector3.ZERO
		model.pose(dt, {"aim": model.rotation.y, "dead": min(1.0, dead_t / .9), "world_move": Vector3.ZERO}); return
	var iv := _input_vec(); var mv := Vector3(iv.x, 0, iv.y)
	aim_point = _aim_point(); var ad := aim_point - global_position; ad.y = 0
	if ad.length() > .2 and (not Game.using_pad or Game.test_mode): aim_dir = ad.normalized()
	var blk := Game.input_blocked()               # just after a menu closes, its button press is not a game command
	if Input.is_action_just_pressed("crouch") and not blk: want_crouch = not want_crouch
	_crouch_step(dt)
	dodge_cd = max(0.0, dodge_cd - dt); barrage_cd = max(0.0, barrage_cd - dt)
	plate_t = max(0.0, plate_t - dt); plate_cd = max(0.0, plate_cd - dt); calm_t += dt
	if mods.regen > 0 and calm_t > 4.0 and hp < 100.0: hp = min(100.0, hp + mods.regen * dt)
	# Cross / Space: vault or climb what is ahead, otherwise dive
	if Input.is_action_just_pressed("roll") and not blk and not climbing() and dodge_t <= 0:
		var dir := mv.normalized() if mv.length() > .1 else aim_dir
		if not try_climb(dir, false) and dodge_cd <= 0 and mv.length() > .1:
			dodge_t = Game.DIVE_TIME; dodge_cd = mods.dive_cd; dodge_dir = mv.normalized(); want_crouch = false
	var steady := Input.is_action_pressed("steady")
	var sprint := Input.is_action_pressed("sprint") and not steady and crouch < .5
	var spd := move_speed(sprint, steady)
	if dodge_t > 0:
		dodge_t -= dt; move_unit(dt, dodge_dir, 11.0)
	else:
		move_unit(dt, mv.limit_length(1.0), spd)
	# weapon
	fire_t -= dt
	if reload_t > 0:
		reload_t -= dt
		if reload_t <= 0: ammo = mag
	elif (Input.is_action_just_pressed("reload") and ammo < mag) or ammo <= 0:
		reload_t = mods.reload; Game.say("reload", 25.0)
	fired = false
	var want := (test_fire if Game.test_mode else false) or (Input.is_action_pressed("fire") and not blk)
	if want and fire_t <= 0 and reload_t <= 0 and ammo > 0 and dodge_t <= 0 and not climbing() and not sprint:
		fire_t = .11; ammo -= 1; fired = true
		var muzzle := global_position + Vector3(0, chest() + .2, 0) + aim_dir * .9 + aim_dir.cross(Vector3.UP) * -.23
		var spread := (randf() - .5) * (.025 if steady else .06)
		mission.fire_bolt(muzzle, _shot_dir(muzzle).rotated(Vector3.UP, spread), 60.0, 20.0, true, Color("ffd27a"))
		Game.rumble(.25, 0.0, .05)
	if Input.is_action_just_pressed("grenade") and not blk and grenades > 0 and not climbing():
		grenades -= 1; mission.throw_grenade(self, aim_point, mods.grenade_r); Game.say("grenade", 20.0)
	if Input.is_action_just_pressed("barrage") and not blk and barrage_cd <= 0 and not climbing():
		barrage_cd = mods.barrage_cd; mission.call_barrage(Vector3(aim_point.x, 0, aim_point.z), mods.barrage_lead); Game.say("barrage")
	var moved := global_position - last_pos; last_pos = global_position
	var st := {"aim": atan2(aim_dir.x, aim_dir.z), "moving": mv.length() > .1 and not climbing(), "speed": spd, "move_yaw": atan2(mv.x, mv.z),
		"dodge": (1.0 - dodge_t / Game.DIVE_TIME) if dodge_t > 0 else 0.0, "reload": (1.0 - reload_t / mods.reload) if reload_t > 0 else 0.0,
		"fired": fired, "world_move": moved, "crouch": crouch}
	st.merge(climb_state(), true)
	model.pose(dt, st)

# ground speed from the suit, sprinting or steadying, and how far down the crouch is
func move_speed(sprint: bool, steady: bool) -> float:
	return 6.0 * mods.speed * (mods.sprint if sprint else 1.0) * (.55 if steady else 1.0) * lerp(1.0, .5, crouch)

# blast is true for explosions (Blast Dampers halve those)
func hurt(d: float, blast := false) -> void:
	if hp <= 0 or dodge_t > 0: return
	var was := hp
	d *= mods.taken * (mods.blast if blast else 1.0)
	if mods.reactive and plate_t <= 0 and plate_cd <= 0 and hp >= 35.0 and hp - d < 35.0: plate_t = 3.0; plate_cd = 20.0; Game.say("plates", 20.0)
	if plate_t > 0: d *= .5
	hp -= d; calm_t = 0.0; Game.rumble(.4, .6, .15)
	if was >= 35.0 and hp < 35.0 and hp > 0: Game.say("low_health", 30.0)
	if hp <= 0: Game.say("mission_lost")
	if hp <= 0: hp = 0; dead_t = 0.0; abort_climb()
