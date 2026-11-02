# Starfall Vanguard: the events hall of an unclaimed world. The population will side with whoever wins them over, so
# instead of a battle there is a festival: three events on offer at a time, each against the faction raiding the world.
# Wins fill your side of the hearts-and-minds meter; losses fill the rival's. At 100 the world changes hands.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node

var wid := -1
var w: Dictionary
var ui: CanvasLayer; var box: VBoxContainer; var lbl_head: RichTextLabel; var bar_me: ProgressBar; var bar_foe: ProgressBar
var lbl_result: Label; var cards: VBoxContainer
var game: MiniGame
var bg: ColorRect
var test_queue: Array = []; var test_log: Array = []

func _ready() -> void:
	wid = Game.current_world
	if wid < 0 or Game.galaxy.worlds[wid].owner != "neutral":         # opened directly: pick the first unclaimed world
		for x in Game.galaxy.worlds:
			if x.owner == "neutral": wid = x.id; break
		Game.current_world = wid
	w = Game.galaxy.worlds[wid]
	_ui(); _refresh("")
	if Game.test_mode:
		Engine.time_scale = 3.0
		test_queue = Game.EVENTS.keys()
		get_tree().create_timer(.5).timeout.connect(_test_next)

func _ui() -> void:
	bg = ColorRect.new(); bg.color = Color("070b12"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = CanvasLayer.new(); add_child(ui); ui.add_child(bg)
	var glass := StyleBoxFlat.new(); glass.bg_color = Color(.03, .06, .1, .9); glass.border_color = Color("6fb7d8"); glass.set_border_width_all(1)
	glass.set_corner_radius_all(6); glass.set_content_margin_all(24)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", glass); panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 0); panel.position = Vector2(-450, -390); ui.add_child(panel)
	box = VBoxContainer.new(); box.add_theme_constant_override("separation", 12); panel.add_child(box)
	lbl_head = RichTextLabel.new(); lbl_head.bbcode_enabled = true; lbl_head.fit_content = true; box.add_child(lbl_head)
	for pair in [["You", Galaxy.FAC[Game.player_faction].color], [Galaxy.FAC[w.foe].name, Galaxy.FAC[w.foe].color]]:
		var row := HBoxContainer.new(); box.add_child(row)
		var l := Label.new(); l.text = pair[0]; l.custom_minimum_size = Vector2(220, 0); row.add_child(l)
		var b := ProgressBar.new(); b.max_value = 100; b.custom_minimum_size = Vector2(600, 22); b.show_percentage = true; row.add_child(b)
		var fill := StyleBoxFlat.new(); fill.bg_color = pair[1]; b.add_theme_stylebox_override("fill", fill)
		if bar_me == null: bar_me = b
		else: bar_foe = b
	lbl_result = Label.new(); lbl_result.add_theme_font_size_override("font_size", 20); lbl_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(lbl_result)
	cards = VBoxContainer.new(); cards.add_theme_constant_override("separation", 8); box.add_child(cards)

func _refresh(result: String) -> void:
	var h := Game.hearts(wid)
	var boost := ""
	if w.boost != "": boost = "\nWhoever wins it over gets its [b]%s[/b]: %s" % [Galaxy.BOOSTERS[w.boost].name, Galaxy.BOOSTERS[w.boost].desc]
	lbl_head.text = "[font_size=30][b]%s[/b][/font_size]   %s, unclaimed\nThe %s are working the crowds here. Win the population over in open competition.%s" % [
		w.name, Galaxy.BIOMES[w.biome].name, Galaxy.FAC[w.foe].name, boost]
	bar_me.value = h.me; bar_foe.value = h.foe
	lbl_result.text = result
	for c in cards.get_children(): c.queue_free()
	var first: Button = null
	if w.owner == "neutral":
		for key in Game.event_card(wid):
			var e: Dictionary = Game.EVENTS[key]
			var b := Button.new(); b.text = "%s\n%s" % [e.name, e.blurb]; b.custom_minimum_size = Vector2(0, 64); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func(): play(key)); cards.add_child(b)
			if first == null: first = b
	var back := Button.new(); back.text = "Back to the galaxy map"; back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/galaxy.tscn")); cards.add_child(back)
	(first if first else back).call_deferred("grab_focus")

func play(key: String) -> void:
	ui.visible = false
	game = load(Game.EVENTS[key].script).new()
	game.setup(w.foe, w.biome, w.name)
	game.finished.connect(func(won, summary): _done(key, won, summary))
	add_child(game)
	if Game.test_mode: get_tree().create_timer(5.0).timeout.connect(_snap.bind(key))

func _snap(key: String) -> void:
	if is_instance_valid(game): get_viewport().get_texture().get_image().save_png("user://t_ev_%s.png" % key)

func _done(key: String, won: bool, summary: String) -> void:
	game.queue_free(); game = null; ui.visible = true
	var flip := Game.apply_event(wid, won)
	var res := "%s: %s %s" % [Game.EVENTS[key].name, "won." if won else "lost.", summary]
	if flip != "": res += "\n\n" + flip
	_refresh(res)
	if Game.test_mode:
		var h := Game.hearts(wid)
		test_log.append([key, won, summary, int(h.me), int(h.foe), w.owner])
		print("EVENT ", key, " won=", won, " | ", summary, " | hearts ", h.me, "/", h.foe, " owner ", w.owner)
		get_tree().create_timer(.6).timeout.connect(_test_next)

# ---- the controller: Cross picks a card (buttons take focus), Circle goes back to the map ----
func _unhandled_input(ev: InputEvent) -> void:
	if game: return
	if ev.is_action_pressed("roll") and Game.using_pad:
		var f := get_viewport().gui_get_focus_owner()
		if f is Button: (f as Button).pressed.emit()
	elif ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("crouch"):
		get_tree().change_scene_to_file("res://scenes/galaxy.tscn")

# ---- test mode: every event, played by the autopilot at three times speed ----
func _test_next() -> void:
	if test_queue.is_empty():
		get_viewport().get_texture().get_image().save_png("user://t_ev_hall.png")
		var all_done := test_log.size() == Game.EVENTS.size()
		print("CHECK ", "PASS " if all_done else "FAIL ", "every event runs to a result  ", test_log.size(), " of ", Game.EVENTS.size())
		var wins := test_log.filter(func(x): return x[1]).size()
		print("CHECK ", "PASS " if wins > 0 else "FAIL ", "the autopilot can win events  ", wins, " won")
		var moved: bool = test_log.size() > 0 and (test_log[-1][3] > 0 or test_log[-1][4] > 10)
		print("CHECK ", "PASS " if moved else "FAIL ", "results move the hearts meter")
		print("RESULT owner ", w.owner)
		Engine.time_scale = 1.0
		get_tree().quit(); return
	if w.owner != "neutral":                         # the world has changed hands; reset it so every event still gets played
		print("FLIP ", w.name, " -> ", w.owner); w.owner = "neutral"; Game.hm.erase(str(wid)); _refresh("")
	play(test_queue.pop_front())
