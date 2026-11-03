# Starfall Vanguard: what every trooper body shares. Gravity on uneven ground, crouching, and getting over obstacles:
# a low pile is vaulted, a chest-high one is climbed with both hands on the ledge, anything taller blocks the way.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends CharacterBody3D
class_name Unit

const GRAV := 19.6
const VAULT_MAX := 1.05          # obstacles up to this height are vaulted
const CLIMB_MAX := 2.1           # up to this height they are climbed; taller ones block
const W_MASK := 1                # world layer: ground, buildings, rubble, debris

var mission: Node3D
var model: Trooper
var hp := 100.0
var crouch := 0.0; var want_crouch := false
var climb_t := -1.0; var climb_dur := 1.0; var climb_kind := ""
var climb_from := Vector3.ZERO; var climb_to := Vector3.ZERO; var climb_h := 0.0; var climb_yaw := 0.0; var climb_ledge := Vector3.ZERO
var push_t := 0.0
var climbs := 0                  # how many vaults and climbs this unit has made (the test reads it)
var shape_node: CollisionShape3D; var capsule: CapsuleShape3D
var last_pos := Vector3.ZERO

func _unit_body(layer: int, mask: int) -> void:
	collision_layer = layer; collision_mask = mask
	shape_node = CollisionShape3D.new(); capsule = CapsuleShape3D.new(); capsule.radius = .4; capsule.height = 1.8
	shape_node.shape = capsule; shape_node.position.y = .9; add_child(shape_node)
	floor_snap_length = .5; floor_max_angle = deg_to_rad(52); safe_margin = .02
	last_pos = global_position

func chest() -> float: return lerp(1.25, .8, crouch)
func climbing() -> bool: return climb_t >= 0.0

func _crouch_step(dt: float) -> void:
	crouch = move_toward(crouch, 1.0 if want_crouch and not climbing() else 0.0, dt * 6.0)
	capsule.height = lerp(1.8, 1.15, crouch); shape_node.position.y = capsule.height / 2.0

# move with gravity; when pushing into something low enough, get over it
func move_unit(dt: float, wish: Vector3, speed: float) -> void:
	if climbing(): _climb_step(dt); return
	var hv := wish * speed
	velocity.x = hv.x; velocity.z = hv.z
	if is_on_floor(): velocity.y = -1.0
	else: velocity.y -= GRAV * dt
	move_and_slide()
	if global_position.y < -10.0: global_position.y = 2.0       # never fall out of the world
	var blocked := false
	if wish.length() > .3 and is_on_wall():
		for c in get_slide_collision_count():
			var nrm := get_slide_collision(c).get_normal()
			if nrm.y < .5 and Vector2(nrm.x, nrm.z).dot(Vector2(wish.x, wish.z).normalized()) < -.4: blocked = true
	push_t = push_t + dt if blocked else 0.0
	if push_t > .15: try_climb(wish.normalized(), false)

func _clear_at(p: Vector3, tall: float) -> bool:
	var prm := PhysicsShapeQueryParameters3D.new(); var cap := CapsuleShape3D.new(); cap.radius = .3; cap.height = tall
	prm.shape = cap; prm.transform = Transform3D(Basis(), p + Vector3(0, tall / 2.0 + .06, 0)); prm.collision_mask = W_MASK
	prm.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(prm, 1).is_empty()

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b); q.collision_mask = W_MASK; q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

# look at what is in front: returns {} when there is nothing to get over, or {kind, to, h, ledge}
func probe_obstacle(d: Vector3) -> Dictionary:
	d.y = 0; if d.length() < .1: return {}
	d = d.normalized(); var p := global_position
	var face := {}
	for kh in [.35, .7, 1.1]:
		var hit := _ray(p + Vector3(0, kh, 0), p + Vector3(0, kh, 0) + d * 1.1)
		if not hit.is_empty() and hit.normal.y < .6: face = hit; break
	if face.is_empty(): return {}
	var fp: Vector3 = face.position
	var depth := .2
	while depth <= 1.7:
		depth += .15
		var x: Vector3 = fp + d * depth
		var top_hit := _ray(Vector3(x.x, p.y + CLIMB_MAX + .6, x.z), Vector3(x.x, p.y - .5, x.z))
		if top_hit.is_empty(): continue
		var top: float = top_hit.position.y - p.y
		if top > CLIMB_MAX: return {}
		if top < .3: continue
		var stand := Vector3(x.x, top_hit.position.y, x.z)
		var kind := "vault" if top <= VAULT_MAX else "climb"
		var dest := stand
		if kind == "vault":                             # clear the obstacle completely when the far side is open
			for reach in [1.0, 1.5, 2.0, 2.5]:
				var far: Vector3 = stand + d * reach
				var gh := _ray(far + Vector3(0, 1.5, 0), far - Vector3(0, CLIMB_MAX + 1.0, 0))
				if not gh.is_empty() and stand.y - gh.position.y > .25 and _clear_at(gh.position, 1.6): dest = gh.position; break
		if not _clear_at(dest, 1.6 if kind == "climb" else 1.0): continue
		return {"kind": kind, "to": dest, "h": top, "ledge": Vector3(fp.x, top_hit.position.y, fp.z)}
	return {}

func try_climb(d: Vector3, forced: bool) -> bool:
	if climbing() or (not is_on_floor() and not forced): return false
	var info := probe_obstacle(d)
	if info.is_empty(): return false
	climb_kind = info.kind; climb_to = info.to; climb_h = info.h; climb_ledge = info.ledge
	climb_from = global_position; climb_yaw = atan2(d.x, d.z); climb_t = 0.0; push_t = 0.0; climbs += 1
	if mission and self == mission.player: Game.say("climb", 30.0)
	climb_dur = .55 if climb_kind == "vault" else lerp(.8, 1.15, (climb_h - VAULT_MAX) / (CLIMB_MAX - VAULT_MAX))
	shape_node.disabled = true; velocity = Vector3.ZERO; want_crouch = false
	return true

func _climb_step(dt: float) -> void:
	climb_t = min(1.0, climb_t + dt / climb_dur); var u := climb_t
	var p: Vector3
	if climb_kind == "vault":
		var top := climb_from.y + climb_h + .08
		p = climb_from.lerp(climb_to, smoothstep(0.0, 1.0, u))
		var base: float = lerp(climb_from.y, climb_to.y, u)
		p.y = base + max(0.0, top - base) * sin(PI * min(1.0, u * 1.15))
	else:
		var edge := climb_ledge - (climb_to - climb_from).normalized() * .38; edge.y = climb_from.y
		if u < .55:                                      # hands on the ledge, pull up
			var a := smoothstep(0.0, 1.0, u / .55)
			p = climb_from.lerp(edge, min(1.0, u / .2)); p.y = climb_from.y + (climb_to.y - climb_from.y + .05) * a
		else:                                            # knee over, stand up on top
			var b := smoothstep(0.0, 1.0, (u - .55) / .45)
			p = Vector3(edge.x, climb_to.y + .05 * (1.0 - b), edge.z).lerp(Vector3(climb_to.x, climb_to.y, climb_to.z), b)
			p.y = climb_to.y + .05 * (1.0 - b)
	global_position = p
	if u >= 1.0:
		climb_t = -1.0; global_position = climb_to + Vector3(0, .02, 0); shape_node.disabled = false

# what the rig needs to animate getting over things
func climb_state() -> Dictionary:
	if not climbing(): return {}
	return {"climb_kind": climb_kind, "climb_u": climb_t, "climb_h": climb_h, "climb_ledge": climb_ledge, "aim": climb_yaw}
