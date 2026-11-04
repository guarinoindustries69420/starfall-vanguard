# Starfall Vanguard: the trooper. Builds the jointed rig from the Blender kit, dresses it in PBR materials and animates it:
# walk with knee bend, lower body turning toward movement, two-bone arm IK onto the weapon grips, recoil, reload, roll, death,
# and a verlet cloth cape. A port of the web version's rig, now with real lighting and materials.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D
class_name Trooper

const HOLD := {
	"rifle": {"pos": Vector3(.23, 1.53, .25), "tw": .7, "rg": Vector3(0, -.075, -.03), "lg": Vector3(0, -.065, .25), "hd": -.62, "rp": Vector3(.7, -1, -.35), "lp": Vector3(-.25, -1, .1)},
	"pistol": {"pos": Vector3(.05, 1.45, .45), "tw": .15, "rg": Vector3(0, -.06, -.015), "lg": Vector3(-.035, -.075, -.005), "hd": -.12, "rp": Vector3(.5, -1, -.3), "lp": Vector3(-.5, -1, -.2)},
	"heavy": {"pos": Vector3(.2, 1.3, .2), "tw": .6, "rg": Vector3(0, -.08, -.03), "lg": Vector3(0, .09, .15), "hd": -.5, "rp": Vector3(.6, -1, -.4), "lp": Vector3(-.3, -1, .2)},
	"tube": {"pos": Vector3(.24, 1.7, .12), "tw": .45, "rg": Vector3(0, -.07, -.03), "lg": Vector3(0, -.06, .25), "hd": -.38, "rp": Vector3(.4, -1, -.2), "lp": Vector3(-.3, -1, .1)},
}
const ARMOR_CLASS := {"vanguard": "M", "pathfinder": "L", "warden": "M", "ashwalker": "L", "bulwark": "H", "sentinel": "H", "drakeguard": "D", "drakeguard_hd": "D"}

var tilt: Node3D; var body: Node3D; var upper: Node3D; var lower: Node3D
var leg_l: Node3D; var leg_r: Node3D; var arm_l: Node3D; var arm_r: Node3D
var head: Node3D; var gun: Node3D; var cape: Node3D; var cape_mesh: MeshInstance3D
var mats := {}
var hd_src: Node3D = null          # the skinned model (blender/skin_model.py), when this trooper wears one
var hd_skel: Skeleton3D = null     # its skeleton, driven from the joint nodes every pose
var hd_bones: Array = []           # per bone: [index, joint node, parent index, rest correction]
var hold: Dictionary; var gun0 := Vector3.ZERO
var ph := 0.0; var recoil := 0.0; var t := 0.0
var cloth: Array = []; var cloth_prev: Array = []

static var _noise_n: NoiseTexture2D
static var _noise_r: NoiseTexture2D

func _detail_textures() -> void:
	if _noise_n: return
	var fn := FastNoiseLite.new(); fn.frequency = 0.04; fn.fractal_octaves = 4
	_noise_n = NoiseTexture2D.new(); _noise_n.noise = fn; _noise_n.as_normal_map = true; _noise_n.bump_strength = 2.0; _noise_n.seamless = true; _noise_n.width = 256; _noise_n.height = 256
	var fr := FastNoiseLite.new(); fr.frequency = 0.02; fr.fractal_octaves = 3
	_noise_r = NoiseTexture2D.new(); _noise_r.noise = fr; _noise_r.seamless = true; _noise_r.width = 256; _noise_r.height = 256

func _mat(col: Color, rough: float, metal: float, kind := "plate") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col; m.roughness = rough; m.metallic = metal; m.vertex_color_use_as_albedo = true
	m.uv1_triplanar = true; m.uv1_scale = Vector3(6, 6, 6)
	if kind != "visor" and kind != "glow":
		m.roughness_texture = _noise_r; m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.normal_enabled = true; m.normal_texture = _noise_n; m.normal_scale = 0.08 if kind == "plate" else 0.25
		if kind == "cloth": m.uv1_scale = Vector3(40, 40, 40)
	return m

func build(armor: String, helm: String, pal: Dictionary, with_cape: bool, weapon: String) -> void:
	_detail_textures()
	var cls: String = ARMOR_CLASS.get(armor, "M")
	mats = {
		"base": _mat(pal.base, .55, .15), "trim": _mat(pal.trim, .62, .12), "acc": _mat(pal.acc, .5, .2),
		"under": _mat(Color("3b3f47"), .92, 0.0, "cloth"), "dark": _mat(Color("24262c"), .65, .1, "cloth"),
		"metal": _mat(Color("9aa0aa"), .3, .9), "gold": _mat(Color("d8a640"), .34, .6),
		"visor": _mat(Color("0a1220"), .06, .6, "visor"), "cape": _mat(pal.trim, .95, 0.0, "cloth"),
		"glow": _mat(pal.acc, .5, 0.0, "glow"),
		"leather": _mat(Color("5a3a26"), .72, 0.0, "cloth"), "cloth": _mat(Color("6a1a22"), .95, 0.0, "cloth"),
		"eye": _mat(Color("ff3a2a"), .4, 0.0, "glow"),
	}
	mats.eye.emission_enabled = true; mats.eye.emission = Color("ff3a2a"); mats.eye.emission_energy_multiplier = 3.5
	mats.visor.emission_enabled = true; mats.visor.emission = pal.acc * .12
	mats.glow.emission_enabled = true; mats.glow.emission = pal.acc; mats.glow.emission_energy_multiplier = 3.0
	mats.cape.cull_mode = BaseMaterial3D.CULL_DISABLED; mats.cape.vertex_color_use_as_albedo = false
	if armor.begins_with("drakeguard"): mats.cape.albedo_color = Color("5a1a22")   # a maroon cape to match the tabard
	tilt = _node(self, Vector3.ZERO); body = _node(tilt, Vector3.ZERO); upper = _node(body, Vector3.ZERO)
	lower = _node(tilt, Vector3.ZERO)
	hd_src = Game.hd_kit(armor) if armor.ends_with("_hd") else null
	if hd_src and not _hd_valid(hd_src):
		push_warning("%s.glb: skeleton does not match the trooper rig; wearing the built kit" % armor); hd_src = null
	if hd_src:                                 # a skinned model replaces the whole built kit; the joints drive its bones
		var pelvis_h := _node(lower, Vector3(0, .98, 0))
		leg_l = _leg(-1, cls); leg_r = _leg(1, cls)
		var torso_h := _node(upper, Vector3(0, 1.05, 0))
		arm_l = _arm(-1, cls); arm_r = _arm(1, cls)
		head = _node(upper, Vector3(0, 1.82, .02))
		_hd_bind({"pelvis": pelvis_h, "torso": torso_h, "head": head, "thigh_l": leg_l, "thigh_r": leg_r,
			"shin_l": leg_l.get_meta("knee"), "shin_r": leg_r.get_meta("knee"), "boot_l": leg_l.get_meta("boot"),
			"boot_r": leg_r.get_meta("boot"), "upperarm_l": arm_l, "upperarm_r": arm_r, "forearm_l": arm_l.get_meta("fore"),
			"forearm_r": arm_r.get_meta("fore"), "hand_l": arm_l.get_meta("hand"), "hand_r": arm_r.get_meta("hand")})
		_gun(weapon, with_cape); return
	armor = armor.trim_suffix("_hd")         # no fitted model on disk: wear the built kit of the same armor
	cls = ARMOR_CLASS.get(armor, "M")
	var pelvis := _node(lower, Vector3(0, .98, 0)); _part("pelvis", pelvis)
	if armor == "drakeguard": _part("pelvis__tabard_D", pelvis)
	leg_l = _leg(-1, cls); leg_r = _leg(1, cls)
	var torso := _node(upper, Vector3(0, 1.05, 0))
	_part("torso", torso)
	_part("torso__chest_" + cls, torso); _part("torso__belt", torso); _part("torso__pauld_" + cls, torso)
	_part("torso__pack_D" if cls == "D" else "torso__pack", torso)
	if cls == "D": _part("torso__belt_D", torso)
	if armor == "warden": _part("torso__tabard", torso)
	arm_l = _arm(-1, cls); arm_r = _arm(1, cls)
	head = _node(upper, Vector3(0, 1.82, .02)); _part("head__neck", head)
	var hk := {"hood": "head__hood", "mask": "head__mask", "dome": "head__dome", "dragon": "head__dragon"}
	_part(hk.get(helm, "head__visor"), head)
	if helm == "crest": _part("head__crest", head)
	if helm == "antenna": _part("head__antenna", head)
	_gun(weapon, with_cape)

func _gun(weapon: String, with_cape: bool) -> void:
	gun = _node(body, Vector3.ZERO)
	var gk := "rifle"
	if weapon in ["pistol", "handcannon", "mpistol", "spark", "ember"]: gk = "pistol"
	elif weapon in ["hmg", "autocannon", "flamer", "beam"]: gk = "heavy"
	elif weapon in ["launcher", "rr"]: gk = "tube"
	_part("gun__" + gk, gun)
	hold = HOLD[gk]; gun.position = hold.pos; gun0 = hold.pos
	upper.rotation.y = hold.tw; head.rotation.y = hold.hd; head.rotation.x = .12 if gk == "rifle" else .05
	if with_cape: _build_cape()
	_arms(0.0, 0.0)

# ---- the skinned model: each bone follows its joint node ----
# the bones blender/skin_model.py writes, each with its parent
const HD_PARENT := {"pelvis": "", "torso": "pelvis", "head": "torso", "thigh_l": "pelvis", "thigh_r": "pelvis",
	"shin_l": "thigh_l", "shin_r": "thigh_r", "boot_l": "shin_l", "boot_r": "shin_r", "upperarm_l": "torso",
	"upperarm_r": "torso", "forearm_l": "upperarm_l", "forearm_r": "upperarm_r", "hand_l": "forearm_l", "hand_r": "forearm_r"}

func _hd_valid(src: Node3D) -> bool:
	var sk := src.find_children("*", "Skeleton3D", true, false)
	if sk.size() != 1: return false
	var k: Skeleton3D = sk[0]
	if k.get_bone_count() != HD_PARENT.size(): return false
	for i in k.get_bone_count():
		var nm := k.get_bone_name(i); var p := k.get_bone_parent(i)
		if not HD_PARENT.has(nm) or HD_PARENT[nm] != (k.get_bone_name(p) if p >= 0 else ""): return false
		if p > i: return false              # the drive assumes parents come first
	return true
# a node's transform in this trooper's space (works before the trooper is in the scene tree)
func _rel(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != self: t = n.transform * t; n = n.get_parent()
	return t

# called with every joint still at rest; the bone's rest pose is turned into "follow this joint from now on"
func _hd_bind(joints: Dictionary) -> void:
	var m: Node3D = hd_src.duplicate(); add_child(m)
	hd_skel = m.find_children("*", "Skeleton3D", true, false)[0]
	var s0 := _rel(hd_skel)
	for i in hd_skel.get_bone_count():
		var j: Node3D = joints.get(hd_skel.get_bone_name(i))
		if j == null: continue
		hd_bones.append([i, j, hd_skel.get_bone_parent(i), _rel(j).affine_inverse() * s0 * hd_skel.get_bone_global_rest(i)])
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm: MeshInstance3D = mi; mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for k in mm.mesh.get_surface_count():
			var src := mm.mesh.surface_get_material(k) as BaseMaterial3D
			if src == null: continue
			if mats.has(src.resource_name): mm.set_surface_override_material(k, mats[src.resource_name]); continue
			var c := src.duplicate() as BaseMaterial3D; c.metallic *= .5     # the generated maps read too glossy here
			mm.set_surface_override_material(k, c)
	_hd_drive()

func _hd_drive() -> void:
	var inv := _rel(hd_skel).affine_inverse(); var glob := {}
	for b in hd_bones:                         # bones come parent first in the imported skeleton
		var g: Transform3D = inv * _rel(b[1]) * b[3]; glob[b[0]] = g
		var l: Transform3D = (glob[b[2]] as Transform3D).affine_inverse() * g if glob.has(b[2]) else g
		hd_skel.set_bone_pose_position(b[0], l.origin)
		hd_skel.set_bone_pose_rotation(b[0], l.basis.get_rotation_quaternion())
		hd_skel.set_bone_pose_scale(b[0], l.basis.get_scale())

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = pos; parent.add_child(n); return n

func _part(name: String, parent: Node3D, mirror := false) -> bool:
	var p := Game.kit_part(name)
	if p == null: return false
	if mirror: p.scale.x = -1
	parent.add_child(p)
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			var key := src.resource_name if src else "base"
			if mats.has(key): m.set_surface_override_material(s, mats[key])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return true

func _leg(side: int, cls: String) -> Node3D:
	var mr := side < 0
	var L := _node(lower, Vector3(side * .13, .95, 0))
	if hd_src:
		var Kh := _node(L, Vector3(0, -.44, 0)); var Bh := _node(Kh, Vector3(0, -.42, 0))
		L.set_meta("knee", Kh); L.set_meta("boot", Bh); return L
	_part("thigh", L, mr)
	_part("thigh__pouch_L" if cls == "L" else "thigh__plate_" + cls, L, mr)
	var K := _node(L, Vector3(0, -.44, 0)); _part("shin", K, mr); _part("shin__greave_" + cls, K, mr)
	var B := _node(K, Vector3(0, -.42, 0)); _part("boot", B, mr)
	if cls == "D": _part("boot__sabaton_D", B, mr)
	L.set_meta("knee", K); L.set_meta("boot", B); return L

func _arm(side: int, cls: String) -> Node3D:
	var mr := side < 0
	var R := _node(upper, Vector3(side * .31, 1.6, 0))
	if hd_src:
		var Fh := _node(R, Vector3(0, -.3, 0)); R.set_meta("fore", Fh); R.set_meta("hand", _node(Fh, Vector3(0, -.27, 0)))
		return R
	_part("upperarm", R, mr)
	if cls != "L": _part("upperarm__plate_" + cls, R, mr)
	var F := _node(R, Vector3(0, -.3, 0)); _part("forearm", F, mr); _part("forearm__bracer_" + cls, F, mr)
	var Hd := _node(F, Vector3(0, -.27, 0)); _part("hand", Hd, mr)
	R.set_meta("fore", F); return R

# ---- two-bone IK, in the twisted upper-body frame (upper arm .3, forearm plus fist .31) ----
func _ik(R: Node3D, target: Vector3, pole: Vector3) -> void:
	var a := .3; var b := .31; var S := R.position
	var d := target - S; var L: float = clamp(d.length(), .08, a + b - .001); d = d.normalized()
	var A := acos(clamp((a * a + L * L - b * b) / (2 * a * L), -1.0, 1.0))
	var pl := (pole - d * pole.dot(d)).normalized()
	var up := (d * cos(A) + pl * sin(A)).normalized()
	R.quaternion = Quaternion(Vector3.DOWN, up)
	var elbow := S + up * a; var fd := (target - elbow).normalized()
	var F: Node3D = R.get_meta("fore"); F.quaternion = Quaternion(Vector3.DOWN, R.quaternion.inverse() * fd)

# IK onto a point given in world space (hands on a ledge while climbing)
func _ik_world(R: Node3D, wt: Vector3, wpole: Vector3) -> void:
	var ut := upper.global_transform
	_ik(R, ut.affine_inverse() * wt, ut.basis.inverse() * wpole)

func _arms(reload: float, dead: float) -> void:
	var gt := gun.transform
	var rT: Vector3 = gt * (hold.rg as Vector3); var lT: Vector3 = gt * (hold.lg as Vector3)
	if reload > 0: lT = lT.lerp(gt * Vector3(0, -.16, .09), sin(PI * reload))
	if dead > 0: rT = Vector3(.55, 1.2, -.2); lT = Vector3(-.55, 1.2, -.2)
	var tw := upper.rotation.y
	_ik(arm_r, rT.rotated(Vector3.UP, -tw), (hold.rp as Vector3).rotated(Vector3.UP, -tw))
	_ik(arm_l, lT.rotated(Vector3.UP, -tw), (hold.lp as Vector3).rotated(Vector3.UP, -tw))

# state: aim (yaw), moving, speed (m/s), move_yaw, dodge 0..1, reload 0..1, fired, dead 0..1, world_move (Vector3 this frame)
func pose(dt: float, st: Dictionary) -> void:
	t += dt
	var moving: bool = st.get("moving", false); var k := 1.0 if moving else 0.0
	ph += dt * (st.get("speed", 0.0) * 1.5 if moving else 0.0)
	var diff := 0.0; var dir := 1.0
	if moving:
		diff = wrapf(st.get("move_yaw", 0.0) - st.get("aim", 0.0), -PI, PI)
		if abs(diff) > PI / 2: diff -= sign(diff) * PI; dir = -1.0
	lower.rotation.y += (diff * .85 - lower.rotation.y) * min(1.0, dt * 12.0)
	var s := sin(ph); var c := cos(ph); var sw := .62 * k * dir
	for pair in [[leg_l, 1.0], [leg_r, -1.0]]:
		var L: Node3D = pair[0]; var sg: float = pair[1]
		var lift: float = max(0.0, sg * c)
		L.rotation.x = -sg * s * sw
		(L.get_meta("knee") as Node3D).rotation.x = k * (.15 + .95 * lift)
		(L.get_meta("boot") as Node3D).rotation.x = k * (-.2 * lift)
	tilt.position = Vector3(0, -abs(c) * .04 * k, 0); body.position.y = abs(c) * .03 * k
	body.rotation.x = .06 * k + sin(t * 2.2) * .012
	rotation.y = st.get("aim", 0.0)
	recoil = min(1.0, max(0.0, recoil - dt * 8.0) + (1.0 if st.get("fired", false) else 0.0))
	gun.position = gun0 - Vector3(0, 0, .06 * recoil); gun.rotation = Vector3(-.12 * recoil, 0, 0)
	var rl: float = st.get("reload", 0.0)
	if rl > 0: gun.rotation.x += .55 * sin(PI * rl); gun.position.y -= .08 * sin(PI * rl)
	var dg: float = st.get("dodge", 0.0)
	if dg > 0:
		var th := dg * TAU; var cy := .95; var sq := sin(PI * dg)
		tilt.rotation.x = th; tilt.position = Vector3(0, cy - cy * cos(th) - .35 * sq, -cy * sin(th))
		for L in [leg_l, leg_r]: L.rotation.x = -1.5 * sq; (L.get_meta("knee") as Node3D).rotation.x = 2.0 * sq
	else: tilt.rotation.x = 0.0
	var dd: float = st.get("dead", 0.0)
	if dd > 0:
		var e := 1.0 - pow(1.0 - min(1.0, dd), 3)
		tilt.rotation.x = -e * PI / 2; tilt.position = Vector3(0, -.1 * e, .9 * e)
	# crouch: down on the right knee, left foot planted forward, a little hunched over the rifle
	var cr: float = st.get("crouch", 0.0) * (1.0 - .45 * k)
	if cr > 0 and dd <= 0 and dg <= 0:
		tilt.position.y -= .44 * cr; body.rotation.x += .16 * cr
		_blend_leg(leg_l, -1.3, 1.3, 0.0, cr); _blend_leg(leg_r, .05, 1.55, -.9, cr)
	tilt.rotation.z = 0.0
	gun.visible = true
	var kind: String = st.get("climb_kind", "")
	var hands := false
	if kind != "" and dd <= 0:
		lower.rotation.y = 0.0
		var u: float = st.get("climb_u", 0.0)
		if kind == "vault": hands = _vault_pose(u, st)
		else: hands = _climb_pose(u, st)
	if not hands: _arms(rl, dd)
	if cape: _cloth_step(dt, st.get("world_move", Vector3.ZERO))
	if hd_skel: _hd_drive()

func _blend_leg(L: Node3D, thigh: float, knee: float, boot: float, w: float) -> void:
	var K: Node3D = L.get_meta("knee"); var B: Node3D = L.get_meta("boot")
	L.rotation.x = lerp(L.rotation.x, thigh, w); K.rotation.x = lerp(K.rotation.x, knee, w); B.rotation.x = lerp(B.rotation.x, boot, w)

# side vault: left hand plants on the top, hips swing over with the knees tucked, rifle stays in the right hand
func _vault_pose(u: float, st: Dictionary) -> bool:
	var sq := sin(PI * u)
	tilt.rotation.z = -.5 * sq; lower.rotation.y = .7 * sq
	_blend_leg(leg_l, -1.35, 1.7, -.3, sq); _blend_leg(leg_r, -1.15, 1.9, -.3, sq)
	var ledge: Vector3 = st.get("climb_ledge", global_position)
	var fwd := global_transform.basis.z; var right := global_transform.basis.x   # the rig's +x side, where the right arm hangs
	var gt := gun.transform
	_ik(arm_r, (gt * (hold.rg as Vector3)).rotated(Vector3.UP, -upper.rotation.y), (hold.rp as Vector3).rotated(Vector3.UP, -upper.rotation.y))
	if u < .75:
		var plant := ledge + fwd * .15 - right * .2 + Vector3(0, .03, 0)
		_ik_world(arm_l, plant, -right + Vector3(0, -.4, 0) - fwd * .3)
	else:
		_ik(arm_l, (gt * (hold.lg as Vector3)).rotated(Vector3.UP, -upper.rotation.y), (hold.lp as Vector3).rotated(Vector3.UP, -upper.rotation.y))
	return true

# climb: rifle slung on the back, both hands on the ledge, pull up, right knee over the edge, stand
func _climb_pose(u: float, st: Dictionary) -> bool:
	var ledge: Vector3 = st.get("climb_ledge", global_position)
	var fwd := global_transform.basis.z; var right := global_transform.basis.x   # the rig's +x side, where the right arm hangs
	var slung := u > .06 and u < .9
	if slung: gun.position = Vector3(0, 1.3, -.3); gun.rotation = Vector3(-1.25, 0, .55)   # across the back, muzzle up over the right shoulder
	else: gun.position = gun0; gun.rotation = Vector3.ZERO
	var lean := sin(PI * u)
	body.rotation.x = .45 * lean
	if u < .55:
		var a := u / .55
		_blend_leg(leg_l, -.9 * a, 1.4 * a, -.4 * a, 1.0); _blend_leg(leg_r, -.2, .5 + .6 * a, 0.0, 1.0)
	else:
		var b := (u - .55) / .45; var up := sin(PI * min(1.0, b * 1.3))
		_blend_leg(leg_r, -1.7 * up, 2.1 * up, -.3 * up, 1.0); _blend_leg(leg_l, -.4 * (1.0 - b), .7 * (1.0 - b), 0.0, 1.0)
	if not slung: return false
	var grip: float = clamp((1.0 - u) / .2, 0.0, 1.0) if u > .7 else 1.0          # let go as he stands
	for side in [1.0, -1.0]:
		var R: Node3D = arm_r if side > 0 else arm_l
		var hand: Vector3 = ledge + right * (.24 * side) - fwd * .02 + Vector3(0, .04, 0)
		if grip < 1.0: hand = hand.lerp(global_position + right * (.35 * side) + Vector3(0, 1.0, 0), 1.0 - grip)
		_ik_world(R, hand, right * side + Vector3(0, -.6, 0) - fwd * .4)
	return true

# ---- cape: verlet cloth pinned at the shoulders, simulated in world space, kept off the pack and legs ----
const CW := 5; const CH := 8; const CSX := .46; const CSY := .82
func _build_cape() -> void:
	cape = _node(body, Vector3(0, 1.64, -.3))
	var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(.46, .04, .05); bar.mesh = bm; bar.material_override = mats.acc; cape.add_child(bar)
	cape_mesh = MeshInstance3D.new(); cape.add_child(cape_mesh); cape_mesh.material_override = mats.cape

func _cloth_step(dt: float, move: Vector3) -> void:
	var M := cape.global_transform; var inv := M.affine_inverse()
	var rest := func(i: int, j: int) -> Vector3: return M * Vector3((float(i) / (CW - 1) - .5) * CSX, -float(j) / (CH - 1) * CSY, -.03 * j / (CH - 1))
	if cloth.is_empty() or move.length() > 3.0:
		cloth.clear(); cloth_prev.clear()
		for j in CH:
			for i in CW: var v: Vector3 = rest.call(i, j); cloth.append(v); cloth_prev.append(v)
	var h: float = min(.05, dt); var dx := CSX / (CW - 1); var dy := CSY / (CH - 1); var dd := Vector2(dx, dy).length()
	var wind := (.25 * sin(t * 1.7) + .15 * sin(t * 3.1)) * .02 * h
	for kk in range(CW, cloth.size()):
		var P: Vector3 = cloth[kk]; var Q: Vector3 = cloth_prev[kk]; var v := (P - Q) * .97
		cloth_prev[kk] = P - move
		cloth[kk] = P + v + Vector3(wind, -9.8 * h * h, 0) - move
	for i in CW: var v: Vector3 = rest.call(i, 0); cloth[i] = v; cloth_prev[i] = v
	for it in 4:
		for j in CH:
			for i in CW:
				var kk := j * CW + i
				if i < CW - 1: _link(kk, kk + 1, dx)
				if j < CH - 1: _link(kk, kk + CW, dy)
				if i < CW - 1 and j < CH - 1: _link(kk, kk + CW + 1, dd); _link(kk + 1, kk + CW, dd)
		for kk in range(CW, cloth.size()):
			var lp: Vector3 = inv * (cloth[kk] as Vector3); var lim: float = -.07 + max(0.0, -lp.y - .5) * .55
			if lp.z > lim: lp.z = lim; cloth[kk] = M * lp
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in CH - 1:
		for i in CW - 1:
			var a := j * CW + i
			for idx in [a, a + 1, a + CW, a + 1, a + CW + 1, a + CW]:
				st.set_uv(Vector2(float(idx % CW) / (CW - 1), float(idx / CW) / (CH - 1))); st.add_vertex(inv * cloth[idx])
	st.generate_normals(); cape_mesh.mesh = st.commit()

func _link(a: int, b: int, L: float) -> void:
	var A: Vector3 = cloth[a]; var B: Vector3 = cloth[b]; var e := B - A; var d: float = max(e.length(), 1e-6)
	var wa := 0.0 if a < CW else 1.0; var wb := 0.0 if b < CW else 1.0; var w := wa + wb
	if w == 0: return
	var f := e * ((d - L) / d)
	cloth[a] = A + f * (wa / w); cloth[b] = B - f * (wb / w)
