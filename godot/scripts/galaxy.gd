# Starfall Vanguard: the galaxy. A spiral disc where each of the four factions holds its own arm. A neutral deep core and
# thin borderlands between the arms hold the unclaimed worlds and their boosters. Generated the same way every time from
# one seed, so only who holds what needs saving. The 24 named worlds of the browser demo keep their names and factions.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends RefCounted
class_name Galaxy

const RADIUS := 1000.0          # galaxy radius in map units
const MIN_D := 112.0            # closest two worlds may sit
const CORE_R := 240.0           # the neutral deep core
const TWIST := .0024            # how far the arms wind (radians per unit of radius): about 135 degrees from core to rim
const BORDER := 46.0            # half-width of the neutral borderlands between arms
const ORDER := ["reach", "concord", "compact", "swarm"]

const FAC := {
	"reach": {"name": "Free Reach", "kind": "Frontier coalition", "color": Color("ef8f3a")},
	"concord": {"name": "Sovereign Concord", "kind": "Crown state", "color": Color("e14a40")},
	"compact": {"name": "Meridian Compact", "kind": "Federation", "color": Color("4fa8e8")},
	"swarm": {"name": "Hollow Swarm", "kind": "Machine hive", "color": Color("a8de5c")},
	"neutral": {"name": "Unclaimed worlds", "kind": "Neutral", "color": Color("9aa3ad")},
}
const BIOMES := {
	"desert": {"name": "Desert", "ground": Color("6b5638")}, "ice": {"name": "Glacial", "ground": Color("4f6576")},
	"jungle": {"name": "Jungle", "ground": Color("2c4a31")}, "ash": {"name": "Ashland", "ground": Color("3d3839")},
	"toxic": {"name": "Toxic marsh", "ground": Color("38422a")}, "magma": {"name": "Volcanic", "ground": Color("2b2422")},
	"forest": {"name": "Autumn forest", "ground": Color("4a3f24")}, "crystal": {"name": "Crystal plains", "ground": Color("4f4b63")},
	"mesa": {"name": "Red mesa", "ground": Color("7a4a30")}, "archipelago": {"name": "Archipelago", "ground": Color("857552")},
	"moon": {"name": "Airless moon", "ground": Color("48484d")},
}
# which ground each faction's arm tends toward
const BIOME_W := {
	"reach": {"desert": 3, "forest": 3, "archipelago": 2, "ice": 1, "jungle": 1},
	"concord": {"ash": 3, "mesa": 3, "magma": 2, "desert": 1, "toxic": 1},
	"compact": {"jungle": 3, "ice": 3, "crystal": 2, "forest": 1, "archipelago": 1},
	"swarm": {"toxic": 3, "ash": 2, "moon": 2, "magma": 2, "crystal": 1},
	"neutral": {"moon": 2, "crystal": 2, "archipelago": 2, "magma": 1, "mesa": 1, "desert": 1},
}
const RES := {"low": "Low", "med": "Moderate", "high": "High", "fort": "Fortress"}
const BOOSTERS := {
	"munitions": {"name": "Munitions works", "desc": "One spare magazine for every weapon and one more grenade."},
	"medical": {"name": "Field hospital", "desc": "Twenty more health for every trooper."},
	"relay": {"name": "Deep-space relay", "desc": "Call-ins recharge 15% faster."},
	"hangar": {"name": "Drop pod yards", "desc": "Two more reinforcements on every mission."},
	"survey": {"name": "Survey array", "desc": "15% more Requisition from every mission."},
	"battery": {"name": "Orbital battery", "desc": "One extra artillery call-in on every mission."},
	"foundry": {"name": "Armor foundry", "desc": "Your troopers take 5% less damage."},
	"listening": {"name": "Listening post", "desc": "Enemy patrols show on your map at the start of a mission."},
}
const CITY_PU := {
	"shelter": {"name": "Bunker network", "me": "You take 15% less damage on this world."},
	"uplink": {"name": "Signal tower", "me": "Your call-ins recharge 25% faster on this world."},
	"depot": {"name": "Supply depot", "me": "Two spare magazines and one more grenade on this world."},
	"clinic": {"name": "Field clinic", "me": "Your health slowly comes back on this world."},
	"militia": {"name": "Militia", "me": "Two more auxiliary troopers join you on this world."},
}
const SECTOR_PU := [
	["Veteran drop crews", "One more reinforcement, and your auxiliaries have 50% more health."],
	["Overcharged rounds", "Your whole squad deals 10% more damage."],
	["Plate forges", "Your whole squad takes 10% less damage."],
	["Fire-control net", "Call-ins recharge 20% faster and your auxiliaries fire faster."],
	["Logistics web", "Supply pods recharge 40% faster and you carry one more grenade."],
	["Pathfinder corps", "Your squad moves 8% faster."],
	["Siege doctrine", "Your explosives do 15% more damage to buildings."],
	["Medic wing", "Revived troopers come back with full health."],
]
# the browser demo's 24 worlds, by the faction section they belong to; capitals first
const NAMED := {
	"reach": ["Cairn", "Duskwell", "Brine"],
	"concord": ["Auric Throne", "Marrow", "Orrus Gate", "Glasswater", "Lowmoor", "Kharon Deep", "Aster Gulf"],
	"compact": ["Meridia Prime", "Tessaly IV", "Haldane's Rest", "Verdance", "Thule Reach"],
	"swarm": ["Vael Tor", "Kessrin", "Ostrava", "Cinder Mesa"],
	"neutral": ["Pyrrhos", "Tamsin Shoal", "Sable Moon", "Prism Fields", "Ninefold Ring"],
}
const SECTOR_NAMES := {
	"reach": ["Frontier March", "Outrider Drift", "Freehold Run", "Ember Verge"],
	"concord": ["Throne Worlds", "Legion Steppe", "Crown Marches", "Auric Reach"],
	"compact": ["Meridian Core", "Charter Belt", "Tidewater Cluster", "Northern Compact"],
	"swarm": ["Hollow Belt", "Brood Expanse", "Silent Choir", "Rust Nebula"],
}

var seed := 0
var worlds: Array = []          # {id, name, pos, home, owner, biome, res, cap, boost, foe, cities, sector}
var lanes: Array = []           # [a, b] with a < b
var sectors: Array = []         # {name, fac, worlds, pu, desc}
var capitals := {}              # faction -> world id
var rng := RandomNumberGenerator.new()

func generate(s: int) -> void:
	seed = s; rng.seed = s
	worlds.clear(); lanes.clear(); sectors.clear(); capitals.clear()
	var pts := _scatter()
	for i in pts.size():
		var p: Vector2 = pts[i]
		worlds.append({"id": i, "pos": p, "home": _section(p), "cap": false, "boost": "", "foe": "", "cities": [], "sector": -1, "name": ""})
	_capitals(); _lanes(); _knit_sections()
	for w in worlds: w.owner = w.home; w.biome = _pick(BIOME_W[w.home]); w.res = _resistance(w)
	_neutral_roles(); _sectors(); _cities(); _names()

# Poisson-disc scatter inside the disc, thinner toward the rim
func _scatter() -> Array:
	var cell := MIN_D / sqrt(2.0); var grid := {}; var out: Array = []
	var tries := 0
	while tries < 60000:
		tries += 1
		var r := RADIUS * sqrt(rng.randf()); var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * r
		if r > RADIUS * .78 and rng.randf() < (r / RADIUS - .78) * 3.0: continue      # a ragged rim, not a hard circle
		var gx := int(floor(p.x / cell)); var gy := int(floor(p.y / cell)); var ok := true
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var k := Vector2i(gx + dx, gy + dy)
				if grid.has(k) and (out[grid[k]] as Vector2).distance_to(p) < MIN_D: ok = false
		if ok: grid[Vector2i(gx, gy)] = out.size(); out.append(p)
	return out

# which faction's arm a point falls in: the angle is unwound by the spiral so the arms curve
func _arm(p: Vector2) -> float: return wrapf(p.angle() - p.length() * TWIST + PI / 4.0, 0.0, TAU)

func _section(p: Vector2) -> String:
	if p.length() < CORE_R: return "neutral"
	var a := _arm(p); var q := TAU / 4.0
	var edge: float = min(fmod(a, q), q - fmod(a, q)) * p.length()       # arc distance to the nearest arm edge
	if edge < BORDER: return "neutral"
	return ORDER[int(a / q) % 4]

func _capitals() -> void:
	for f in ORDER:
		var best := -1; var bd := 1e9; var k := ORDER.find(f)
		for w in worlds:
			if w.home != f: continue
			# the middle of the arm, two thirds of the way out
			var target := Vector2.from_angle((k + .5) * TAU / 4.0 - PI / 4.0 + 650.0 * TWIST) * 650.0
			var d: float = (w.pos as Vector2).distance_to(target)
			if d < bd: bd = d; best = w.id
		capitals[f] = best; worlds[best].cap = true

func _pick(weights: Dictionary) -> String:
	var tot := 0
	for k in weights: tot += weights[k]
	var r := rng.randi_range(1, tot)
	for k in weights:
		r -= weights[k]
		if r <= 0: return k
	return weights.keys()[0]

func _resistance(w: Dictionary) -> String:
	if w.cap: return "fort"
	if w.home == "neutral": return "high" if (w.pos as Vector2).length() < CORE_R else ["low", "med"][rng.randi() % 2]
	var d: float = (w.pos as Vector2).distance_to(worlds[capitals[w.home]].pos)
	if d < 190: return "fort" if rng.randf() < .4 else "high"
	if d < 360: return "high"
	if d < 560: return "med"
	return "low"

func _add_lane(a: int, b: int) -> void:
	var l := [min(a, b), max(a, b)]
	if a != b and not (l in lanes): lanes.append(l)

# space lanes: each world to its nearest few, then a spanning tree so the whole galaxy is one network
func _lanes() -> void:
	for w in worlds:
		var near: Array = []
		for v in worlds:
			if v.id == w.id: continue
			var d: float = (w.pos as Vector2).distance_to(v.pos)
			if d < MIN_D * 1.85: near.append([d, v.id])
		near.sort_custom(func(x, y): return x[0] < y[0])
		for k in min(3, near.size()): _add_lane(w.id, near[k][1])
	# Prim's spanning tree: the cheapest link from the network so far to each world outside it
	var n := worlds.size(); var inside := {0: true}
	var dist: Array = []; var via: Array = []
	for v in worlds: dist.append((worlds[0].pos as Vector2).distance_to(v.pos)); via.append(0)
	while inside.size() < n:
		var bi := -1; var bd := 1e18
		for i in n:
			if not inside.has(i) and dist[i] < bd: bd = dist[i]; bi = i
		inside[bi] = true; _add_lane(via[bi], bi)
		for i in n:
			if inside.has(i): continue
			var d: float = (worlds[bi].pos as Vector2).distance_to(worlds[i].pos)
			if d < dist[i]: dist[i] = d; via[i] = bi

# every faction's worlds must form one connected section: join any island to the main body of its arm
func _knit_sections() -> void:
	for f in ORDER:
		while true:
			var comps := components_of(f)
			if comps.size() <= 1: break
			comps.sort_custom(func(x, y): return x.size() > y.size())
			var best := [1e9, -1, -1]
			for a in comps[0]:
				for b in comps[1]:
					var d: float = (worlds[a].pos as Vector2).distance_to(worlds[b].pos)
					if d < best[0]: best = [d, a, b]
			_add_lane(best[1], best[2])

func neighbours(i: int) -> Array:
	var out: Array = []
	for l in lanes:
		if l[0] == i: out.append(l[1])
		elif l[1] == i: out.append(l[0])
	return out

# connected groups of one faction's home worlds, moving only along lanes between them
func components_of(f: String) -> Array:
	var seen := {}; var comps: Array = []
	for w in worlds:
		if w.home != f or seen.has(w.id): continue
		var comp: Array = []; var stack: Array = [w.id]; seen[w.id] = true
		while not stack.is_empty():
			var c: int = stack.pop_back(); comp.append(c)
			for n in neighbours(c):
				if not seen.has(n) and worlds[n].home == f: seen[n] = true; stack.append(n)
		comps.append(comp)
	return comps

func _nearest_capital(p: Vector2) -> String:
	var best := ""; var bd := 1e9
	for f in ORDER:
		var d: float = (worlds[capitals[f]].pos as Vector2).distance_to(p)
		if d < bd: bd = d; best = f
	return best

# unclaimed worlds: boosters for whoever takes them, raided by the nearest faction
func _neutral_roles() -> void:
	var keys := BOOSTERS.keys(); var k := 0
	for w in worlds:
		if w.home != "neutral": continue
		w.foe = _nearest_capital(w.pos)
		if (w.pos as Vector2).length() < CORE_R or rng.randf() < .55: w.boost = keys[k % keys.size()]; k += 1

# sectors: each arm splits four ways (inner and outer, leading and trailing side); the core and each borderland are their own
func _sectors() -> void:
	var pu_i := 0
	for f in ORDER:
		var mine: Array = worlds.filter(func(w): return w.home == f)
		var rs: Array = mine.map(func(w): return (w.pos as Vector2).length()); rs.sort()
		var rmed: float = rs[rs.size() / 2]
		var amid := (ORDER.find(f) + .5) * TAU / 4.0
		var groups := [[], [], [], []]
		for w in mine:
			var outer := 1 if (w.pos as Vector2).length() >= rmed else 0
			var side := 1 if _arm(w.pos) >= amid else 0
			groups[outer * 2 + side].append(w.id)
		for g in 4:
			if groups[g].is_empty(): continue
			var pu: Array = SECTOR_PU[pu_i % SECTOR_PU.size()]; pu_i += 1
			sectors.append({"name": SECTOR_NAMES[f][g], "fac": f, "worlds": groups[g], "pu": pu[0], "desc": pu[1]})
	var core: Array = []; var border := {}
	for w in worlds:
		if w.home != "neutral": continue
		if (w.pos as Vector2).length() < CORE_R: core.append(w.id)
		else:
			var a := _arm(w.pos); var q := TAU / 4.0; var edge := int(round(a / q)) % 4
			if not border.has(edge): border[edge] = []
			border[edge].append(w.id)
	sectors.append({"name": "Deep Core", "fac": "neutral", "worlds": core, "pu": "Core command", "desc": "Every call-in recharges 25% faster and you carry one more grenade."})
	for e in border:
		var left: String = ORDER[(e + 3) % 4]; var right: String = ORDER[e]
		var pu: Array = SECTOR_PU[pu_i % SECTOR_PU.size()]; pu_i += 1
		sectors.append({"name": "%s and %s Borderlands" % [FAC[left].name.split(" ")[-1], FAC[right].name.split(" ")[-1]], "fac": "neutral", "worlds": border[e], "pu": pu[0], "desc": pu[1]})
	for si in sectors.size():
		for id in sectors[si].worlds: worlds[id].sector = si

func _cities() -> void:
	var pus := CITY_PU.keys()
	for w in worlds:
		var n: int = {"low": rng.randi_range(0, 1), "med": 1, "high": rng.randi_range(1, 2), "fort": rng.randi_range(2, 3)}[w.res]
		var order := pus.duplicate(); order.shuffle()
		for c in n:
			var size: String = "mega" if w.cap and c == 0 else ["town", "city", "city"][rng.randi() % 3]
			w.cities.append({"size": size, "pu": order[c % order.size()]})

const SYL_A := ["Ka", "Vel", "Tor", "Ash", "Mar", "Ost", "Brev", "Hal", "Ser", "Ny", "Or", "Cael", "Dra", "Fen", "Gal", "Ith", "Jor", "Lum",
	"Mor", "Nev", "Pra", "Quel", "Ryn", "Sol", "Tal", "Ul", "Vor", "Xan", "Yr", "Zeph", "Bel", "Cor", "Eid", "Har", "Isk", "Kor", "Lyr", "Myr"]
const SYL_B := ["ra", "on", "ix", "eth", "ar", "is", "os", "um", "en", "ia", "or", "un", "ae", "yx", "ith", "ane", "ost", "ira"]
const SYL_C := ["", "", "", "", "n", "s", "th", "l", "r", "d", "x"]
const SUFFIX := [" Prime", " Minor", " II", " IV", " VII", " Gate", " Deep", " Hollow", " Station", " Rest", " Shoal", " Spire", " Drift", " Crossing"]

# names that read badly or that belong to someone else's setting are thrown away and drawn again
const BORROWED := ["breen", "hoth", "endor", "naboo", "tatooine", "jakku", "kamino", "ryloth", "lothal", "mustafar", "bespin",
	"coruscant", "dagobah", "geonosis", "kessel", "korriban", "malachor", "scarif", "jedha", "alderaan", "corellia", "vulcan", "romulus",
	"kronos", "arrakis", "caladan", "reach", "sith", "jedi", "korra"]
func _awkward(nm: String) -> bool:
	var l := nm.to_lower()
	for bad in ["thth", "hth", "xr", "xth", "xs", "xd", "xl", "xn", "yxx", "iai", "aea", "aa", "ii", "uu"]:
		if bad in l: return true
	for bad in BORROWED:
		if l.begins_with(bad) or l == bad: return true
	return false

func _names() -> void:
	var used := {}
	for f in NAMED:
		var mine: Array = worlds.filter(func(w): return w.home == f and not w.cap)
		var list: Array = NAMED[f].duplicate()
		if f != "neutral":
			worlds[capitals[f]].name = list.pop_front(); used[worlds[capitals[f]].name] = true
		for nm in list:
			if mine.is_empty(): break
			var w: Dictionary = mine.pop_at(rng.randi() % mine.size()); w.name = nm; used[nm] = true
	for w in worlds:
		if w.name != "": continue
		var nm := ""
		while nm == "" or used.has(nm):
			var b: String = SYL_B[rng.randi() % SYL_B.size()]
			var c: String = SYL_C[rng.randi() % SYL_C.size()] if b.right(1) in "aeiou" else ""
			nm = SYL_A[rng.randi() % SYL_A.size()] + b + c
			if _awkward(nm): nm = ""; continue
			if rng.randf() < .28: nm += SUFFIX[rng.randi() % SUFFIX.size()]
		w.name = nm; used[nm] = true

# ---- campaign state: who holds each world ----
func owners() -> Dictionary:
	var d := {}
	for w in worlds: d[str(w.id)] = w.owner
	return d

func apply_owners(d: Dictionary) -> void:
	for w in worlds:
		if d.has(str(w.id)): w.owner = d[str(w.id)]

func count(f: String) -> int: return worlds.filter(func(w): return w.owner == f).size()

# who is raiding an unclaimed world, competing with you for its people: the nearest faction capital that is not yours
func raider_of(i: int, me: String) -> String:
	var p: Vector2 = worlds[i].pos; var best := ""; var bd := 1e18
	for f in ORDER:
		if f == me: continue
		var d: float = (worlds[capitals[f]].pos as Vector2).distance_to(p)
		if d < bd: bd = d; best = f
	return best

# who you fight on a world: its owner, or the raiders on an unclaimed world
func foe_of(i: int, me: String) -> String:
	var w: Dictionary = worlds[i]
	if w.owner != "neutral" and w.owner != me: return w.owner
	if w.owner == "neutral": return raider_of(i, me)
	# a world you already hold: whoever borders it
	for n in neighbours(i):
		if worlds[n].owner != me and worlds[n].owner != "neutral": return worlds[n].owner
	return "swarm" if me != "swarm" else "concord"
