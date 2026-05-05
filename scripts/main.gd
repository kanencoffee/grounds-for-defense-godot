extends Node2D
# Grounds for Defense — Godot 4 port
# Single-file game logic. All entities created programmatically — no .tscn for towers/enemies needed.

const W := 1280
const H := 800

# ============== DEFINITIONS ==============
const TOWER_DEFS = {
	"eye":      {"name":"SHERLOCK BEANS",  "cost":50,  "range":180, "dmg":6,  "fire_rate":0.22, "sprite":"tower-eye.svg",    "specialty":"visual",    "blurb":"Visual inspection. Color card + magnifier. ★ Catches OVER-ROASTED, mold, foreign matter."},
	"tongue":   {"name":"TASTE-MASTER",    "cost":150, "range":320, "dmg":60, "fire_rate":1.8,  "sprite":"tower-tongue.svg", "specialty":"taste",     "blurb":"Cupping station — SCA slurp protocol. Slow charge, line damage. ★ Catches REHEATED MILK, UNDER-EXTRACTED.", "charge":1.5, "pierce":true},
	"date":     {"name":"FATHER TIME",     "cost":75,  "range":190, "dmg":0,  "fire_rate":1.2,  "sprite":"tower-date.svg",   "specialty":"date",      "blurb":"Date stamp / lot tracker. Freezes expired lots mid-march. No damage, pure CC. ★ Catches STALE LOTS, POD-ZILLA.", "root":2.0},
	"nose":     {"name":"NOSE GOES",       "cost":100, "range":180, "dmg":0,  "fire_rate":0.0,  "sprite":"tower-nose.svg",   "specialty":"aroma",     "blurb":"Aroma station. Sniffs out rancidity in radius — slows everything. ★ Catches PRE-GROUND, STALE.", "slow":0.55, "aura":true},
}

const ENEMY_DEFS = {
	"disciple":   {"hp":30,  "speed":52, "sprite":"enemy-disciple.svg",   "bounty":5,   "size":100,
		"name":"SIR STALES-A-LOT",  "defect":"date",
		"fail":"Roasted 2 years ago. SCA freshness window: 4 weeks.",
		"intro":"DEFECT: STALE. CO₂ + volatile aromatics dissipate after roasting. Past 4 weeks → 50% aroma loss. CATCH WITH: Father Time ✓, Nose Goes ✓"},
	"evangelist": {"hp":20,  "speed":100,"sprite":"enemy-evangelist.svg", "bounty":8,   "size":100,
		"name":"GRIND ZERO",        "defect":"aroma",
		"fail":"Pre-ground. Surface area 10,000× higher → oxidizes in HOURS.",
		"intro":"DEFECT: PRE-GROUND. Coffee should be ground RIGHT BEFORE brewing. Bagged grounds are stale before you open them. CATCH WITH: Nose Goes ✓, Sherlock Beans ✓",
		"slow_immune":3.0},
	"demon":      {"hp":140, "speed":30, "sprite":"enemy-demon.svg",      "bounty":22,  "size":120,
		"name":"SKIN-DEEP MILK",    "defect":"taste",
		"fail":"Steamed 3×. Proteins denatured >70°C → that crusty skin on top.",
		"intro":"DEFECT: REHEATED DAIRY. Milk can only be steamed ONCE — second heat denatures proteins, scorches lactose. Tanky. CATCH WITH: Taste-Master ✓"},
	"wraith":     {"hp":80,  "speed":56, "sprite":"enemy-wraith.svg",     "bounty":15,  "size":110,
		"name":"BURNY McBURNFACE",  "defect":"visual",
		"fail":"Agtron color: 18 (target ~55). Roasted past 2nd crack — carbonized.",
		"intro":"DEFECT: OVER-ROASTED. Internal temp blew past 240°C. Origin character incinerated. Bitter + ashy. The dead giveaway: color. CATCH WITH: Sherlock Beans ✓"},
	"zealot":     {"hp":50,  "speed":68, "sprite":"enemy-zealot.svg",     "bounty":10,  "size":100,
		"name":"MR. WISHY-WASHY",   "defect":"taste",
		"fail":"TDS 0.5% (target 1.15-1.35%). Ratio 1:30 (target 1:15-18).",
		"intro":"DEFECT: UNDER-EXTRACTED. Brew ratio way off. Sour, weak, no body — basically brown water. CATCH WITH: Taste-Master ✓"},
	"baron":      {"hp":600, "speed":36, "sprite":"enemy-baron.svg",      "bounty":250, "size":180,
		"name":"POD-ZILLA",         "defect":"compound",
		"fail":"Pre-ground + sealed 18mo + foil + plastic + microplastics.",
		"intro":"BOSS: POD-ZILLA. Compound defect — stale + pre-ground + plastic taint at once. Heavily armored. ALL QC tools work, but at reduced bonus. Bring everything.",
		"regen":5, "armor":0.25},
}

# Track which enemy types have already been introduced this session
var enemies_seen: Dictionary = {}

# Specialty matching: defense.specialty matches enemy.defect → bonus damage + visual feedback
const MATCH_BONUS := 2.0
const MISMATCH_PENALTY := 0.6  # wrong tool — does some damage, but reduced

# Path waypoints (zigzag) — bigger viewport so enemies are clearly visible
const PATH_PTS = [
	Vector2(-40, 180), Vector2(330, 180), Vector2(330, 380),
	Vector2(680, 380), Vector2(680, 200), Vector2(1030, 200),
	Vector2(1030, 560), Vector2(220, 560), Vector2(220, 700),
	Vector2(1320, 700)
]

const SLOTS = [
	Vector2(220, 110), Vector2(220, 260),
	Vector2(430, 310), Vector2(580, 310),
	Vector2(770, 110), Vector2(770, 280),
	Vector2(930, 110), Vector2(1130, 320),
	Vector2(1130, 500), Vector2(870, 640),
	Vector2(530, 640), Vector2(330, 640),
]

const WAVE_PLAN = [
	[ {"type":"disciple", "count":8,  "gap":0.8, "delay":0.0} ],
	[ {"type":"disciple", "count":12, "gap":0.6, "delay":0.0} ],
	[ {"type":"disciple", "count":10, "gap":0.5, "delay":0.0}, {"type":"evangelist", "count":4, "gap":0.7, "delay":6.0} ],
	[ {"type":"evangelist","count":10,"gap":0.5, "delay":0.0}, {"type":"zealot",     "count":3, "gap":1.2, "delay":3.0} ],
	[ {"type":"wraith",   "count":4,  "gap":1.0, "delay":0.0}, {"type":"demon",      "count":1, "gap":0.0, "delay":5.0} ],
	[ {"type":"evangelist","count":12,"gap":0.4, "delay":0.0}, {"type":"wraith",     "count":3, "gap":1.2, "delay":3.0} ],
	[ {"type":"demon",    "count":3,  "gap":3.5, "delay":0.0}, {"type":"zealot",     "count":6, "gap":0.6, "delay":1.5}, {"type":"wraith", "count":3, "gap":1.5, "delay":8.0} ],
	[ {"type":"disciple", "count":18, "gap":0.35,"delay":0.0}, {"type":"zealot",     "count":5, "gap":0.5, "delay":2.0}, {"type":"wraith", "count":2, "gap":2.0, "delay":6.0} ],
	[ {"type":"evangelist","count":14,"gap":0.28,"delay":0.0}, {"type":"demon",      "count":4, "gap":2.5, "delay":1.0}, {"type":"zealot", "count":8, "gap":0.5, "delay":8.0} ],
	[ {"type":"baron",    "count":1,  "gap":0.0, "delay":0.0}, {"type":"demon",      "count":3, "gap":2.5, "delay":5.0}, {"type":"wraith", "count":4, "gap":1.5, "delay":7.0}, {"type":"evangelist","count":12,"gap":0.4,"delay":11.0} ],
]

# ============== STATE ==============
var beans := 250
var hp := 20
var wave_num := 0
var max_waves := WAVE_PLAN.size()
var spawning := false
var wave_active := false
var game_over := false

var enemies: Array = []
var towers: Array = []
var slot_nodes: Array = []
var slot_taken: Array = []
var path_curve: Curve2D
var path_length: float = 0.0
var pending_slot := -1

# textures cache
var textures := {}

# UI nodes
var beans_label: Label
var wave_label: Label
var hp_label: Label
var start_btn: Button
var picker_panel: PanelContainer
var info_label: Label

# perfect shot
var perfect_ready := true
var perfect_armed := false
var perfect_cd := 0.0

func _ready():
	get_tree().root.title = "Grounds for Defense"
	_load_textures()
	_build_path()
	_build_barista()
	_build_slots()
	_build_hud()
	_show_briefing()

var briefing_pages: Array = []
var briefing_idx: int = 0
var briefing_layer: CanvasLayer

func _show_briefing():
	# Build the page list
	briefing_pages = [
		{
			"kind": "intro",
			"title": "GROUNDS FOR DEFENSE",
			"subtitle": "Q GRADER ORIENTATION",
			"body": "Welcome to The Last Drop, Q Grader.\n\nBad coffee is marching toward your customer. Every defect coming down the line is real — recognized by the Specialty Coffee Association.\n\nYour job: spot the defect, deploy the right inspection tool, fail it before it reaches the cup.\n\nThe next pages introduce the threats and your tools.\nClick NEXT to meet them, or SKIP if you already know the drill."
		},
		{ "kind":"section", "title":"THE DEFECTS", "subtitle":"Six real coffee quality failures" }
	]
	# Add each enemy as its own page (in spawn order)
	var enemy_order = ["disciple", "evangelist", "wraith", "zealot", "demon", "baron"]
	for k in enemy_order:
		if ENEMY_DEFS.has(k):
			var d = ENEMY_DEFS[k]
			briefing_pages.append({
				"kind": "enemy",
				"key": k,
				"name": d.name,
				"defect_type": d.defect,
				"fail": d.fail,
				"intro": d.intro,
				"sprite": d.sprite,
				"is_boss": k == "baron"
			})
	briefing_pages.append({ "kind":"section", "title":"YOUR Q GRADER KIT", "subtitle":"Four tools. Each catches specific defects." })
	# Add each tower as its own page
	var tower_order = ["eye", "date", "nose", "tongue"]
	for k in tower_order:
		if TOWER_DEFS.has(k):
			var d = TOWER_DEFS[k]
			briefing_pages.append({
				"kind": "tower",
				"key": k,
				"name": d.name,
				"specialty": d.specialty,
				"cost": d.cost,
				"blurb": d.blurb,
				"sprite": d.sprite
			})
	briefing_pages.append({
		"kind": "ready",
		"title": "READY, Q GRADER?",
		"body": "★ Right tool → 2× damage + ✓ DEFECT CAUGHT\n✗ Wrong tool → 0.6× damage + ✗ WRONG TOOL\n☆ Pod-zilla (boss) → all tools apply at 1.3×\n\nClick empty slot → place tool.\nClick placed tool → sell (60% refund).\nPress P + click enemy → Perfect Cupping Shot.\n\nHit 'Start Wave' (top right) when you're ready."
	})
	briefing_idx = 0
	_build_briefing_ui()
	_render_briefing_page()

func _build_briefing_ui():
	if briefing_layer and is_instance_valid(briefing_layer):
		briefing_layer.queue_free()
	briefing_layer = CanvasLayer.new()
	briefing_layer.layer = 100
	add_child(briefing_layer)
	# Full-screen darken
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.size = Vector2(W, H)
	briefing_layer.add_child(dim)
	# Card panel (centered)
	var card = PanelContainer.new()
	card.name = "Card"
	card.size = Vector2(720, 620)
	card.position = Vector2((W - 720)/2, (H - 620)/2)
	briefing_layer.add_child(card)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(0.94, 0.79, 0.53)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", sb)
	# Vertical layout
	var v = VBoxContainer.new()
	v.name = "Content"
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	# Page indicator at top right
	var page_lbl = Label.new()
	page_lbl.name = "PageIndicator"
	page_lbl.add_theme_font_size_override("font_size", 12)
	page_lbl.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53, 0.6))
	page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(page_lbl)
	# Sprite container
	var sprite_box = CenterContainer.new()
	sprite_box.name = "SpriteBox"
	sprite_box.custom_minimum_size = Vector2(0, 220)
	v.add_child(sprite_box)
	# Title
	var title = Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	# Type badge
	var badge = Label.new()
	badge.name = "Badge"
	badge.add_theme_font_size_override("font_size", 16)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(badge)
	# Body text
	var body = RichTextLabel.new()
	body.name = "Body"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_font_size_override("normal_font_size", 17)
	body.custom_minimum_size = Vector2(0, 180)
	v.add_child(body)
	# spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	# Buttons row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	v.add_child(btn_row)
	var prev_btn = Button.new()
	prev_btn.name = "PrevBtn"
	prev_btn.text = "◀  Previous"
	prev_btn.add_theme_font_size_override("font_size", 16)
	prev_btn.custom_minimum_size = Vector2(140, 44)
	prev_btn.pressed.connect(_briefing_prev)
	btn_row.add_child(prev_btn)
	var skip_btn = Button.new()
	skip_btn.text = "Skip All"
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.custom_minimum_size = Vector2(100, 44)
	skip_btn.pressed.connect(_briefing_skip)
	btn_row.add_child(skip_btn)
	var next_btn = Button.new()
	next_btn.name = "NextBtn"
	next_btn.text = "Next  ▶"
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.custom_minimum_size = Vector2(160, 44)
	next_btn.pressed.connect(_briefing_next)
	btn_row.add_child(next_btn)

func _render_briefing_page():
	if not is_instance_valid(briefing_layer): return
	var card = briefing_layer.get_node("Card")
	var page_lbl = card.get_node("Content/PageIndicator")
	var sprite_box = card.get_node("Content/SpriteBox")
	var title_lbl = card.get_node("Content/Title")
	var badge_lbl = card.get_node("Content/Badge")
	var body = card.get_node("Content/Body")
	var prev_btn = card.get_node("Content").get_node_or_null("../").get_node_or_null("Content")
	# More robust button lookup
	var btn_row = card.get_node("Content").get_child(card.get_node("Content").get_child_count() - 1)
	var prev_b = btn_row.get_child(0)
	var next_b = btn_row.get_child(2)

	page_lbl.text = "%d / %d" % [briefing_idx + 1, briefing_pages.size()]

	# clear sprite box
	for c in sprite_box.get_children():
		c.queue_free()

	var p = briefing_pages[briefing_idx]
	var kind = p.kind

	# Set sprite
	if p.has("sprite") and textures.has(p.sprite):
		var tr = TextureRect.new()
		tr.texture = textures[p.sprite]
		tr.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var size = 200.0 if not (p.has("is_boss") and p.is_boss) else 240.0
		tr.custom_minimum_size = Vector2(size, size)
		sprite_box.add_child(tr)
		sprite_box.custom_minimum_size = Vector2(0, size + 8)
	else:
		sprite_box.custom_minimum_size = Vector2(0, 40)

	# Set title + badge + body per kind
	if kind == "intro":
		title_lbl.text = p.title
		title_lbl.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
		badge_lbl.text = p.subtitle
		badge_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
		body.text = "[center]%s[/center]" % p.body
	elif kind == "section":
		title_lbl.text = p.title
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
		badge_lbl.text = p.subtitle
		badge_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
		body.text = ""
	elif kind == "enemy":
		title_lbl.text = p.name
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		badge_lbl.text = "DEFECT TYPE: " + str(p.defect_type).to_upper() + ("   [BOSS]" if p.get("is_boss", false) else "")
		badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		body.text = "[color=#ffb088]FAIL CONDITION:[/color] %s\n\n%s" % [p.fail, p.intro]
	elif kind == "tower":
		title_lbl.text = p.name
		title_lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.7))
		badge_lbl.text = "SPECIALTY: %s   |   COST: %d¢" % [str(p.specialty).to_upper(), p.cost]
		badge_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		body.text = p.blurb
	elif kind == "ready":
		title_lbl.text = p.title
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		badge_lbl.text = ""
		body.text = "[center]%s[/center]" % p.body

	# Update buttons
	prev_b.disabled = briefing_idx == 0
	if briefing_idx == briefing_pages.size() - 1:
		next_b.text = "Begin Game ▶"
		next_b.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	else:
		next_b.text = "Next  ▶"
		next_b.remove_theme_color_override("font_color")

func _briefing_prev():
	if briefing_idx > 0:
		briefing_idx -= 1
		Sfx.play("place")
		_render_briefing_page()

func _briefing_next():
	if briefing_idx < briefing_pages.size() - 1:
		briefing_idx += 1
		Sfx.play("place")
		_render_briefing_page()
	else:
		_briefing_close()

func _briefing_skip():
	_briefing_close()

func _briefing_close():
	if is_instance_valid(briefing_layer):
		Sfx.play("waveStart")
		briefing_layer.queue_free()

func _load_textures():
	var keys = ["barista"]
	for k in TOWER_DEFS:
		keys.append(TOWER_DEFS[k].sprite)
	for k in ENEMY_DEFS:
		keys.append(ENEMY_DEFS[k].sprite)
	keys.append("barista.svg")
	for fname in keys:
		var path = "res://assets/" + (fname if fname.ends_with(".svg") else fname + ".svg")
		if not ResourceLoader.exists(path):
			path = "res://assets/" + fname + ".svg"
		var tex = load(path)
		if tex:
			textures[fname] = tex

func _build_path():
	path_curve = Curve2D.new()
	for p in PATH_PTS:
		path_curve.add_point(p)
	path_length = path_curve.get_baked_length()
	# draw the path in _draw via a child Node2D
	var path_drawer = Node2D.new()
	path_drawer.set_script(_make_path_drawer())
	path_drawer.set_meta("curve", path_curve)
	add_child(path_drawer)

func _make_path_drawer():
	var s = GDScript.new()
	s.source_code = """extends Node2D
func _draw():
	var curve = get_meta(\"curve\")
	var pts = curve.get_baked_points()
	# shadow
	for i in range(pts.size()-1):
		draw_line(pts[i], pts[i+1], Color(0.10,0.07,0.03,0.5), 44.0)
	# darker outline
	for i in range(pts.size()-1):
		draw_line(pts[i], pts[i+1], Color(0.42,0.27,0.14,1), 38.0)
	# main path
	for i in range(pts.size()-1):
		draw_line(pts[i], pts[i+1], Color(0.55,0.35,0.17,1), 32.0)
	# highlight
	for i in range(pts.size()-1):
		draw_line(pts[i], pts[i+1], Color(0.63,0.47,0.26,0.6), 2.0)
"""
	s.reload()
	return s

func _build_barista():
	var spr = Sprite2D.new()
	spr.texture = textures.get("barista.svg")
	spr.position = PATH_PTS[PATH_PTS.size()-1] + Vector2(-110, -80)
	spr.scale = Vector2(1.0, 1.0)
	add_child(spr)
	# Idle bob
	var tw = create_tween().set_loops()
	tw.tween_property(spr, "scale", Vector2(1.46,1.46), 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "scale", Vector2(1.4,1.4), 1.8).set_trans(Tween.TRANS_SINE)

func _build_slots():
	for i in SLOTS.size():
		var pos = SLOTS[i]
		var slot = _make_slot_button(i, pos)
		add_child(slot)
		slot_nodes.append(slot)
		slot_taken.append(false)

func _make_slot_button(idx: int, pos: Vector2) -> Node2D:
	var node = Node2D.new()
	node.position = pos
	node.set_meta("idx", idx)
	# circular outline
	var ring = _make_circle_drawer(28.0, Color(0.94, 0.79, 0.53, 0.7), 3.0, Color(0,0,0,0.35))
	node.add_child(ring)
	# clickable area
	var area = Area2D.new()
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	area.add_child(col)
	area.input_pickable = true
	area.input_event.connect(_on_slot_clicked.bind(idx))
	node.add_child(area)
	return node

func _make_circle_drawer(radius: float, outline: Color, width: float, fill: Color) -> Node2D:
	var n = Node2D.new()
	var s = GDScript.new()
	s.source_code = """extends Node2D
var radius := %f
var outline := Color(%f,%f,%f,%f)
var width := %f
var fill := Color(%f,%f,%f,%f)
func _draw():
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, outline, width, true)
""" % [radius, outline.r, outline.g, outline.b, outline.a, width, fill.r, fill.g, fill.b, fill.a]
	s.reload()
	n.set_script(s)
	return n

func _on_slot_clicked(_viewport, event, _shape_idx, slot_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_picker(slot_idx)

func _open_picker(slot_idx):
	if slot_taken[slot_idx]:
		# Show sell option for now (simplified)
		var t = _find_tower_at_slot(slot_idx)
		if t:
			_sell_tower(t)
		return
	pending_slot = slot_idx
	picker_panel.visible = true

func _find_tower_at_slot(idx):
	for t in towers:
		if t.get_meta("slot_idx") == idx:
			return t
	return null

func _build_hud():
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(20, 16)
	top_bar.add_theme_constant_override("separation", 24)
	canvas.add_child(top_bar)

	beans_label = _stat_label("Beans", "250")
	wave_label = _stat_label("Wave", "0 / 10")
	hp_label = _stat_label("Barista", "20")
	top_bar.add_child(beans_label.get_parent())
	top_bar.add_child(wave_label.get_parent())
	top_bar.add_child(hp_label.get_parent())

	start_btn = Button.new()
	start_btn.text = "Start Wave"
	start_btn.add_theme_color_override("font_color", Color(1,1,1))
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.custom_minimum_size = Vector2(160, 44)
	start_btn.pressed.connect(_on_start_wave)
	top_bar.add_child(start_btn)

	# tower picker (hidden by default)
	picker_panel = PanelContainer.new()
	picker_panel.position = Vector2(W/2 - 200, H/2 - 160)
	picker_panel.custom_minimum_size = Vector2(400, 320)
	picker_panel.visible = false
	canvas.add_child(picker_panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	picker_panel.add_child(vb)
	var title = Label.new()
	title.text = "DEPLOY A SENSE"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for k in TOWER_DEFS:
		var d = TOWER_DEFS[k]
		var b = Button.new()
		b.text = "%s — %d¢ — %s" % [d.name, d.cost, d.blurb]
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(380, 40)
		b.pressed.connect(_on_pick_tower.bind(k))
		vb.add_child(b)
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): picker_panel.visible = false)
	vb.add_child(cancel_btn)

	info_label = Label.new()
	info_label.position = Vector2(20, H - 40)
	info_label.text = ""
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.94,0.79,0.53))
	canvas.add_child(info_label)

func _stat_label(label_text: String, value_text: String) -> Label:
	var box = VBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.94,0.79,0.53,0.7))
	box.add_child(lbl)
	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 24)
	val.add_theme_color_override("font_color", Color(0.94,0.79,0.53))
	box.add_child(val)
	return val

func _on_pick_tower(type_key):
	if beans < TOWER_DEFS[type_key].cost:
		_flash_info("Not enough beans!")
		Sfx.play("error")
		return
	if pending_slot < 0:
		return
	beans -= TOWER_DEFS[type_key].cost
	var pos = SLOTS[pending_slot]
	var t = _build_tower(type_key, pos, pending_slot)
	towers.append(t)
	slot_taken[pending_slot] = true
	# hide the slot ring
	slot_nodes[pending_slot].visible = false
	pending_slot = -1
	picker_panel.visible = false
	Sfx.play("place")
	_update_hud()

func _build_tower(type_key, pos, slot_idx):
	var def = TOWER_DEFS[type_key]
	var node = Node2D.new()
	node.position = pos
	node.set_meta("type", type_key)
	node.set_meta("slot_idx", slot_idx)
	node.set_meta("def", def)
	node.set_meta("last_fire", 0.0)
	node.set_meta("dmg", def.dmg)
	node.set_meta("range", def.range)
	node.set_meta("fire_rate", def.fire_rate)
	# glow
	var glow = _make_circle_drawer(36.0, Color(0.94,0.79,0.53,0), 0.0, Color(0.94,0.79,0.53,0.18))
	node.add_child(glow)
	# sprite
	var spr = Sprite2D.new()
	spr.texture = textures.get(def.sprite)
	spr.scale = Vector2(1.5, 1.5)
	node.add_child(spr)
	add_child(node)
	# bob
	var tw = create_tween().set_loops()
	tw.tween_property(spr, "position:y", -3.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	return node

func _sell_tower(t):
	var def = t.get_meta("def")
	beans += int(def.cost * 0.6)
	var slot_idx = t.get_meta("slot_idx")
	slot_taken[slot_idx] = false
	slot_nodes[slot_idx].visible = true
	towers.erase(t)
	t.queue_free()
	Sfx.play("sell")
	_update_hud()
	_flash_info("Sold for %d¢" % int(def.cost * 0.6))

func _on_start_wave():
	if spawning or wave_active or game_over:
		return
	if wave_num >= max_waves:
		return
	wave_num += 1
	spawning = true
	wave_active = true
	Sfx.play("waveStart")
	var plan = WAVE_PLAN[wave_num - 1]
	var pending = plan.size()
	for group in plan:
		var g = group  # capture
		await get_tree().create_timer(g.delay).timeout
		if g.count == 1:
			_spawn_enemy(g.type)
			pending -= 1
			if pending == 0: spawning = false
		else:
			for i in g.count:
				_spawn_enemy(g.type)
				if i < g.count - 1:
					await get_tree().create_timer(g.gap).timeout
			pending -= 1
			if pending == 0: spawning = false
	_update_hud()

func _spawn_enemy(type_key):
	var def = ENEMY_DEFS[type_key]
	# First-appearance intro popup
	if not enemies_seen.has(type_key):
		enemies_seen[type_key] = true
		_show_enemy_intro(def)
	var node = Node2D.new()
	node.set_meta("type", type_key)
	node.set_meta("def", def)
	node.set_meta("hp", def.hp)
	node.set_meta("max_hp", def.hp)
	node.set_meta("speed", def.speed)
	node.set_meta("t", 0.0)
	node.set_meta("alive", true)
	node.set_meta("rooted_until", 0.0)
	node.set_meta("slow_mult", 1.0)
	node.set_meta("spawn_time", Time.get_ticks_msec()/1000.0)
	# sprite
	var spr = Sprite2D.new()
	spr.texture = textures.get(def.sprite)
	# scale so enemy is "size" pixels wide based on texture native size
	var tex_w = spr.texture.get_width() if spr.texture else 64
	var s = float(def.size) / float(tex_w)
	spr.scale = Vector2(s, s)
	node.add_child(spr)
	# hp bar
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.10,0.07,0.03)
	bar_bg.size = Vector2(def.size, 5)
	bar_bg.position = Vector2(-def.size/2.0, -def.size/2.0 - 14)
	node.add_child(bar_bg)
	var bar_fg = ColorRect.new()
	bar_fg.color = Color(1,0.33,0.27)
	bar_fg.size = Vector2(def.size, 5)
	bar_fg.position = bar_bg.position
	node.add_child(bar_fg)
	node.set_meta("hp_bar", bar_fg)
	node.set_meta("hp_bar_width", float(def.size))
	# initial position
	node.position = path_curve.get_point_position(0)
	add_child(node)
	enemies.append(node)

func _process(delta):
	if game_over:
		return
	# towers fire
	for t in towers:
		_tower_update(t, delta)
	# enemies move + auras
	var to_remove = []
	for e in enemies:
		if not e.get_meta("alive"):
			to_remove.append(e)
			continue
		_enemy_update(e, delta)
	for e in to_remove:
		enemies.erase(e)
		if is_instance_valid(e):
			e.queue_free()
	# wave clear
	if wave_active and not spawning and enemies.is_empty():
		wave_active = false
		beans += 30 + wave_num * 5
		if wave_num >= max_waves:
			_win()
		else:
			Sfx.play("waveClear")
		_update_hud()
	# perfect shot cd
	if not perfect_ready:
		perfect_cd -= delta
		if perfect_cd <= 0:
			perfect_ready = true
			_flash_info("Perfect Shot ready (press P)")

func _tower_update(t, delta):
	var def = t.get_meta("def")
	var now = Time.get_ticks_msec() / 1000.0
	var last_fire = t.get_meta("last_fire")
	# Cold Brew aura
	if def.get("aura", false):
		for e in enemies:
			if not e.get_meta("alive"):
				continue
			var d2 = t.position.distance_squared_to(e.position)
			if d2 < def.range * def.range:
				var ed = e.get_meta("def")
				var spawn_t = e.get_meta("spawn_time")
				if ed.has("slow_immune") and (now - spawn_t) < ed.slow_immune:
					continue
				e.set_meta("slow_mult", min(e.get_meta("slow_mult"), def.slow))
		return
	if now - last_fire < def.fire_rate:
		return
	var target = _find_target(t)
	if not target:
		return
	t.set_meta("last_fire", now)
	if def.get("charge", 0) > 0:
		# espresso: charge then pierce
		Sfx.play("espressoCh")
		await get_tree().create_timer(def.charge).timeout
		if not is_instance_valid(t): return
		Sfx.play("espressoF")
		_fire_pierce(t, def)
	else:
		# play tower-specific sound
		var type_key = t.get_meta("type")
		match type_key:
			"eye": Sfx.play("drip")
			"date": Sfx.play("frother")
			_: Sfx.play("drip")
		_fire_projectile(t, target, def)

func _find_target(t):
	var best = null
	var best_t = -1.0
	var def = t.get_meta("def")
	var r2 = def.range * def.range
	for e in enemies:
		if not e.get_meta("alive"):
			continue
		if t.position.distance_squared_to(e.position) > r2:
			continue
		var et = e.get_meta("t")
		if et > best_t:
			best_t = et
			best = e
	return best

func _fire_projectile(tower_node, target, def):
	var proj = ColorRect.new()
	proj.color = Color(0.96, 0.91, 0.84)
	proj.size = Vector2(10, 10)
	proj.position = tower_node.position - Vector2(5, 5)
	add_child(proj)
	var dur = max(0.08, tower_node.position.distance_to(target.position) / 600.0)
	var specialty = def.get("specialty", "")
	var tw = create_tween()
	tw.tween_property(proj, "position", target.position - Vector2(5, 5), dur)
	tw.finished.connect(func():
		proj.queue_free()
		if not is_instance_valid(target) or not target.get_meta("alive"):
			return
		if def.get("root", 0) > 0:
			# Date stamp catches stale + compound — show match feedback
			var enemy_def = target.get_meta("def")
			if specialty == "date" and (enemy_def.defect == "date" or enemy_def.defect == "compound"):
				_spawn_match_text(target.position, "✓ DEFECT CAUGHT")
			target.set_meta("rooted_until", Time.get_ticks_msec()/1000.0 + def.root)
		if def.dmg > 0:
			_damage_enemy(target, def.dmg, specialty)
	)

func _fire_pierce(tower_node, def):
	var target = _find_target(tower_node)
	if not target:
		return
	var dir = (target.position - tower_node.position).normalized()
	var end = tower_node.position + dir * (def.range + 60)
	# draw beam
	var beam = Line2D.new()
	beam.add_point(tower_node.position)
	beam.add_point(end)
	beam.width = 12.0
	beam.default_color = Color(0.85, 0.46, 0.02, 1)
	add_child(beam)
	var tw = create_tween()
	tw.tween_property(beam, "modulate:a", 0.0, 0.32)
	tw.finished.connect(func(): beam.queue_free())
	# damage everything close to the line
	var specialty = def.get("specialty", "")
	for e in enemies:
		if not e.get_meta("alive"):
			continue
		if _dist_to_segment(e.position, tower_node.position, end) < 28:
			_damage_enemy(e, def.dmg, specialty)

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var l2 = ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t = clamp((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _damage_enemy(e, d, specialty := ""):
	var def = e.get_meta("def")
	# QC matching: specialty vs defect type
	var match_label = ""
	if specialty != "" and def.has("defect"):
		var defect = def.defect
		if defect == "compound":
			# K-Pod: every check applies, but only 1.3× since it's compound
			d *= 1.3
			match_label = "✓ ONE OF MANY"
		elif specialty == defect:
			d *= MATCH_BONUS
			match_label = "✓ DEFECT CAUGHT"
		else:
			d *= MISMATCH_PENALTY
			match_label = "✗ WRONG TOOL"
	if def.has("armor"):
		d *= (1.0 - def.armor)
	var hp_now = e.get_meta("hp") - d
	e.set_meta("hp", hp_now)
	# damage number
	_spawn_damage_text(e.position, str(int(round(d))))
	if match_label != "":
		_spawn_match_text(e.position, match_label)
	if d > 0:
		Sfx.play("hit")
	# flash
	var spr = e.get_child(0)
	if spr is Sprite2D:
		spr.modulate = Color(2,2,2,1)
		var tw = create_tween()
		tw.tween_property(spr, "modulate", Color.WHITE, 0.08)
	if hp_now <= 0:
		_kill_enemy(e)

func _kill_enemy(e):
	if not e.get_meta("alive"):
		return
	e.set_meta("alive", false)
	beans += e.get_meta("def").bounty
	Sfx.play("enemyDie")
	_update_hud()
	# poof
	var poof = _make_circle_drawer(20, Color(0.94,0.79,0.53,1), 0, Color(0.94,0.79,0.53,0.4))
	poof.position = e.position
	add_child(poof)
	var tw = create_tween()
	tw.tween_property(poof, "scale", Vector2(2.5,2.5), 0.4)
	tw.parallel().tween_property(poof, "modulate:a", 0.0, 0.4)
	tw.finished.connect(func(): poof.queue_free())

func _enemy_update(e, delta):
	var def = e.get_meta("def")
	var now = Time.get_ticks_msec() / 1000.0
	var rooted = e.get_meta("rooted_until")
	# regen
	if def.has("regen"):
		var hp_now = e.get_meta("hp") + def.regen * delta
		e.set_meta("hp", min(def.hp, hp_now))
	if rooted < now:
		var slow_mult = e.get_meta("slow_mult")
		var v = (e.get_meta("speed") * slow_mult) / path_length
		e.set_meta("t", e.get_meta("t") + v * delta)
	# reset slow each frame; auras reapply
	e.set_meta("slow_mult", 1.0)
	var t_norm = e.get_meta("t")
	if t_norm >= 1.0:
		_enemy_reach_end(e)
		return
	e.position = path_curve.sample_baked(t_norm * path_length)
	# update hp bar
	var bar = e.get_meta("hp_bar")
	var frac = clamp(e.get_meta("hp") / e.get_meta("max_hp"), 0.0, 1.0)
	bar.size.x = e.get_meta("hp_bar_width") * frac

func _enemy_reach_end(e):
	hp = max(0, hp - 1)
	e.set_meta("alive", false)
	Sfx.play("reachEnd")
	_update_hud()
	if hp <= 0:
		_lose()

func _spawn_damage_text(pos, txt):
	var lbl = Label.new()
	lbl.text = txt
	lbl.position = pos + Vector2(-10, -50)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1,0.96,0.84))
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 30, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.finished.connect(func(): lbl.queue_free())

func _spawn_match_text(pos, txt):
	var lbl = Label.new()
	lbl.text = txt
	lbl.position = pos + Vector2(-50, -78)
	lbl.add_theme_font_size_override("font_size", 13)
	var col = Color(0.4, 1.0, 0.5) if txt.begins_with("✓") else Color(1.0, 0.5, 0.4)
	lbl.add_theme_color_override("font_color", col)
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 24, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.finished.connect(func(): lbl.queue_free())

func _flash_info(msg):
	info_label.text = msg
	info_label.modulate = Color(1, 0.5, 0.5, 1)
	var tw = create_tween()
	tw.tween_property(info_label, "modulate", Color(0.94,0.79,0.53,1), 1.5)

func _update_hud():
	beans_label.text = str(beans)
	wave_label.text = "%d / %d" % [wave_num, max_waves]
	hp_label.text = str(hp)
	if start_btn:
		start_btn.disabled = spawning or wave_active or game_over or wave_num >= max_waves
		start_btn.text = "Start Wave" if wave_num == 0 else ("Wave Active" if wave_active else ("Done" if wave_num >= max_waves else "Next Wave"))

func _show_message(title, body):
	# simple popup using Godot's AcceptDialog
	var dlg = AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = body
	add_child(dlg)
	dlg.popup_centered(Vector2(600, 300))

func _show_enemy_intro(def):
	# Slide-in banner at top showing the enemy's name + 1-line defect explanation
	var banner = PanelContainer.new()
	banner.position = Vector2(W/2 - 380, 80)
	banner.custom_minimum_size = Vector2(760, 130)
	banner.modulate.a = 0
	var canvas = $CanvasLayer if has_node("CanvasLayer") else null
	# attach to a top canvas if we have one, else add to scene root
	add_child(banner)
	# style
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(0.94, 0.79, 0.53)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", sb)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	banner.add_child(vb)
	# header line: DEFECT INCOMING — name + type
	var header = Label.new()
	var type_str = ("[%s]" % def.defect.to_upper()) if def.has("defect") else ""
	header.text = "⚠ DEFECT INCOMING: %s %s" % [def.name, type_str]
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	vb.add_child(header)
	# fail condition (the QC parameter that fails)
	if def.has("fail"):
		var fail_lbl = Label.new()
		fail_lbl.text = "FAIL: " + def.fail
		fail_lbl.add_theme_font_size_override("font_size", 13)
		fail_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
		fail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fail_lbl.custom_minimum_size = Vector2(720, 0)
		vb.add_child(fail_lbl)
	# intro line: educational
	var intro = Label.new()
	intro.text = def.intro
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", Color(0.94, 0.85, 0.65))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(720, 0)
	vb.add_child(intro)
	# play sound
	Sfx.play("error")
	# fade in / hold / fade out
	var tw = create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.5)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): banner.queue_free())

func _win():
	game_over = true
	Sfx.play("win")
	_show_message("☕ The Counter Holds!", "You crushed the K-Pod Tyrant. The Barista lives to pull another shot.")

func _lose():
	game_over = true
	Sfx.play("lose")
	_show_message("💀 The Barista Falls", "Bad coffee overran the counter. Try again?")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		if perfect_ready:
			perfect_armed = not perfect_armed
			_flash_info("Perfect Shot " + ("ARMED — click an enemy" if perfect_armed else "disarmed"))
	if perfect_armed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var best = null
		var best_d = 60.0 * 60.0
		for e in enemies:
			if not e.get_meta("alive"): continue
			var d = e.position.distance_squared_to(click_pos)
			if d < best_d:
				best_d = d
				best = e
		if best:
			Sfx.play("perfect")
			_damage_enemy(best, 500)
			perfect_armed = false
			perfect_ready = false
			perfect_cd = 45.0
