# Starfall Vanguard: an enemy trooper. Patrols, spots the player with line of sight, closes to firing range and shoots.
# Climbs or vaults rubble in its way, and ducks behind low cover between shots.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Unit

var state := "patrol"; var home := Vector3.ZERO; var wp := Vector3.ZERO; var wait := 0.0
var fire_t := 1.0; var dead_t := -1.0; var aim_yaw := 0.0
var stuck_t := 0.0

func _ready() -> void:
	hp = 60.0
	add_to_group("enemies")
	_unit_body(4, 1 | 2 | 4)
	model = Trooper.new(); add_child(model)
	model.build("vanguard", "visor", Game.FACTIONS[Game.enemy_faction], false, "rifle")
	home = global_position; wp = home; aim_yaw = randf() * TAU

func _sees(p: Vector3, target_h: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.45, 0), p + Vector3(0, target_h, 0)); q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# a low wall of rubble between this trooper and the player, close enough to duck behind
func _low_cover_toward(to_p: Vector3) -> bool:
	var d := to_p.normalized(); var o := global_position + Vector3(0, .55, 0)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 2.2); q.collision_mask = 1; q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(dt: float) -> void:
	if hp <= 0:
		dead_t += dt; velocity = Vector3.ZERO
		model.pose(dt, {"aim": aim_yaw, "dead": min(1.0, dead_t / .9)})
		if dead_t > 30.0: queue_free()
		return
	var pl: Unit = mission.player
	var to_p := pl.global_position - global_position; to_p.y = 0; var dist := to_p.length()
	if state == "patrol" and dist < 32.0 and pl.hp > 0 and _sees(pl.global_position, pl.chest()): state = "hunt"
	var mv := Vector3.ZERO; want_crouch = false
	if state == "hunt" and pl.hp > 0:
		aim_yaw = atan2(to_p.x, to_p.z)
		var los := _sees(pl.global_position, pl.chest())
		var cover := _low_cover_toward(to_p)
		if (dist > 14.0 or not los) and not (cover and los): mv = to_p.normalized()
		elif dist < 8.0: mv = -to_p.normalized()
		fire_t -= dt
		if cover and mv == Vector3.ZERO: want_crouch = fire_t > .35          # stay down, pop up to shoot
		if fire_t <= 0 and los and dist < 30.0 and crouch < .3 and not climbing():
			fire_t = randf_range(1.0, 1.6)
			var muzzle := global_position + Vector3(0, chest() + .2, 0) + to_p.normalized() * .9
			var tgt := pl.global_position + Vector3(0, pl.chest(), 0)
			var dir := (tgt - muzzle).normalized().rotated(Vector3.UP, randf_range(-.05, .05))
			mission.fire_bolt(muzzle, dir, 38.0, 8.0, false, Color("8fd0ff"))
	else:
		wait -= dt
		if wait <= 0 and global_position.distance_to(wp) < 1.0:
			wp = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)); wait = randf_range(1, 3)
		var d := wp - global_position; d.y = 0
		if d.length() > 1.0: mv = d.normalized() * .5; aim_yaw = atan2(d.x, d.z)
	_crouch_step(dt)
	var before := global_position
	move_unit(dt, mv, 4.5 * lerp(1.0, .5, crouch))
	# wandering into a wall it cannot get over: pick another patrol point
	if mv.length() > .1 and not climbing() and (global_position - before).length() < .3 * 4.5 * dt * mv.length():
		stuck_t += dt
		if stuck_t > 1.0: stuck_t = 0.0; wp = global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	else: stuck_t = 0.0
	var moved := global_position - last_pos; last_pos = global_position
	var st := {"aim": aim_yaw, "moving": mv.length() > .1 and not climbing(), "speed": 4.5 * mv.length(), "move_yaw": atan2(mv.x, mv.z),
		"world_move": moved, "crouch": crouch, "fired": false}
	st.merge(climb_state(), true)
	model.pose(dt, st)

func hurt(d: float) -> void:
	if hp <= 0: return
	hp -= d; state = "hunt"
	if hp <= 0:
		hp = 0; dead_t = 0.0; collision_layer = 0; mission.kills += 1; abort_climb()
