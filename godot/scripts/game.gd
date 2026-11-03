# Starfall Vanguard: shared game state, controls, factions, the Blender trooper kit and the saved state of battlefields.
# PC game. Keyboard and mouse, or a controller using the standard PlayStation 5 DualSense layout:
#   left stick move, L3 sprint, right stick aim, R2 fire, L2 steady aim, R1 grenade, L1 artillery call-in,
#   Cross dive (vault or climb when something is in the way), Circle crouch, Square reload, Options pause.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node

const FACTIONS := {
	"reach": {"name": "Free Reach", "base": Color("ef8f3a"), "trim": Color("6e3610"), "acc": Color("ffd6a8")},
	"concord": {"name": "Sovereign Concord", "base": Color("e8e2d6"), "trim": Color("8e2a22"), "acc": Color("d4a640")},
	"compact": {"name": "Meridian Compact", "base": Color("4fa8e8"), "trim": Color("123a5c"), "acc": Color("d4ebfb")},
	"swarm": {"name": "Hollow Swarm", "base": Color("4a5a3a"), "trim": Color("1c2414"), "acc": Color("a8de5c")},
	"wyrm": {"name": "Wyrm Lord", "base": Color("1d2740"), "trim": Color("0c0f17"), "acc": Color("d4a640")},
}
const GALAXY_SEED := 31
const CAMPAIGN_PATH := "user://campaign.json"
const SAVE_PATH := "user://battlefields.json"

# Prompts for each action, for the pad (PS5 glyph names) and for keyboard and mouse.
const PROMPTS := {
	"roll": ["Cross", "Space"], "crouch": ["Circle", "C"], "reload": ["Square", "R"], "grenade": ["R1", "G"],
	"barrage": ["L1", "B"], "fire": ["R2", "Left mouse"], "steady": ["L2", "Right mouse"], "sprint": ["L3", "Shift"], "pause": ["Options", "Esc"],
}

var player_faction := "concord"
var enemy_faction := "compact"
var test_mode := false          # --sv-test: the mission drives itself and saves screenshots
var fresh := false              # --sv-fresh: forget saved battle damage before starting
var kit: Node3D = null
var using_pad := false          # true while the last input came from a controller
var battlefields := {}          # map key -> {"ruins": [column ids], "craters": [[x, z, r], ...]}
var galaxy: Galaxy              # the galaxy map, regenerated from GALAXY_SEED; only ownership is saved
var current_world := -1         # the world being fought over, or -1 for the stand-alone test city

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	test_mode = "--sv-test" in args; fresh = "--sv-fresh" in args
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_keys("move_up", [KEY_W, KEY_UP]); _bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT]); _bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1); _bind_axis("move_right", JOY_AXIS_LEFT_X, 1)
	_bind_axis("move_up", JOY_AXIS_LEFT_Y, -1); _bind_axis("move_down", JOY_AXIS_LEFT_Y, 1)
	_bind_axis("aim_left", JOY_AXIS_RIGHT_X, -1); _bind_axis("aim_right", JOY_AXIS_RIGHT_X, 1)
	_bind_axis("aim_up", JOY_AXIS_RIGHT_Y, -1); _bind_axis("aim_down", JOY_AXIS_RIGHT_Y, 1)
	_bind_keys("roll", [KEY_SPACE]); _bind_pad("roll", JOY_BUTTON_A)                 # Cross
	_bind_keys("crouch", [KEY_C, KEY_CTRL]); _bind_pad("crouch", JOY_BUTTON_B)        # Circle
	_bind_keys("reload", [KEY_R]); _bind_pad("reload", JOY_BUTTON_X)                  # Square
	_bind_keys("grenade", [KEY_G]); _bind_pad("grenade", JOY_BUTTON_RIGHT_SHOULDER)   # R1
	_bind_keys("barrage", [KEY_B]); _bind_pad("barrage", JOY_BUTTON_LEFT_SHOULDER)    # L1
	_bind_keys("sprint", [KEY_SHIFT]); _bind_pad("sprint", JOY_BUTTON_LEFT_STICK)     # L3
	_bind_keys("pause", [KEY_ESCAPE]); _bind_pad("pause", JOY_BUTTON_START)           # Options
	_bind_mouse("fire", MOUSE_BUTTON_LEFT); _bind_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1)       # R2
	_bind_mouse("steady", MOUSE_BUTTON_RIGHT); _bind_axis("steady", JOY_AXIS_TRIGGER_LEFT, 1)   # L2
	_bind_keys("fullscreen", [KEY_F11])
	# menus: Cross confirms and Circle backs out, as on the console
	InputMap.action_add_event("ui_cancel", _pad_ev(JOY_BUTTON_B))
	var scene: PackedScene = load("res://assets/trooper_kit.glb")
	if scene: kit = scene.instantiate()
	_load()
	if fresh: battlefields = {}; _save()
	galaxy = Galaxy.new(); galaxy.generate(GALAXY_SEED)
	for a in args:                                   # --sv-world=N: start the mission on world N (for tests)
		if a.begins_with("--sv-world="): current_world = int(a.split("=")[1])
	if not fresh and FileAccess.file_exists(CAMPAIGN_PATH):
		var f := FileAccess.open(CAMPAIGN_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary and d.get("seed", -1) == GALAXY_SEED:
			galaxy.apply_owners(d.get("owners", {})); hm = d.get("hearts", {})
	elif fresh and FileAccess.file_exists(CAMPAIGN_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMPAIGN_PATH))

func save_campaign() -> void:
	var f := FileAccess.open(CAMPAIGN_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"seed": GALAXY_SEED, "player": player_faction, "owners": galaxy.owners(), "hearts": hm}))

# drop onto a world: the mission there fights whoever holds or raids it, on that world's ground, with its own saved damage
func deploy(i: int) -> void:
	current_world = i; enemy_faction = galaxy.foe_of(i, player_faction); say("drop_mission")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ---- hearts and minds: unclaimed worlds are won with events, not by force ----
const EVENTS := {
	"race": {"name": "Skimmer Rally", "script": "res://scripts/games/race.gd", "blurb": "Three laps of a canyon circuit in hover skimmers. Finish in the top two and ahead of the rival's ace."},
	"asteroids": {"name": "Asteroid Rush", "script": "res://scripts/games/asteroids.gd", "blurb": "A minute in a drifting ore field. Cut rocks apart and haul more ore than the rival miner."},
	"gravball": {"name": "Gravball", "script": "res://scripts/games/gravball.gd", "blurb": "Two against two in a low-gravity arena. Outscore the rival pair."},
	"rings": {"name": "Ring Run", "script": "res://scripts/games/rings.gd", "blurb": "Full throttle through a canyon of beacon rings. Beat the rival pilot's time."},
	"gala": {"name": "Marksman Gala", "script": "res://scripts/games/gala.gd", "blurb": "A shooting exhibition in the town square. Spare the civilian cut-outs and outscore the rival marksman."},
	"sumo": {"name": "Cargo Sumo", "script": "res://scripts/games/sumo.gd", "blurb": "Heavy tugs on a shrinking platform. Shove the rival's hauler off before you go over."},
}
const HEART_GAIN := {"low": 34, "med": 26, "high": 20, "fort": 16}
var hm := {}                    # world id (string) -> {"me": 0..100, "foe": 0..100, "n": events played}

func hearts(i: int) -> Dictionary:
	var k := str(i)
	if not hm.has(k): hm[k] = {"me": 0, "foe": 10, "n": 0}
	return hm[k]

# the three events on offer at a world; the line-up moves on after each one is played
func event_card(i: int) -> Array:
	var keys := EVENTS.keys(); var h := hearts(i); var out: Array = []
	for k in 3: out.append(keys[(i + int(h.n) + k * 2) % keys.size()])
	return out

# the result of one event: a win sways the crowd your way, a loss sways it to the rival. At 100 the world changes hands.
func apply_event(i: int, won: bool) -> String:
	var w: Dictionary = galaxy.worlds[i]; var h := hearts(i); var g: int = HEART_GAIN[w.res]
	h.n = int(h.n) + 1
	if won:
		h.me = min(100, int(h.me) + g); h.foe = max(0, int(h.foe) - g / 4)
	else:
		h.foe = min(100, int(h.foe) + int(g * .8))
	var flip := ""
	if int(h.me) >= 100: w.owner = player_faction; flip = "%s joins the %s." % [w.name, Galaxy.FAC[player_faction].name]
	elif int(h.foe) >= 100: w.owner = w.foe; flip = "%s sides with the %s." % [w.name, Galaxy.FAC[w.foe].name]
	save_campaign()
	return flip

func open_events(i: int) -> void:
	current_world = i; say("drop_events")
	get_tree().change_scene_to_file("res://scenes/events.tscn")

# a photographic ground texture for a biome, when one has been made (assets/ground/<biome>.jpg), or null
func ground_texture(biome: String) -> Texture2D:
	var path := "res://assets/ground/%s.jpg" % biome
	return load(path) if ResourceLoader.exists(path) else null

# ---- NINE, the ship's advisor, on the comm channel ----
var voice: AudioStreamPlayer
var said := {}                  # line -> time it was last spoken, so routine barks do not repeat every few seconds
func say(line: String, cooldown := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0 and now - said.get(line, -1e9) < cooldown: return
	var path := "res://assets/voice/nine_%s.ogg" % line
	if not ResourceLoader.exists(path): return
	if voice == null: voice = AudioStreamPlayer.new(); voice.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(voice)
	said[line] = now; voice.stream = load(path); voice.play()

func mission_key() -> String: return "world_%d" % current_world if current_world >= 0 else "city_7"
func mission_seed() -> int: return 1000 + current_world * 97 if current_world >= 0 else 7

func _action(a: String) -> void:
	if not InputMap.has_action(a): InputMap.add_action(a, .25)

func _bind_keys(a: String, keys: Array) -> void:
	_action(a)
	for k in keys: var ev := InputEventKey.new(); ev.physical_keycode = k; InputMap.action_add_event(a, ev)

func _pad_ev(b: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new(); ev.button_index = b; ev.device = -1; return ev

func _bind_pad(a: String, b: int) -> void: _action(a); InputMap.action_add_event(a, _pad_ev(b))

func _bind_axis(a: String, axis: int, dir: int) -> void:
	_action(a); var ev := InputEventJoypadMotion.new(); ev.axis = axis; ev.axis_value = dir; ev.device = -1; InputMap.action_add_event(a, ev)

func _bind_mouse(a: String, b: int) -> void:
	_action(a); var ev := InputEventMouseButton.new(); ev.button_index = b; InputMap.action_add_event(a, ev)

func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and abs(ev.axis_value) > .35):
		if not using_pad: using_pad = true; Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif ev is InputEventKey or ev is InputEventMouseButton or (ev is InputEventMouseMotion and ev.relative.length() > 3.0):
		if using_pad: using_pad = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ev.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func prompt(action: String) -> String:
	var p: Array = PROMPTS.get(action, ["?", "?"]); return p[0] if using_pad else p[1]

# controller rumble; weak is the high-frequency motor, strong the low one
func rumble(weak: float, strong: float, secs: float) -> void:
	if not using_pad: return
	for d in Input.get_connected_joypads(): Input.start_joy_vibration(d, clamp(weak, 0.0, 1.0), clamp(strong, 0.0, 1.0), secs)

# A kit part is a node group in the GLB (for example "thigh" or "torso__chest_M"); returns a fresh copy or null.
func kit_part(name: String) -> Node3D:
	if kit == null: return null
	var n := kit.find_child(name, true, false)
	if n == null: return null
	var c: Node3D = n.duplicate()
	c.transform = Transform3D.IDENTITY
	return c

# ---- battle damage that outlives a mission ----
func battlefield(key: String) -> Dictionary:
	if not battlefields.has(key): battlefields[key] = {"ruins": [], "craters": []}
	return battlefields[key]

func record_ruin(key: String, id: int) -> void:
	var b := battlefield(key)
	if not (id in b.ruins): b.ruins.append(id); _save()

func record_crater(key: String, p: Vector3, r: float) -> void:
	battlefield(key).craters.append([snappedf(p.x, .01), snappedf(p.z, .01), snappedf(r, .01)]); _save()

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(battlefields))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary: battlefields = d
