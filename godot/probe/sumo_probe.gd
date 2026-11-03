# Test probe (not part of the game): plays Cargo Sumo many times with the autopilot and reports how long it lasts.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends Node
var runs := 0; var res := []; var g: MiniGame; var mode := "auto"
func _ready() -> void:
	mode = "idle" if "--idle" in OS.get_cmdline_user_args() else "auto"
	Engine.max_fps = 0; _next()
func _next() -> void:
	if runs >= 12:
		var wins := res.filter(func(r): return r[0]).size()
		var ts := res.map(func(r): return r[1]); ts.sort()
		print("SUMO ", mode, " wins ", wins, " of ", runs, " durations ", ts); get_tree().quit(); return
	runs += 1
	g = load("res://scripts/games/sumo.gd").new(); g.setup("swarm", "moon", ["Pyrrhos", "Tamsin Shoal", "Sable Moon", "Prism Fields", "Ninefold Ring", "Yrorn"][runs % 6] + str(runs))
	if mode == "idle": g.autopilot = false
	g.finished.connect(func(won, s): res.append([won, snappedf(g.t, .1)]); g.queue_free(); call_deferred("_next"))
	add_child(g)
