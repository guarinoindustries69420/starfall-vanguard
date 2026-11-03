# Test probe (not part of the game): plays every event once with the autopilot and prints the result, so runs at
# different frame rates can be compared. MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3).
extends Node
var keys := ["race", "asteroids", "gravball", "rings", "gala", "sumo"]; var i := 0; var g: MiniGame
func _ready() -> void: _next()
func _next() -> void:
	if i >= keys.size(): get_tree().quit(); return
	var k: String = keys[i]; i += 1
	g = load(Game.EVENTS[k].script).new(); g.setup("swarm", "desert", "Pyrrhos", "low")
	g.finished.connect(func(won, s): print("FPS ", k, " won=", won, " t=", snappedf(g.t, .1), " | ", s); g.queue_free(); call_deferred("_next"))
	add_child(g)
