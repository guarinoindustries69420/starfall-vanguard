# Starfall Vanguard: a city mission. Lighting and atmosphere, deformable ground with streets and kerbs, a street grid with
# tight alleys, buildings made of breakable columns. A destroyed column becomes a heap of rubble with loose chunks around it;
# both stay for good, block movement and stop bolts, so they are cover. Grenades and artillery dig craters that never fill
# in. Ruins and craters are saved per map, so a city you come back to is still wrecked.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node3D

const SIZE := 160.0                       # map size in metres
const CAM_OFF := Vector3(0, 15, 9.5)      # camera offset from the player
const L_WORLD := 1; const L_PLAYER := 2; const L_ENEMY := 4
const SEED := 7

var map_key := "city_%d" % SEED       # replaced in _ready by the world being fought over
var player: Unit
var cam: Camera3D
var terrain: Terrain
var hud: CanvasLayer; var hud_label: Label; var hud_hp: ProgressBar; var hud_msg: Label; var hud_hint: Label
var reticle: MeshInstance3D
var bolts: Array = []                     # {node, vel, life, dmg, player, heavy}
var columns := {}                         # standing building columns: StaticBody3D -> {hp, size, mat, id, floors, pos}
var col_count := 0
var ruins: Array = []                     # rubble heaps (StaticBody3D)
var debris: Array = []                    # loose chunks (RigidBody3D), frozen in place once they settle
var paint_slabs: Array = []               # road markings, removed where a crater opens
var pending_ruins: Array = []             # columns saved as destroyed, laid out after the standing ones
var rng := RandomNumberGenerator.new()
var shake := 0.0
var kills := 0
var test_t := 0.0; var test := {}

func _ready() -> void:
	map_key = Game.mission_key(); rng.seed = Game.mission_seed()
	_environment()
	_ground()
	_city()
	terrain.build_all()
	_spawn_player()
	for i in 7: _spawn_squad()
	_hud()
	add_child(preload("res://scripts/pause_menu.gd").new())

# ---------- look: sky, sun with shadows, fog, ambient occlusion, bloom ----------
func _environment() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3d5a86"); sm.sky_horizon_color = Color("b9a88a"); sm.ground_horizon_color = Color("6a5c4a"); sm.ground_bottom_color = Color("2a241e")
	sm.sun_angle_max = 20.0; sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = .45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = .85
	env.ssao_enabled = true; env.ssao_radius = 1.6; env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.glow_enabled = true; env.glow_intensity = .6; env.glow_bloom = .08
	env.fog_enabled = true; env.fog_light_color = Color("a99c86"); env.fog_density = .004; env.fog_sky_affect = .3
	env.adjustment_enabled = true; env.adjustment_contrast = 1.08; env.adjustment_saturation = 1.05
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52, -35, 0); sun.light_energy = 1.15
	sun.light_color = Color("fff1dc"); sun.shadow_enabled = true; sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _noise_tex(freq: float, normal: bool, oct := 4, strength := 4.0) -> NoiseTexture2D:
	var n := FastNoiseLite.new(); n.frequency = freq; n.fractal_octaves = oct; n.seed = rng.randi()
	var t := NoiseTexture2D.new(); t.noise = n; t.seamless = true; t.width = 512; t.height = 512
	if normal: t.as_normal_map = true; t.bump_strength = strength
	return t

func _surface(col: Color, rough: float, scale: float, nscale := .6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough
	var gr := Gradient.new(); gr.set_color(0, col.darkened(.25)); gr.set_color(1, col.lightened(.12))
	var alb := _noise_tex(.01, false); alb.color_ramp = gr
	m.albedo_texture = alb; m.albedo_color = Color.WHITE
	m.normal_enabled = true; m.normal_texture = _noise_tex(.03, true); m.normal_scale = nscale
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE * scale
	return m

# the ground is one deformable heightmap; its colour comes from the painted surface (dirt, asphalt, kerb, pavement)
func _ground() -> void:
	var gr := Gradient.new(); gr.set_color(0, Color(.74, .74, .74)); gr.set_color(1, Color(1.0, 1.0, 1.0))
	var alb := _noise_tex(.02, false); alb.color_ramp = gr
	var gt: Texture2D = null
	terrain = Terrain.new(); add_child(terrain)
	if Game.current_world >= 0:                      # bare earth takes the colour of this world's ground
		var biome: String = Game.galaxy.worlds[Game.current_world].biome
		terrain.surf_col[0] = Galaxy.BIOMES[biome].ground
		gt = Game.ground_texture(biome)
		if gt: terrain.surf_col[0] = Color(1, 1, 1)  # the photographed ground shows on bare earth only, not on the paving
	# very bright ground (ice, beach) is toned down a little so it does not glare
	var tint := 1.0
	if gt: tint = clamp(.62 / max(.2, Game.ground_brightness(gt)), .7, 1.0)
	terrain.setup(SIZE + 40, Terrain.make_material(alb, _noise_tex(.04, true, 4, 3.0), gt, tint), L_WORLD)
	terrain.paint_rect(-SIZE / 2, -SIZE / 2, SIZE / 2, SIZE / 2, 3, .12)

# ---------- city: avenues, side streets, alleys, breakable buildings ----------
func _city() -> void:
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("c9b266"); paint.roughness = .7
	var half := SIZE / 2.0
	var lines := []
	var x := -half + rng.randf_range(10, 16)
	var k := 0
	while x < half - 12:
		lines.append({"c": x, "w": 10.0 if k % 2 == 0 else 7.0, "main": k % 2 == 0}); x += rng.randf_range(30, 38); k += 1
	for l in lines:
		terrain.paint_rect(l.c - l.w / 2 - .6, -half, l.c + l.w / 2 + .6, half, 2, .12)
		terrain.paint_rect(-half, l.c - l.w / 2 - .6, half, l.c + l.w / 2 + .6, 2, .12)
	for l in lines:
		terrain.paint_rect(l.c - l.w / 2, -half, l.c + l.w / 2, half, 1, 0.0)
		terrain.paint_rect(-half, l.c - l.w / 2, half, l.c + l.w / 2, 1, 0.0)
		if l.main:
			var y := -half
			while y < half:
				_paint(Vector3(l.c, .012, y), Vector3(.18, .02, 2.2), paint); _paint(Vector3(y, .012, l.c), Vector3(2.2, .02, .18), paint); y += 4.0
	# battle damage from earlier drops on this map, dug in before anything is built on top of it
	for c in Game.battlefield(map_key).craters: terrain.crater(Vector3(c[0], 0, c[1]), c[2], false)
	var cuts := []
	var a := -half
	for l in lines: cuts.append([a, l.c - l.w / 2 - .8]); a = l.c + l.w / 2 + .8
	cuts.append([a, half])
	var styles := [
		{"wall": Color("a89f8e"), "trim": Color("6e2a22"), "roof": Color("5e574c")},
		{"wall": Color("6a7886"), "trim": Color("9fb8cc"), "roof": Color("3c4652")},
		{"wall": Color("846648"), "trim": Color("b88638"), "roof": Color("4a3826")},
		{"wall": Color("62656c"), "trim": Color("9a9ea4"), "roof": Color("35373b")},
	]
	var wall_mats := []
	for st in styles: wall_mats.append({"wall": _facade(st.wall, st.trim), "roof": _surface(st.roof, .95, .3), "rubble": _surface(st.wall.darkened(.25), 1.0, .5)})
	var saved := {}
	for id in Game.battlefield(map_key).ruins: saved[int(id)] = true
	for cx in cuts:
		for cz in cuts: _split(cx[0], cz[0], cx[1], cz[1], 0, wall_mats, saved)
	for info in pending_ruins: _ruin(info, Vector3.ZERO, false)
	_remove_paint_in_craters()

func _paint(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = mat; mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi); paint_slabs.append(mi)

func _remove_paint_in_craters() -> void:
	for s in paint_slabs.duplicate():
		var p: Vector3 = (s as Node3D).position
		if abs(terrain.height_at(p.x, p.z)) > .03: s.queue_free(); paint_slabs.erase(s)

# facade: concrete with a window grid (dark glass) projected in world space
func _facade(wall: Color, trim: Color) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var win := x > 14 and x < 50 and y > 18 and y < 48
			var frame := (x > 12 and x < 52 and y > 16 and y < 50) and not win
			var n := rng.randf_range(-.04, .04)
			var c := wall.lightened(n) if not (win or frame) else (trim if frame else Color("141a24"))
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new(); m.albedo_texture = ImageTexture.create_from_image(img); m.roughness = .85
	m.normal_enabled = true; m.normal_texture = _noise_tex(.05, true, 3, 2.0); m.normal_scale = .4
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE / 3.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

func _split(x0: float, z0: float, x1: float, z1: float, d: int, wall_mats: Array, saved: Dictionary) -> void:
	var w := x1 - x0; var h := z1 - z0
	if w < 5 or h < 5: return
	if (w < 18 and h < 18) or d > 4:
		if player_spawn_near(Vector3((x0 + x1) / 2, 0, (z0 + z1) / 2)): return
		if rng.randf() < .82: _building(x0 + .4, z0 + .4, x1 - .4, z1 - .4, wall_mats[rng.randi() % wall_mats.size()], saved)
		else: terrain.paint_rect(x0 + .6, z0 + .6, x1 - .6, z1 - .6, 0, 0.0)       # an empty lot of bare earth
		return
	var al := rng.randf_range(2.8, 3.6)
	if w >= h:
		var m := x0 + w * rng.randf_range(.38, .62); _split(x0, z0, m - al / 2, z1, d + 1, wall_mats, saved); _split(m + al / 2, z0, x1, z1, d + 1, wall_mats, saved)
	else:
		var m := z0 + h * rng.randf_range(.38, .62); _split(x0, z0, x1, m - al / 2, d + 1, wall_mats, saved); _split(x0, m + al / 2, x1, z1, d + 1, wall_mats, saved)

func player_spawn_near(p: Vector3) -> bool:
	return p.distance_to(Vector3(-SIZE / 2 + 8, 0, -SIZE / 2 + 8)) < 14.0

# a building is a grid of 3 m columns, each its own breakable body. Foundations run 4 m below ground, deeper than any
# crater can dig (Terrain.MIN_H), so a crater beside a standing column shows its footing and never a gap under it.
const FOOT := 4.0
func _building(x0: float, z0: float, x1: float, z1: float, mats: Dictionary, saved: Dictionary) -> void:
	var floors := rng.randi_range(1, 3); var height := floors * 3.2 + rng.randf_range(0, .6)
	var nx: int = max(1, round((x1 - x0) / 3.0)); var nz: int = max(1, round((z1 - z0) / 3.0))
	var tw := (x1 - x0) / nx; var td := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			var id := col_count; col_count += 1
			var cx := x0 + tw * (i + .5); var cz := z0 + td * (j + .5); var gy := .12
			var info := {"hp": 260.0 * floors, "size": Vector3(tw, height, td), "mat": mats.rubble, "id": id, "floors": floors, "pos": Vector3(cx, gy, cz)}
			if saved.has(id): pending_ruins.append(info); continue      # built once every standing column exists
			var body := StaticBody3D.new(); body.collision_layer = L_WORLD; body.position = Vector3(cx, gy + (height - FOOT) / 2, cz)
			var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(tw, height + FOOT, td); cs.shape = sh; body.add_child(cs)
			var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(tw + .02, height + FOOT, td + .02); mi.mesh = bm; mi.material_override = mats.wall; body.add_child(mi)
			var rf := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(tw + .04, .12, td + .04); rf.mesh = rm; rf.material_override = mats.roof
			rf.position.y = (height + FOOT) / 2 + .02; body.add_child(rf)
			add_child(body); columns[body] = info

# ---------- rubble: what a column leaves behind, for good ----------
func _ruin(c: Dictionary, from: Vector3, live: bool, chunks := true) -> StaticBody3D:
	var p: Vector3 = c.pos; var size: Vector3 = c.size; var floors: int = c.floors
	var r := RandomNumberGenerator.new(); r.seed = 1000 + int(c.id) * 7919
	var gy := _ground_min(p, size)                   # sit on the lowest ground under the footprint, so no crater leaves it hanging
	var hgt: float = clamp(.45 * floors + .45 + r.randf_range(-.15, .2), .8, 1.75)
	if c.has("height"): hgt = c.height
	var mound := StaticBody3D.new(); mound.collision_layer = L_WORLD; mound.position = Vector3(p.x, gy, p.z); add_child(mound)
	# three stacked, turned slabs of broken floor, each smaller than the one below, read as a heap
	var y := -.25
	for layer in 3:
		var lh: float = hgt * [.5, .33, .25][layer] + (.25 if layer == 0 else 0.0)
		var s := Vector3(size.x * [.98, .74, .48][layer], lh, size.z * [.98, .7, .5][layer])
		var off := Vector3(r.randf_range(-.22, .22), y + lh / 2, r.randf_range(-.22, .22))
		var rot := Vector3(r.randf_range(-.07, .07), r.randf_range(-.45, .45), r.randf_range(-.07, .07))
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = s; cs.shape = sh; cs.position = off; cs.rotation = rot; mound.add_child(cs)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.material_override = c.mat
		mi.position = off; mi.rotation = rot; mound.add_child(mi)
		y += lh * .82
	mound.set_meta("ruin_id", c.id); mound.set_meta("size", size); ruins.append(mound)
	if not chunks: return mound
	var n: int = clamp(floors * 2 + 1, 3, 7)
	for i in n:
		var s := Vector3(r.randf_range(.6, 1.3), r.randf_range(.35, .8), r.randf_range(.6, 1.3))
		var rb := RigidBody3D.new(); rb.collision_layer = L_WORLD; rb.collision_mask = L_WORLD; rb.continuous_cd = true
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = s; cs.shape = sh; rb.add_child(cs)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.material_override = c.mat; rb.add_child(mi)
		rb.mass = s.x * s.y * s.z * 2.0
		if live:                                     # tumbling down off the collapsing column
			rb.position = Vector3(p.x + r.randf_range(-size.x / 2, size.x / 2), gy + hgt + r.randf_range(.3, max(.4, size.y - hgt)), p.z + r.randf_range(-size.z / 2, size.z / 2))
			add_child(rb)
			var away := rb.position - from; away.y = abs(away.y) + 2.0
			rb.apply_central_impulse(away.normalized() * r.randf_range(2, 5) * rb.mass)
			rb.angular_velocity = Vector3(r.randf_range(-4, 4), r.randf_range(-4, 4), r.randf_range(-4, 4))
			_settle(rb)
		else:                                        # the map was loaded with this column already down: chunks at rest
			var q := Vector3.INF
			for tries in 10:                         # a spot beside the heap that is not inside a standing building
				var a := r.randf() * TAU; var rr := r.randf_range(max(size.x, size.z) * .5 + .2, max(size.x, size.z) * .5 + 1.8)
				var cand := Vector3(p.x + cos(a) * rr, 0, p.z + sin(a) * rr)
				if not _inside_column(cand, max(s.x, s.z) * .5): q = cand; break
			if q == Vector3.INF: rb.free(); continue
			q.y = terrain.height_at(q.x, q.z) + s.y / 2 - .05
			rb.position = q; rb.rotation = Vector3(r.randf_range(-.15, .15), r.randf() * TAU, r.randf_range(-.15, .15)); rb.freeze = true
			add_child(rb)
		debris.append(rb)
	return mound

func _ground_min(p: Vector3, size: Vector3) -> float:
	var lo := 1e9
	for fx in [-.5, 0.0, .5]:
		for fz in [-.5, 0.0, .5]: lo = min(lo, terrain.height_at(p.x + fx * size.x, p.z + fz * size.z))
	return lo

func _inside_column(q: Vector3, margin: float) -> bool:
	for b in columns:
		var c: Dictionary = columns[b]; var cp: Vector3 = c.pos; var cs: Vector3 = c.size
		if abs(q.x - cp.x) < cs.x / 2 + margin and abs(q.z - cp.z) < cs.z / 2 + margin: return true
	return false

# A loose chunk freezes once it has come to rest and stays there as an obstacle. The check only runs while the game
# runs (paused time does not count), each new throw starts a new check so an older one cannot freeze it in flight,
# and a chunk still moving is checked again a moment later.
func _settle(rb: RigidBody3D) -> void:
	rb.freeze = false; rb.can_sleep = true
	var gen: int = rb.get_meta("settle", 0) + 1; rb.set_meta("settle", gen)
	if not rb.has_meta("hooked"):
		rb.set_meta("hooked", true)
		rb.sleeping_state_changed.connect(func(): if is_instance_valid(rb) and rb.sleeping and not rb.freeze: rb.set_deferred("freeze", true))
	_settle_check(rb, gen, 3.0, 0)

# at rest: freeze. Still creeping (a chunk rocking in a crater bowl) after several looks: freeze once it is slow.
# Still moving fast after ten seconds of game time is not possible for a chunk on the ground, so it freezes then.
func _settle_check(rb: RigidBody3D, gen: int, wait: float, tries: int) -> void:
	get_tree().create_timer(wait, false, true).timeout.connect(func():
		if not is_instance_valid(rb) or rb.freeze or rb.get_meta("settle", 0) != gen: return
		var v := rb.linear_velocity.length()
		if (v < .25 and rb.angular_velocity.length() < .5) or (tries >= 4 and v < 1.5) or tries >= 9: rb.freeze = true
		else: _settle_check(rb, gen, .75, tries + 1))

# ---------- player and enemies ----------
func _spawn_player() -> void:
	player = preload("res://scripts/player.gd").new(); player.mission = self
	player.position = Vector3(-SIZE / 2 + 8, .3, -SIZE / 2 + 8); add_child(player)
	cam = Camera3D.new(); cam.fov = 45; cam.far = 400; add_child(cam)
	cam.position = player.position + CAM_OFF; cam.look_at(player.position)
	reticle = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = .32; tm.outer_radius = .4; reticle.mesh = tm
	var rm := StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color(1, .85, .45, .85)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.no_depth_test = true; reticle.material_override = rm
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(reticle)

func _spawn_squad() -> void:
	var p := Vector3(rng.randf_range(-SIZE / 2 + 20, SIZE / 2 - 10), 1, rng.randf_range(-SIZE / 2 + 20, SIZE / 2 - 10))
	if p.distance_to(player.position) < 30: p += Vector3(30, 0, 30)
	for i in rng.randi_range(2, 4):
		var e: Unit = preload("res://scripts/enemy.gd").new(); e.mission = self
		e.position = _free_spot(p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))); add_child(e)

func _free_spot(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	for k in 40:
		var q := p + Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * k * .8
		q.y = terrain.height_at(q.x, q.z) + .1
		var prm := PhysicsShapeQueryParameters3D.new(); var sh := SphereShape3D.new(); sh.radius = .6; prm.shape = sh
		prm.transform = Transform3D(Basis(), q + Vector3(0, 1, 0)); prm.collision_mask = L_WORLD
		if space.intersect_shape(prm, 1).is_empty(): return q
	return p

# ---------- bolts, grenades, artillery, explosions, destruction ----------
func fire_bolt(from: Vector3, dir: Vector3, speed: float, dmg: float, from_player: bool, col: Color, heavy := false) -> void:
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = .05; cm.height = .9; mi.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 4.0
	mi.material_override = m; mi.position = from; add_child(mi)
	var up := Vector3.UP if abs(dir.y) < .95 else Vector3.FORWARD
	mi.look_at(from + dir, up); mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	bolts.append({"node": mi, "vel": dir * speed, "life": 1.2, "dmg": dmg, "player": from_player, "heavy": heavy})
	var fl := OmniLight3D.new(); fl.light_color = col; fl.light_energy = 2.0; fl.omni_range = 4.0; fl.position = from; add_child(fl)
	get_tree().create_timer(.05, false).timeout.connect(fl.queue_free)

func throw_grenade(by: Unit, target: Vector3, reach := 1.0) -> void:
	var g := RigidBody3D.new(); g.collision_layer = 0; g.collision_mask = L_WORLD; g.mass = .5
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = .12; cs.shape = sh; g.add_child(cs)
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = .12; sm.height = .24; mi.mesh = sm
	var m := StandardMaterial3D.new(); m.albedo_color = Color("3a3f2c"); m.emission_enabled = true; m.emission = Color("ff6a2a"); m.emission_energy_multiplier = .6
	mi.material_override = m; g.add_child(mi)
	var start := by.global_position + Vector3(0, 1.7, 0); g.position = start; add_child(g)
	var to := target - start; to.y = terrain.height_at(target.x, target.z) - start.y
	var flat := Vector2(to.x, to.z).length(); if flat > 26.0: to *= 26.0 / flat; flat = 26.0
	var T: float = clamp(flat / 16.0, .45, 1.2)
	g.linear_velocity = Vector3(to.x / T, (to.y + .5 * 19.6 * T * T) / T, to.z / T)
	get_tree().create_timer(1.7, false).timeout.connect(func():
		if is_instance_valid(g): explode(g.global_position, 5.0 * reach, 160.0, 2.2); g.queue_free())

# artillery: a red marker goes down, then six shells land around it over a few seconds; lead is the wait for the first
func call_barrage(center: Vector3, lead := 2.0) -> void:
	center.y = terrain.height_at(center.x, center.z)
	var beacon := OmniLight3D.new(); beacon.light_color = Color("ff3a2a"); beacon.light_energy = 3.0; beacon.omni_range = 6.0; beacon.position = center + Vector3(0, .6, 0); add_child(beacon)
	get_tree().create_timer(6.5, false).timeout.connect(beacon.queue_free)
	for i in 6:
		var a := rng.randf() * TAU; var rr := sqrt(rng.randf()) * 9.0
		var p := center + Vector3(cos(a) * rr, 0, sin(a) * rr)
		get_tree().create_timer(lead + i * .6, false).timeout.connect(func(): _shell(p))

func _shell(p: Vector3) -> void:
	p.y = terrain.height_at(p.x, p.z)
	var streak := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = .12; cm.height = 3.0; streak.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color("ffd9a0"); m.emission_enabled = true; m.emission = Color("ffb35a"); m.emission_energy_multiplier = 6.0
	streak.material_override = m; streak.position = p + Vector3(0, 40, 0); add_child(streak)
	var tw := create_tween(); tw.tween_property(streak, "position", p + Vector3(0, 1.5, 0), .35)
	tw.tween_callback(func(): streak.queue_free(); explode(p, 7.0, 400.0, 4.6))

# blast: light, fire, dust; hurts what is near, knocks loose rubble about, and digs a crater when it is at ground level
func explode(pos: Vector3, radius: float, dmg: float, crater_r := 0.0) -> void:
	shake = min(1.4, shake + radius * .12)
	if is_instance_valid(player):
		var dd := player.global_position.distance_to(pos)
		Game.rumble(clamp(1.0 - dd / 40.0, 0.0, 1.0) * .6, clamp(1.0 - dd / 30.0, 0.0, 1.0), .35)
	var fl := OmniLight3D.new(); fl.light_color = Color("ffb35a"); fl.light_energy = 12.0; fl.omni_range = radius * 3; fl.position = pos + Vector3(0, 1, 0); add_child(fl)
	var tw := create_tween(); tw.tween_property(fl, "light_energy", 0.0, .5); tw.tween_callback(fl.queue_free)
	_particles(pos, Color("ffb35a"), 40, 9.0, .6, .25)
	_particles(pos, Color("7a7266"), 30, 3.0, 2.2, .7)
	for b in columns.keys():
		if not is_instance_valid(b): continue
		var d: float = (b as Node3D).global_position.distance_to(pos) - max(columns[b].size.x, columns[b].size.z) / 2
		if d < radius: damage_column(b, dmg * (1.0 - .5 * max(0.0, d) / radius) * 1.5, pos)
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(pos)
		if d < radius: e.hurt(dmg * (1.0 - .5 * d / radius))
	if is_instance_valid(player) and player.global_position.distance_to(pos) < radius: player.hurt(dmg * .5, true)
	var gy := terrain.height_at(pos.x, pos.z)
	if crater_r > 0 and pos.y - gy < 1.2:
		var cp := Vector3(pos.x, gy, pos.z)
		terrain.crater(cp, crater_r); Game.record_crater(map_key, cp, crater_r)
		_remove_paint_in_craters()
		for m in ruins:                                  # a heap sinks with the ground under it
			if is_instance_valid(m) and m.has_meta("size"):
				var mn: Node3D = m; mn.position.y = min(mn.position.y, _ground_min(mn.position, m.get_meta("size")))
	for rb in debris:                                    # loose chunks near the blast are thrown, then settle again
		if not is_instance_valid(rb): continue
		var away: Vector3 = (rb as Node3D).global_position - pos
		if away.length() < radius * 1.2:
			_settle(rb); away.y = abs(away.y) + 1.5
			rb.apply_central_impulse(away.normalized() * rb.mass * (1.0 - away.length() / (radius * 1.2)) * 9.0)

func damage_column(b: StaticBody3D, dmg: float, from: Vector3) -> void:
	var c: Dictionary = columns[b]; c.hp -= dmg
	if c.hp > 0: return
	columns.erase(b)
	_particles(b.global_position, Color("8a8478"), 40, 4.0, 2.5, 1.2)
	b.queue_free()
	_ruin(c, from, true)
	Game.record_ruin(map_key, c.id)

# a soft round puff, shared by every particle so dust and fire have no hard square edges
var _puff_tex: GradientTexture2D
func _puff() -> GradientTexture2D:
	if _puff_tex: return _puff_tex
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(.45, Color(1, 1, 1, .55))
	_puff_tex = GradientTexture2D.new(); _puff_tex.gradient = g; _puff_tex.fill = GradientTexture2D.FILL_RADIAL
	_puff_tex.fill_from = Vector2(.5, .5); _puff_tex.fill_to = Vector2(1, .5); _puff_tex.width = 64; _puff_tex.height = 64
	return _puff_tex

func _particles(pos: Vector3, col: Color, n: int, speed: float, life: float, size: float) -> void:
	var p := CPUParticles3D.new(); p.position = pos + Vector3(0, .5, 0); p.amount = n; p.one_shot = true; p.explosiveness = .95; p.lifetime = life
	p.direction = Vector3.UP; p.spread = 80.0; p.initial_velocity_min = speed * .4; p.initial_velocity_max = speed; p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = size * .5; p.scale_amount_max = size * 1.5
	var qm := QuadMesh.new(); qm.size = Vector2(1, 1); p.mesh = qm
	var m := StandardMaterial3D.new(); m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff(); p.material_override = m
	var g := Gradient.new(); g.set_color(0, Color(col, .9)); g.set_color(1, Color(col, 0)); p.color_ramp = g
	add_child(p); p.emitting = true
	get_tree().create_timer(life + .2, false).timeout.connect(p.queue_free)

func _physics_process(dt: float) -> void:
	# safety net: a chunk that tunnels through the ground (a fast throw, or a crater opening under it) is put back on top
	for rb in debris:
		if is_instance_valid(rb) and not rb.freeze:
			var p: Vector3 = rb.global_position; var gh := terrain.height_at(p.x, p.z)
			if p.y < gh - 2.0:
				rb.global_position = Vector3(p.x, gh + 1.0, p.z); rb.linear_velocity = Vector3.ZERO; rb.angular_velocity = Vector3.ZERO
				test["rescued"] = test.get("rescued", 0) + 1
	var space := get_world_3d().direct_space_state
	for b in bolts.duplicate():
		var n: MeshInstance3D = b.node; var from := n.position; var to: Vector3 = from + b.vel * dt
		var q := PhysicsRayQueryParameters3D.create(from, to); q.collision_mask = L_WORLD | (L_ENEMY if b.player else L_PLAYER)
		var hit := space.intersect_ray(q)
		b.life -= dt
		if hit or b.life <= 0:
			if hit:
				var c = hit.collider
				if c.has_method("hurt"): c.hurt(b.dmg)
				elif columns.has(c): damage_column(c, b.dmg * (.6 if b.heavy else .1), hit.position)
				_particles(hit.position, Color("ffd59a"), 6, 3.0, .25, .08)
				if b.player: test["bolt_hits"] = test.get("bolt_hits", 0) + 1
			n.queue_free(); bolts.erase(b); continue
		n.position = to

func _process(dt: float) -> void:
	if is_instance_valid(player) and not test.get("hold_cam", false):
		var target: Vector3 = player.global_position + CAM_OFF + (player.aim_dir as Vector3) * 4.0
		cam.position = cam.position.lerp(target, min(1.0, dt * 5.0))
		shake = max(0.0, shake - dt * 2.0)
		cam.h_offset = randf_range(-1, 1) * shake * .3; cam.v_offset = randf_range(-1, 1) * shake * .3
		cam.look_at(cam.position - CAM_OFF, Vector3.UP)
		var ap: Vector3 = player.aim_point
		reticle.visible = player.hp > 0
		reticle.position = Vector3(ap.x, terrain.height_at(ap.x, ap.z) + .06, ap.z)
		hud_hp.value = player.hp
		var wpn := "Reloading" if player.reload_t > 0 else "K-7 Pulse Rifle"
		var art := "ready" if player.barrage_cd <= 0 else "%d s" % int(ceil(player.barrage_cd))
		var su: Dictionary = Game.SUITS[player.suit]; var pas: String = su.passive
		if player.mods.reactive: pas += " ON" if player.plate_t > 0 else (" %d s" % int(ceil(player.plate_cd)) if player.plate_cd > 0 else " ready")
		hud_label.text = "%s   %d / %d     Grenades %d     Artillery %s     Kills %d     %s: %s" % [wpn, player.ammo, player.mag, player.grenades, art, kills, su.name, pas]
		hud_hint.text = "%s fire   %s steady   %s dive / vault / climb   %s crouch   %s reload   %s grenade   %s artillery   %s sprint   %s pause" % [
			Game.prompt("fire"), Game.prompt("steady"), Game.prompt("roll"), Game.prompt("crouch"), Game.prompt("reload"),
			Game.prompt("grenade"), Game.prompt("barrage"), Game.prompt("sprint"), Game.prompt("pause")]
	if Game.test_mode: _test(dt)

func _hud() -> void:
	hud = CanvasLayer.new(); add_child(hud)
	hud_hp = ProgressBar.new(); hud_hp.position = Vector2(24, 24); hud_hp.size = Vector2(320, 16); hud_hp.max_value = 100; hud_hp.show_percentage = false; hud.add_child(hud_hp)
	hud_label = Label.new(); hud_label.position = Vector2(24, 46); hud_label.add_theme_font_size_override("font_size", 20); hud.add_child(hud_label)
	hud_msg = Label.new(); hud_msg.text = "Starfall Vanguard · city mission"
	if Game.current_world >= 0:
		var w: Dictionary = Game.galaxy.worlds[Game.current_world]
		hud_msg.text = "%s · %s · fighting the %s" % [w.name, Galaxy.BIOMES[w.biome].name, Galaxy.FAC[Game.enemy_faction].name]
	hud_msg.position = Vector2(24, 76); hud_msg.modulate = Color(1, 1, 1, .8); hud.add_child(hud_msg)
	hud_hint = Label.new(); hud_hint.anchor_top = 1.0; hud_hint.anchor_bottom = 1.0; hud_hint.position = Vector2(24, -40); hud_hint.offset_top = -40
	hud_hint.add_theme_font_size_override("font_size", 16); hud_hint.modulate = Color(1, 1, 1, .9); hud.add_child(hud_hint)
	# readable over any ground, even bright ice: a dark backing strip and an outline on every line of text
	for pair in [[Vector2(12, 16), Vector2(720, 86), false], [Vector2(12, -50), Vector2(1100, 40), true]]:
		var back := ColorRect.new(); back.color = Color(0, 0, 0, .45); back.position = pair[0]; back.size = pair[1]
		if pair[2]: back.anchor_top = 1.0; back.anchor_bottom = 1.0; back.offset_top = -50; back.offset_bottom = -10
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(back); hud.move_child(back, 0)
	for l in [hud_label, hud_msg, hud_hint]: Game.readable(l)

# ---------- test mode: drive everything, check it, save screenshots, quit ----------
func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image(); img.save_png("user://t_%s.png" % name)

func _check(name: String, ok: bool, detail := "") -> void:
	print("CHECK ", "PASS " if ok else "FAIL ", name, "  ", detail)

func _pad_axis(axis: int, v: float) -> void:
	var ev := InputEventJoypadMotion.new(); ev.axis = axis; ev.axis_value = v; ev.device = 0; Input.parse_input_event(ev)

func _pad_button(b: int, down: bool) -> void:
	var ev := InputEventJoypadButton.new(); ev.button_index = b; ev.pressed = down; ev.device = 0; Input.parse_input_event(ev)

func _at(t: float, dt: float) -> bool: return test_t - dt < t and test_t >= t

# every exosuit builds, and each passive does what its card says (tried on the live player, then put back)
func _suit_checks() -> void:
	var P = player; var keep: String = P.suit
	var built := 0
	for id in Game.SUIT_ORDER:
		P.wear(id)
		if P.model.leg_l != null and P.model.gun != null: built += 1
	_check("every exosuit builds", built == Game.SUIT_ORDER.size(), "%d of %d" % [built, Game.SUIT_ORDER.size()])
	var M := func(id: String) -> Dictionary: return Game.suit_mod(id)
	var ok: bool = M.call("pathfinder").speed > M.call("vanguard").speed and M.call("vanguard").speed > M.call("bulwark").speed \
		and M.call("pathfinder").taken > M.call("vanguard").taken and M.call("vanguard").taken > M.call("bulwark").taken
	_check("light is fastest and thinnest, heavy slowest and toughest", ok, "speed %.2f %.2f %.2f, damage taken %.2f %.2f %.2f" % [M.call("pathfinder").speed, M.call("vanguard").speed, M.call("bulwark").speed, M.call("pathfinder").taken, M.call("vanguard").taken, M.call("bulwark").taken])
	var res := []
	P.wear("bulwark"); P.hp = 100.0; P.hurt(100.0, true); var hb: float = 100.0 - P.hp
	P.wear("sentinel"); P.hp = 100.0; P.hurt(100.0, true); var hs: float = 100.0 - P.hp
	res.append(["Blast Dampers halve blast damage", abs(hb - hs * .5) < .01, "%.1f against %.1f for another heavy" % [hb, hs]])
	P.wear("drakeguard"); P.hp = 50.0; P.hurt(30.0); var first: float = 50.0 - P.hp; var on: float = P.plate_t; P.hurt(10.0); var second: float = 50.0 - first - P.hp
	res.append(["Reactive Plating hardens under 35 health", on > 2.9 and abs(first - 30.0 * .7 * .5) < .01 and abs(second - 10.0 * .7 * .5) < .01, "first hit %.2f, next %.2f, plates %.1f s" % [first, second, on]])
	res.append(["Ordnance Rack carries 7 grenades", P.grenades == 4 and Game.suit_mod("ashwalker").grenades == 7 and Game.suit_mod("ashwalker").grenade_r > 1.3, ""])
	res.append(["Autoloader reloads faster", Game.suit_mod("vanguard").reload < Game.suit_mod("warden").reload * .6, "%.2f s" % Game.suit_mod("vanguard").reload])
	res.append(["Uplink Array calls artillery sooner", Game.suit_mod("sentinel").barrage_cd < 30.0 and Game.suit_mod("sentinel").barrage_lead < 2.0, ""])
	res.append(["Servo Striders sprint faster and dive sooner", Game.suit_mod("pathfinder").sprint > 1.8 and Game.suit_mod("pathfinder").dive_cd < Game.suit_mod("ashwalker").dive_cd, ""])
	P.wear("warden"); P.hp = 40.0; P.calm_t = 10.0
	test.regen_from = 40.0
	for r in res: _check(r[0], r[1], r[2])
	test.keep_suit = keep

func _test(dt: float) -> void:
	test_t += dt
	var P: Unit = player
	if _at(0.05, dt):
		var b := Game.battlefield(map_key)
		print("LOAD saved ruins ", b.ruins.size(), " saved craters ", b.craters.size(), " standing columns ", columns.size(), " heaps ", ruins.size())
		if b.craters.size() > 0:
			var c0: Array = b.craters[0]; _check("saved crater is dug in on reload", terrain.height_at(c0[0], c0[1]) < -.3, "depth %.2f" % terrain.height_at(c0[0], c0[1]))
		test.start = P.global_position
		_suit_checks()
	if _at(.6, dt):
		_check("Trauma Injector heals after 4 s without a hit", P.hp > test.regen_from + 2.0, "%.1f -> %.1f" % [test.regen_from, P.hp])
		P.wear(test.keep_suit); P.hp = 100.0
	# 1. controller: left stick moves, right stick aims, Circle crouches
	if _at(.1, dt): _pad_axis(JOY_AXIS_LEFT_X, 1.0); _pad_axis(JOY_AXIS_RIGHT_X, -1.0)
	if _at(.8, dt):
		_check("pad switches prompts", Game.using_pad, Game.prompt("roll"))
		_check("left stick moves", P.global_position.x - test.start.x > 2.0, "%.2f m" % (P.global_position.x - test.start.x))
		_check("right stick aims", P.aim_dir.x < -.8, str(P.aim_dir))
		_pad_axis(JOY_AXIS_LEFT_X, 0.0); _pad_axis(JOY_AXIS_RIGHT_X, 0.0); _pad_button(JOY_BUTTON_B, true)
	if _at(.85, dt): _pad_button(JOY_BUTTON_B, false)
	if _at(1.3, dt): _check("Circle crouches", P.crouch > .9, "%.2f" % P.crouch); _shot("crouch")
	if _at(1.35, dt): _pad_button(JOY_BUTTON_B, true)
	if _at(1.4, dt): _pad_button(JOY_BUTTON_B, false)
	# 2. shooting a target placed in the line of fire
	if _at(1.5, dt):
		var e: Unit = preload("res://scripts/enemy.gd").new(); e.mission = self
		e.position = _free_spot(P.global_position + Vector3(9, 0, 3)); add_child(e); test.target = e
	if test_t > 1.7 and test_t < 3.4 and test.has("target") and is_instance_valid(test.target):
		var e: Unit = test.target; P.test_aim = e.global_position + Vector3(0, e.chest(), 0); P.test_fire = e.hp > 0
	if _at(3.4, dt):
		P.test_fire = false; P.test_aim = Vector3.ZERO
		_check("bolts kill", kills >= 1, "kills %d, hits %d" % [kills, test.get("bolt_hits", 0)])
	# 3. a low heap to vault and a tall one to climb, laid in the open in front of the player
	if _at(3.5, dt):
		# find a straight run of open ground, 16 m long, and lay a low heap and a tall heap across it
		var o := P.global_position; o.y = 0; var run := Vector3(1, 0, 0)
		var space := get_world_3d().direct_space_state
		for k in 16:
			var dd := Vector3(cos(k * TAU / 16), 0, sin(k * TAU / 16)); var ok := true
			for s in range(1, 19):
				var prm := PhysicsShapeQueryParameters3D.new(); var sh := SphereShape3D.new(); sh.radius = 2.4; prm.shape = sh
				var c := o + dd * s; prm.transform = Transform3D(Basis(), Vector3(c.x, terrain.height_at(c.x, c.z) + 2.6, c.z)); prm.collision_mask = L_WORLD
				if not space.intersect_shape(prm, 1).is_empty(): ok = false; break
			if ok: run = dd; break
		test.run = run
		P.global_position = o + Vector3(0, .2, 0); P.aim_dir = run
		var mat = columns.values()[0].mat
		var low := {"pos": o + run * 4.5, "size": Vector3(1.6, 3, 3.2), "floors": 1, "id": -1, "mat": mat, "height": .85}
		var tall := {"pos": o + run * 14.5, "size": Vector3(3.2, 3, 3.2), "floors": 3, "id": -2, "mat": mat, "height": 1.65}
		var tall2 := tall.duplicate(); tall2.pos = o + run * 14.5
		_ruin(low, Vector3.ZERO, false, false); _ruin(tall2, Vector3.ZERO, false, false)
		# a solid chest-high wall stub: too tall to vault, so it has to be climbed
		var wall := StaticBody3D.new(); wall.collision_layer = L_WORLD; var wp: Vector3 = o + run * 9.0
		wall.position = Vector3(wp.x, terrain.height_at(wp.x, wp.z) + .8, wp.z); wall.rotation.y = atan2(run.x, run.z)
		var wcs := CollisionShape3D.new(); var wsh := BoxShape3D.new(); wsh.size = Vector3(3.0, 1.6, .7); wcs.shape = wsh; wall.add_child(wcs)
		var wmi := MeshInstance3D.new(); var wbm := BoxMesh.new(); wbm.size = wsh.size; wmi.mesh = wbm; wmi.material_override = mat; wall.add_child(wmi)
		add_child(wall); ruins.append(wall)
		test.climbs0 = P.climbs; test.y0 = P.global_position.y
	if test_t > 3.6 and test_t < 9.1: P.test_input = Vector2(test.run.x, test.run.z)
	if _at(3.6, dt): test.max_y = -99.0
	if test_t > 3.6 and test_t < 9.1:
		test.max_y = max(test.max_y, P.global_position.y)
		if P.climbing() and P.climb_kind == "vault" and P.climb_t > .4 and not test.has("shot_vault"): test.shot_vault = true; _shot("vault")
		if P.climbing() and P.climb_kind == "climb" and P.climb_t > .3 and not test.has("shot_climb"): test.shot_climb = true; _shot("climb")
		if P.climbing() and P.climb_kind == "climb" and P.climb_t > .7 and not test.has("shot_climb2"): test.shot_climb2 = true; _shot("climb2")
	if _at(9.0, dt) and OS.get_environment("SV_SHORT") != "": get_tree().quit()
	if _at(9.1, dt):
		P.test_input = Vector2.ZERO
		_check("vaulted and climbed", P.climbs - test.climbs0 >= 3 and test.has("shot_climb"), "%d moves, kinds seen: vault %s climb %s" % [P.climbs - test.climbs0, test.has("shot_vault"), test.has("shot_climb")])
		_check("stood on top of the tall heap", test.max_y > test.y0 + 1.3, "peak %.2f m above start" % (test.max_y - test.y0))
	# 4. ordnance: blow the nearest building, then call artillery on a block
	if _at(9.2, dt):
		P.hp = 1e6                                       # the test watches the blast from close by
		var nearest = null; var nd := 1e9
		for b in columns.keys():
			if is_instance_valid(b):
				var d: float = (b as Node3D).global_position.distance_to(P.global_position)
				if d < nd: nd = d; nearest = b
		if nearest:
			var np: Vector3 = (nearest as Node3D).global_position
			test.blast = Vector3(np.x, terrain.height_at(np.x, np.z), np.z) + (P.global_position - np).normalized() * 2.5
			test.blast.y = terrain.height_at(test.blast.x, test.blast.z)
			test.cols0 = columns.size(); test.h0 = terrain.height_at(test.blast.x, test.blast.z)
			explode(test.blast, 6.0, 900.0, 3.0)
	if _at(9.5, dt):
		_check("explosion leaves a crater", terrain.height_at(test.blast.x, test.blast.z) < test.h0 - .6, "%.2f -> %.2f" % [test.h0, terrain.height_at(test.blast.x, test.blast.z)])
		_check("destroyed columns leave heaps", columns.size() < test.cols0 and ruins.size() > 2, "columns %d -> %d, heaps %d" % [test.cols0, columns.size(), ruins.size()])
		test.barrage = P.global_position + Vector3(14, 0, 12)
		call_barrage(test.barrage)
	if _at(10.5, dt): _shot("collapse")
	if _at(19.5, dt):
		var frozen := 0
		for rb in debris: if is_instance_valid(rb) and rb.freeze: frozen += 1
		var below := 0
		for rb in debris:
			if is_instance_valid(rb) and (rb as Node3D).global_position.y < terrain.height_at(rb.global_position.x, rb.global_position.z) - 2.0: below += 1
		_check("loose chunks settle and stay on the ground", frozen >= debris.size() - 2 and debris.size() > 0 and below == 0,
			"%d of %d frozen, %d below ground, %d put back after falling through" % [frozen, debris.size(), below, test.get("rescued", 0)])
		var q := PhysicsRayQueryParameters3D.create(Vector3(0, 0, 0), Vector3(0, 0, 0))
		var blocked := 0
		for m in ruins:
			if not is_instance_valid(m): continue
			var mp: Vector3 = (m as Node3D).global_position
			q = PhysicsRayQueryParameters3D.create(mp + Vector3(-4, .5, 0), mp + Vector3(4, .5, 0)); q.collision_mask = L_WORLD
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty(): blocked += 1
		_check("heaps stop bolts at waist height", blocked == ruins.size(), "%d of %d" % [blocked, ruins.size()])
		var b := Game.battlefield(map_key)
		_check("ruins and craters saved", b.ruins.size() >= test.cols0 - columns.size() and b.craters.size() >= 7, "ruins %d craters %d" % [b.ruins.size(), b.craters.size()])
		P.global_position = test.barrage + Vector3(0, 4, 0); cam.position = test.barrage + CAM_OFF; cam.look_at(test.barrage); test.hold_cam = true; _shot("craters")
	if _at(19.9, dt): _shot("craters2")
	if test_t > 20.1: get_tree().quit()
