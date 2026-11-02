# Starfall Vanguard: the pause menu. Options or Esc opens it; Cross or Enter picks, Circle or Esc closes it.
# Works with the D-pad and left stick through Godot's focus navigation.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
extends CanvasLayer

var panel: PanelContainer; var first: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS; layer = 10
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(560, 0)
	panel.position = Vector2(-280, -230); add_child(panel)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(.04, .06, .09, .92); sb.border_color = Color("d4a640"); sb.set_border_width_all(2)
	sb.set_corner_radius_all(6); sb.set_content_margin_all(22); panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); panel.add_child(v)
	var t := Label.new(); t.text = "Paused"; t.add_theme_font_size_override("font_size", 30); v.add_child(t)
	first = _button(v, "Resume", func(): _show(false))
	_button(v, "Restart mission", func(): _show(false); get_tree().reload_current_scene())
	_button(v, "Quit to desktop", func(): get_tree().quit())
	var c := Label.new(); c.add_theme_font_size_override("font_size", 15); c.modulate = Color(1, 1, 1, .8)
	c.text = "PS5 controller: left stick move, L3 sprint, right stick aim, R2 fire, L2 steady aim,\nR1 grenade, L1 artillery, Cross dive, vault or climb, Circle crouch, Square reload, Options pause.\n\nKeyboard and mouse: WASD move, Shift sprint, mouse aim, left button fire, right button steady aim,\nG grenade, B artillery, Space dive, vault or climb, C crouch, R reload, Esc pause, F11 full screen."
	v.add_child(c)
	panel.visible = false

func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 44); b.pressed.connect(cb); parent.add_child(b); return b

func _show(on: bool) -> void:
	panel.visible = on; get_tree().paused = on
	if on: first.grab_focus()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause"): _show(not panel.visible); get_viewport().set_input_as_handled()
	elif panel.visible and ev.is_action_pressed("ui_cancel"): _show(false); get_viewport().set_input_as_handled()
