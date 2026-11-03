# Starfall Vanguard: the galaxy map. Each faction's arm is shaded in its colour, borders glow where territories meet,
# space lanes join the worlds, and a cockpit panel describes whatever world is selected. Mouse, keyboard or a PS5 pad:
# left stick moves the cursor, right stick pans, L2 and R2 zoom, L1 and R1 jump between capitals, Cross drops in.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node2D

const TERRITORY_SHADER := """
shader_type canvas_item;
uniform vec2 pts[200];
uniform vec4 cols[200];
uniform int count;
uniform vec2 origin;
varying vec2 world;
void vertex() { world = VERTEX + origin; }
void fragment() {
	float d1 = 1e9; float d2 = 1e9; int i1 = 0; int i2 = 0;
	for (int i = 0; i < count; i++) {
		float d = distance(world, pts[i]);
		if (d < d1) { d2 = d1; i2 = i1; d1 = d; i1 = i; } else if (d < d2) { d2 = d; i2 = i; }
	}
	float r = length(world);
	float a = atan(world.y, world.x) - r * 0.0011;
	float arms = 0.5 + 0.5 * cos(4.0 * a);
	float dust = exp(-r / 520.0) * (0.25 + 0.35 * arms);
	vec3 col = vec3(0.55, 0.6, 0.75) * dust;
	vec4 c1 = cols[i1];
	float reach = 1.0 - smoothstep(110.0, 190.0, d1);
	col = mix(col, c1.rgb, 0.16 * reach);
	bool border = distance(cols[i1].rgb, cols[i2].rgb) > 0.05;
	float edge = 1.0 - smoothstep(0.0, 7.0, d2 - d1);
	if (border) col = mix(col, max(c1.rgb, cols[i2].rgb), 0.55 * edge * reach);
	COLOR = vec4(col, 1.0);
}
"""

var G: Galaxy
var cam: Camera2D
var sel := -1
var cursor := Vector2.ZERO
var stars: Array = []
var ui: CanvasLayer; var title: Label; var counts: RichTextLabel; var info: RichTextLabel; var hint: Label
var terr: ColorRect
var cap_cycle := 0
var test_t := 0.0

func _ready() -> void:
	name = "Galaxy"
	G = Game.galaxy
	RenderingServer.set_default_clear_color(Color("05070c"))
	var r := RandomNumberGenerator.new(); r.seed = 99
	for i in 1400: stars.append([Vector2(r.randf_range(-1500, 1500), r.randf_range(-1100, 1100)), r.randf_range(.6, 1.8), r.randf_range(.25, .9)])
	terr = ColorRect.new(); terr.position = Vector2(-1250, -1250); terr.size = Vector2(2500, 2500); add_child(terr)
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = TERRITORY_SHADER; sm.shader = sh; terr.material = sm
	terr.show_behind_parent = true
	_push_territory()
	cam = Camera2D.new(); cam.zoom = Vector2(.42, .42); add_child(cam); cam.make_current()
	_ui()
	sel = G.capitals.get(Game.player_faction, 0); cursor = G.worlds[sel].pos
	_refresh()
	Game.say("map_open", 600.0)

func _push_territory() -> void:
	var pts := PackedVector2Array(); var cols := PackedColorArray()
	for w in G.worlds: pts.append(w.pos); cols.append(Galaxy.FAC[w.owner].color)
	var m: ShaderMaterial = terr.material
	m.set_shader_parameter("pts", pts); m.set_shader_parameter("cols", cols); m.set_shader_parameter("count", G.worlds.size())
	m.set_shader_parameter("origin", terr.position)

func _ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var glass := StyleBoxFlat.new(); glass.bg_color = Color(.03, .06, .1, .78); glass.border_color = Color("6fb7d8"); glass.set_border_width_all(1)
	glass.set_corner_radius_all(4); glass.set_content_margin_all(16)
	title = Label.new(); title.text = "GALACTIC WAR MAP"; title.position = Vector2(28, 20); title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("cfe8f5")); ui.add_child(title)
	counts = RichTextLabel.new(); counts.bbcode_enabled = true; counts.fit_content = true; counts.position = Vector2(28, 60); counts.size = Vector2(420, 160)
	counts.add_theme_stylebox_override("normal", glass); ui.add_child(counts)
	info = RichTextLabel.new(); info.bbcode_enabled = true; info.fit_content = true; info.anchor_left = 1; info.anchor_right = 1
	info.offset_left = -460; info.offset_right = -24; info.offset_top = 20; info.add_theme_stylebox_override("normal", glass)
	info.add_theme_font_size_override("normal_font_size", 16); ui.add_child(info)
	hint = Label.new(); hint.anchor_top = 1; hint.anchor_bottom = 1; hint.offset_top = -40; hint.offset_left = 28
	hint.add_theme_font_size_override("font_size", 16); hint.modulate = Color(1, 1, 1, .8); ui.add_child(hint)

func _hex(c: Color) -> String: return c.to_html(false)

func _refresh() -> void:
	var t := "[b]%d worlds[/b]\n" % G.worlds.size()
	for f in Galaxy.ORDER + ["neutral"]:
		var mark := "  (you)" if f == Game.player_faction else ""
		t += "[color=#%s]■[/color] %s  %d%s\n" % [_hex(Galaxy.FAC[f].color), Galaxy.FAC[f].name, G.count(f), mark]
	counts.text = t
	if sel >= 0: info.text = _describe(sel)
	var pad := Game.using_pad
	hint.text = ("Left stick select   Right stick pan   L2 / R2 zoom   L1 / R1 capitals   Cross drop in   Options menu" if pad
		else "Click select   Drag or WASD pan   Wheel zoom   Q / E capitals   Enter or double-click drop in   Esc menu")
	queue_redraw()

func _describe(i: int) -> String:
	var w: Dictionary = G.worlds[i]; var f: Dictionary = Galaxy.FAC[w.owner]
	var t := "[font_size=24][b]%s[/b][/font_size]\n" % w.name
	t += "[color=#%s]%s[/color]%s\n" % [_hex(f.color), f.name, "  ·  capital" if w.cap else ""]
	t += "%s  ·  Resistance: %s\n" % [Galaxy.BIOMES[w.biome].name, Galaxy.RES[w.res]]
	var sec: Dictionary = G.sectors[w.sector]
	t += "\n[b]Sector:[/b] %s\nHold every world in it: [i]%s[/i]. %s\n" % [sec.name, sec.pu, sec.desc]
	if w.boost != "":
		var b: Dictionary = Galaxy.BOOSTERS[w.boost]
		t += "\n[b]Booster:[/b] %s. %s\n" % [b.name, b.desc]
	if not w.cities.is_empty():
		t += "\n[b]Cities[/b]\n"
		for c in w.cities:
			var pu: Dictionary = Galaxy.CITY_PU[c.pu]
			t += "%s: %s. %s\n" % [c.size.capitalize(), pu.name, pu.me]
	t += "\n"
	if w.owner == "neutral":
		var hm: Dictionary = Game.hearts(i)
		t += "[b]Hearts and minds[/b]\nYou %d%%   ·   %s %d%%\nWin the population over with events. %s to see them.\n" % [hm.me, Galaxy.FAC[w.foe].name, hm.foe, Game.prompt("roll") if Game.using_pad else "Enter"]
	elif w.owner == Game.player_faction:
		t += "Held by you. Drop in to defend it against the %s.\n" % Galaxy.FAC[G.foe_of(i, Game.player_faction)].name
	else:
		t += "Drop in to fight the %s here.\n" % f.name
	return t

func _draw() -> void:
	var z := cam.zoom.x if cam else .42
	for s in stars: draw_circle(s[0], s[1] / max(z, .3), Color(1, 1, 1, s[2] * .5))
	var front := Color(1, .35, .3, .55); var lane := Color(.6, .75, .9, .22)
	for l in G.lanes:
		var a: Dictionary = G.worlds[l[0]]; var b: Dictionary = G.worlds[l[1]]
		var hostile: bool = a.owner != b.owner and a.owner != "neutral" and b.owner != "neutral"
		draw_line(a.pos, b.pos, front if hostile else lane, (2.2 if hostile else 1.4) / z)
	var font := ThemeDB.fallback_font
	for w in G.worlds:
		var c: Color = Galaxy.FAC[w.owner].color
		var rad: float = (14.0 if w.cap else 8.0) / sqrt(z) * .6
		draw_circle(w.pos, rad + 2.0 / z, Color(0, 0, 0, .6))
		draw_circle(w.pos, rad, c)
		if w.cap: draw_arc(w.pos, rad + 6.0 / z, 0, TAU, 40, c, 2.0 / z)
		if w.boost != "": _diamond(w.pos + Vector2(rad + 5.0 / z, -rad - 5.0 / z), 5.0 / z, Color("ffd34d"))
		for k in w.cities.size(): draw_circle(w.pos + Vector2(-rad + k * 5.0 / z, rad + 6.0 / z), 1.8 / z, Color(1, 1, 1, .8))
		if w.cap or z > .85 or w.id == sel:
			var fs := int(14.0 / z) if z < 1.0 else 14
			draw_string(font, w.pos + Vector2(rad + 6.0 / z, 4.0 / z), w.name, HORIZONTAL_ALIGNMENT_LEFT, -1, max(8, fs), Color(1, 1, 1, .92))
	if sel >= 0:
		var p: Vector2 = G.worlds[sel].pos
		draw_arc(p, 26.0 / z * .6, 0, TAU, 48, Color("ffe08a"), 2.5 / z)
	if Game.using_pad: draw_arc(cursor, 8.0 / z, 0, TAU, 24, Color(1, 1, 1, .7), 1.5 / z)

func _diamond(p: Vector2, s: float, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), c)

func _nearest(p: Vector2, within: float) -> int:
	var best := -1; var bd := within
	for w in G.worlds:
		var d: float = (w.pos as Vector2).distance_to(p)
		if d < bd: bd = d; best = w.id
	return best

func select(i: int) -> void:
	if i < 0: return
	sel = i; cursor = G.worlds[i].pos; _refresh()

func drop_in() -> void:
	if sel < 0: return
	if G.worlds[sel].owner == "neutral": Game.open_events(sel)
	else: Game.deploy(sel)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: _zoom(1.12)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: _zoom(1 / 1.12)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			var i := _nearest(get_global_mouse_position(), 40.0 / cam.zoom.x)
			if i >= 0:
				if ev.double_click and i == sel: drop_in()
				else: select(i)
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		cam.position -= ev.relative / cam.zoom.x
	elif ev.is_action_pressed("roll") and Game.using_pad: drop_in()
	elif ev is InputEventKey and ev.pressed and (ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER): drop_in()
	elif ev.is_action_pressed("barrage") or (ev is InputEventKey and ev.pressed and ev.keycode == KEY_Q): _cycle(-1)
	elif ev.is_action_pressed("grenade") or (ev is InputEventKey and ev.pressed and ev.keycode == KEY_E): _cycle(1)

func _cycle(d: int) -> void:
	cap_cycle = wrapi(cap_cycle + d, 0, Galaxy.ORDER.size())
	select(G.capitals[Galaxy.ORDER[cap_cycle]])

func _zoom(f: float) -> void:
	cam.zoom = (cam.zoom * f).clamp(Vector2(.3, .3), Vector2(2.2, 2.2)); queue_redraw()

func _process(dt: float) -> void:
	if Game.test_mode: _test(dt)
	# keyboard pan, pad cursor and pan, trigger zoom
	var pan := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var look := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if Game.using_pad:
		if pan.length() > .2:
			cursor += pan * 520.0 * dt / cam.zoom.x
			var i := _nearest(cursor, 70.0 / cam.zoom.x)
			if i >= 0 and i != sel: sel = i; _refresh()
			cam.position = cam.position.lerp(cursor, min(1.0, dt * 3.0)); queue_redraw()
		if look.length() > .2: cam.position += look * 700.0 * dt / cam.zoom.x
	elif pan.length() > .1: cam.position += pan * 700.0 * dt / cam.zoom.x
	var zi := Input.get_action_strength("fire") - Input.get_action_strength("steady")
	if Game.using_pad and abs(zi) > .2: _zoom(1.0 + zi * dt * 1.6)

# ---- test mode: frames of the whole galaxy, a close-up, each capital, then a drop onto a neutral world ----
func _checks() -> void:
	var ok := func(name: String, pass_: bool, detail: String): print("CHECK ", "PASS " if pass_ else "FAIL ", name, "  ", detail)
	ok.call("more than 100 worlds", G.worlds.size() > 100, str(G.worlds.size()))
	var per := []
	for f in Galaxy.ORDER: per.append("%s %d" % [f, G.count(f)])
	per.append("neutral %d" % G.count("neutral"))
	ok.call("every faction holds a big section", Galaxy.ORDER.all(func(f): return G.count(f) >= 20), ", ".join(per))
	ok.call("each faction's section is one connected piece", Galaxy.ORDER.all(func(f): return G.components_of(f).size() == 1), str(Galaxy.ORDER.map(func(f): return G.components_of(f).size())))
	var seen := {0: true}; var stack := [0]
	while not stack.is_empty():
		var c: int = stack.pop_back()
		for n in G.neighbours(c):
			if not seen.has(n): seen[n] = true; stack.append(n)
	ok.call("one lane network reaches every world", seen.size() == G.worlds.size(), "%d of %d" % [seen.size(), G.worlds.size()])
	var names := {}
	for w in G.worlds: names[w.name] = true
	ok.call("world names are unique", names.size() == G.worlds.size(), "%d unique" % names.size())
	ok.call("four capitals, each in its own section", Galaxy.ORDER.all(func(f): return G.worlds[G.capitals[f]].home == f and G.worlds[G.capitals[f]].cap), str(G.capitals.values().map(func(i): return G.worlds[i].name)))
	ok.call("unclaimed worlds carry boosters", G.worlds.filter(func(w): return w.boost != "").size() >= 8, str(G.worlds.filter(func(w): return w.boost != "").size()))
	ok.call("every world sits in a sector", G.worlds.all(func(w): return w.sector >= 0), "%d sectors" % G.sectors.size())
	var demo := 0
	for f in Galaxy.NAMED:
		for nm in Galaxy.NAMED[f]: demo += 1 if G.worlds.any(func(w): return w.name == nm and w.home == f) else 0
	ok.call("the 24 demo worlds keep their names and factions", demo == 24, "%d of 24" % demo)
	var g2 := Galaxy.new(); g2.generate(Game.GALAXY_SEED)
	ok.call("the same seed builds the same galaxy", g2.worlds.size() == G.worlds.size() and g2.worlds.all(func(w): return w.name == G.worlds[w.id].name and w.pos == G.worlds[w.id].pos), "")

func _test(dt: float) -> void:
	if test_t == 0.0: _checks()
	test_t += dt
	var shots := {0.6: "galaxy_full", 1.2: "galaxy_close", 1.8: "galaxy_neutral"}
	for at in shots:
		if test_t - dt < at and test_t >= at:
			get_viewport().get_texture().get_image().save_png("user://t_%s.png" % shots[at])
			if at == 0.6:
				cam.zoom = Vector2(1.0, 1.0); cam.position = G.worlds[G.capitals["concord"]].pos; select(G.capitals["concord"])
			if at == 1.2:
				var n := -1
				for w in G.worlds:
					if w.owner == "neutral" and w.boost != "": n = w.id; break
				cam.zoom = Vector2(.8, .8); cam.position = G.worlds[n].pos; select(n)
	if test_t > 2.0 and test_t - dt <= 2.0: drop_in()
