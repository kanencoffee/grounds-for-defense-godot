extends Node2D
# Grounds for Defense — Godot 4 port
# Single-file game logic. All entities created programmatically — no .tscn for towers/enemies needed.

const W := 1280
const H := 800

# ============== DEFINITIONS ==============
const TOWER_DEFS = {
	"eye":      {"name":"SHERLOCK BEANS",  "cost":50,  "range":180, "dmg":6,  "fire_rate":0.22, "sprite":"tower-eye.svg",    "specialty":"visual",    "blurb":"The all-purpose detective. Always works.\n★ Best vs Burny McBurnFace (catches him 2×)."},
	"tongue":   {"name":"TASTE-MASTER",    "cost":150, "range":320, "dmg":60, "fire_rate":1.8,  "sprite":"tower-tongue.svg", "specialty":"taste",     "blurb":"The taste test. Slow but devastating.\n★ Catches Skin-Deep Milk + Mr. Wishy-Washy.", "charge":1.5, "pierce":true},
	"date":     {"name":"FATHER TIME",     "cost":75,  "range":190, "dmg":15, "fire_rate":1.2,  "sprite":"tower-date.svg",   "specialty":"date",      "blurb":"Reads roast dates. Freezes stale lots + tags them.\n★ Catches Sir Stales-A-Lot (one-shots him).", "root":2.0},
	"nose":     {"name":"NOSE GOES",       "cost":100, "range":180, "dmg":0,  "fire_rate":0.0,  "sprite":"tower-nose.svg",   "specialty":"aroma",     "blurb":"Sniffs out bad coffee in a radius. Slows everything.\n★ Catches Grind Zero.", "slow":0.55, "aura":true},
}

const ENEMY_DEFS = {
	"disciple":   {"hp":30,  "speed":52, "sprite":"enemy-disciple.svg",   "bounty":5,   "size":100,
		"name":"SIR STALES-A-LOT",  "defect":"date",
		"fail":"Roasted way too long ago. Aroma's gone.",
		"intro":"Coffee should be drunk within ~4 weeks of roasting.\n▸ Catch with FATHER TIME."},
	"evangelist": {"hp":20,  "speed":100,"sprite":"enemy-evangelist.svg", "bounty":8,   "size":100,
		"name":"GRIND ZERO",        "defect":"aroma",
		"fail":"Pre-ground. Stale before you open the bag.",
		"intro":"Always grind right before brewing. Always.\n▸ Catch with NOSE GOES.",
		"slow_immune":3.0},
	"demon":      {"hp":140, "speed":30, "sprite":"enemy-demon.svg",      "bounty":22,  "size":120,
		"name":"SKIN-DEEP MILK",    "defect":"taste",
		"fail":"Steamed twice. Look at that skin.",
		"intro":"Milk only gets steamed once. Period.\n▸ Catch with TASTE-MASTER."},
	"wraith":     {"hp":80,  "speed":56, "sprite":"enemy-wraith.svg",     "bounty":15,  "size":110,
		"name":"BURNY McBURNFACE",  "defect":"visual",
		"fail":"Roasted till it's basically charcoal.",
		"intro":"Too dark = bitter + ashy. The color tells the truth.\n▸ Catch with SHERLOCK BEANS."},
	"zealot":     {"hp":50,  "speed":68, "sprite":"enemy-zealot.svg",     "bounty":10,  "size":100,
		"name":"MR. WISHY-WASHY",   "defect":"taste",
		"fail":"Brewed weak. Basically brown water.",
		"intro":"Wrong ratio. Sour, thin, no body.\n▸ Catch with TASTE-MASTER."},
	"baron":      {"hp":600, "speed":36, "sprite":"enemy-baron.svg",      "bounty":250, "size":180,
		"name":"POD-ZILLA",         "defect":"compound",
		"fail":"Pre-ground beans, sealed 18 months in plastic.",
		"intro":"Stale + pre-ground + plastic, all at once. Armored.\n▸ Use EVERYTHING.",
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
	# Audio + cutscene need user interaction first (browser autoplay policy).
	_show_start_gate()

func _show_start_gate():
	var layer = CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.02, 1)
	bg.size = Vector2(W, H)
	layer.add_child(bg)
	# Title text
	var title = Label.new()
	title.text = "GROUNDS FOR DEFENSE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(W, 80)
	title.position = Vector2(0, H/2 - 160)
	layer.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "Defend your cup."
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(W, 30)
	subtitle.position = Vector2(0, H/2 - 90)
	layer.add_child(subtitle)
	# Big play button
	var btn = Button.new()
	btn.text = "▶ TAP TO BEGIN"
	btn.add_theme_font_size_override("font_size", 28)
	btn.size = Vector2(400, 80)
	btn.position = Vector2(W/2 - 200, H/2 - 20)
	layer.add_child(btn)
	# Hint
	var hint = Label.new()
	hint.text = "Tip: cutscene + audio require a click to start (browser audio policy)"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(W, 20)
	hint.position = Vector2(0, H/2 + 90)
	layer.add_child(hint)
	# Copyright bottom
	var cr = Label.new()
	cr.text = "© 2026 Kanen Coffee, LLC. All Rights Reserved."
	cr.add_theme_font_size_override("font_size", 11)
	cr.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53, 0.4))
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr.size = Vector2(W, 20)
	cr.position = Vector2(0, H - 40)
	layer.add_child(cr)
	btn.pressed.connect(func():
		Sfx.play("place")
		layer.queue_free()
		_show_character_select()
	)

const CHARACTERS = [
	{"id":"maya",   "name":"MAYA",   "tagline":"Bookish & warm",        "sprite":"person-maya.svg"},
	{"id":"theo",   "name":"THEO",   "tagline":"Indie barista",         "sprite":"person-theo.svg"},
	{"id":"jun",    "name":"JUN",    "tagline":"Quiet intellectual",    "sprite":"person-jun.svg"},
	{"id":"riley",  "name":"RILEY",  "tagline":"Vintage academic",      "sprite":"person-riley.svg"},
	{"id":"devin",  "name":"DEVIN",  "tagline":"Professor-poet",        "sprite":"person-devin.svg"},
]

func _show_character_select():
	var layer = CanvasLayer.new()
	layer.layer = 115
	add_child(layer)
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.03, 1)
	bg.size = Vector2(W, H)
	layer.add_child(bg)
	var header = Label.new()
	header.text = "CHOOSE YOUR COFFEE GEEK"
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 5)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size = Vector2(W, 48)
	header.position = Vector2(0, 30)
	layer.add_child(header)
	var sub = Label.new()
	sub.text = "Pick a character. Same game either way."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(W, 20)
	sub.position = Vector2(0, 80)
	layer.add_child(sub)
	# 5 cards in a row
	var card_w = 220.0
	var card_h = 480.0
	var gap = 18.0
	var total_w = card_w * 5 + gap * 4
	var start_x = (float(W) - total_w) / 2.0
	for i in CHARACTERS.size():
		var ch = CHARACTERS[i]
		var x = start_x + i * (card_w + gap)
		var card = Button.new()
		card.size = Vector2(card_w, card_h)
		card.position = Vector2(x, 130)
		layer.add_child(card)
		var preview = Sprite2D.new()
		preview.texture = textures.get(ch.sprite)
		preview.position = Vector2(card_w/2, 220)
		preview.scale = Vector2(1.0, 1.0)
		card.add_child(preview)
		var name_lbl = Label.new()
		name_lbl.text = ch.name
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(card_w, 32)
		name_lbl.position = Vector2(0, card_h - 64)
		card.add_child(name_lbl)
		var tag_lbl = Label.new()
		tag_lbl.text = ch.tagline
		tag_lbl.add_theme_font_size_override("font_size", 13)
		tag_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.size = Vector2(card_w, 20)
		tag_lbl.position = Vector2(0, card_h - 32)
		card.add_child(tag_lbl)
		var ch_id = ch.id
		card.pressed.connect(func():
			character_id = ch_id
			Sfx.play("place")
			layer.queue_free()
			if is_instance_valid(person_sprite):
				person_sprite.texture = textures.get(_person_key("idle"))
			_show_cutscene([
				{"sprite":"cutscene-1.svg", "sting":"sting_intro", "duration":3.5,
					"caption":"ANOTHER MORNING..."},
				{"sprite":"cutscene-2.svg", "sting":"sting_tense", "duration":3.5,
					"caption":"BUT SOMETHING'S WRONG..."},
				{"sprite":"cutscene-3.svg", "sting":"sting_reveal", "duration":3.8,
					"big_text":"BAD COFFEE", "sub_text":"INVASION!"},
				{"sprite":"cutscene-4.svg", "sting":"sting_hero", "duration":3.5,
					"big_text":"DEFEND", "sub_text":"YOUR CUP!"},
				{"sprite":"cutscene-5.svg", "sting":"waveStart", "duration":3.0,
					"big_text":"GROUNDS FOR", "sub_text":"DEFENSE"},
			], _show_briefing)
		)

var briefing_pages: Array = []
var briefing_idx: int = 0
var briefing_layer: CanvasLayer

# ============== CUTSCENE PLAYER ==============
var cutscene_layer: CanvasLayer
var cutscene_panels: Array = []
var cutscene_idx := 0
var cutscene_on_done: Callable
var cutscene_panel_sprite: Sprite2D
var cutscene_advance_timer: SceneTreeTimer

func _show_cutscene(panels: Array, on_done: Callable):
	if panels.is_empty():
		on_done.call()
		return
	cutscene_panels = panels
	cutscene_idx = 0
	cutscene_on_done = on_done
	if cutscene_layer and is_instance_valid(cutscene_layer):
		cutscene_layer.queue_free()
	cutscene_layer = CanvasLayer.new()
	cutscene_layer.layer = 110
	add_child(cutscene_layer)
	# Black background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = Vector2(W, H)
	cutscene_layer.add_child(bg)
	# Panel sprite (centered)
	cutscene_panel_sprite = Sprite2D.new()
	cutscene_panel_sprite.position = Vector2(W/2, H/2 - 30)
	cutscene_layer.add_child(cutscene_panel_sprite)
	# Skip button (bottom right)
	var skip_btn = Button.new()
	skip_btn.text = "Skip ▶"
	skip_btn.position = Vector2(W - 140, H - 60)
	skip_btn.custom_minimum_size = Vector2(120, 40)
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.pressed.connect(_skip_cutscene)
	cutscene_layer.add_child(skip_btn)
	# Click anywhere to advance
	var click_catcher = Button.new()
	click_catcher.flat = true
	click_catcher.size = Vector2(W, H)
	click_catcher.position = Vector2(0, 0)
	click_catcher.modulate.a = 0
	click_catcher.pressed.connect(_advance_cutscene)
	cutscene_layer.add_child(click_catcher)
	# Hint text bottom left
	var hint = Label.new()
	hint.text = "click anywhere to advance"
	hint.position = Vector2(20, H - 40)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	cutscene_layer.add_child(hint)
	_render_cutscene_panel()

func _render_cutscene_panel():
	if cutscene_idx >= cutscene_panels.size():
		_close_cutscene()
		return
	var p = cutscene_panels[cutscene_idx]
	var tex = textures.get(p.sprite)
	if not tex:
		_advance_cutscene()
		return
	# Clear any previous caption labels
	for child in cutscene_layer.get_children():
		if child.has_meta("is_caption"):
			child.queue_free()
	# Fit panel to screen with margins
	var panel_w = 800.0
	var panel_h = 450.0
	var max_w = float(W) - 100
	var max_h = float(H) - 140
	var s = min(max_w / panel_w, max_h / panel_h)
	cutscene_panel_sprite.texture = tex
	cutscene_panel_sprite.scale = Vector2.ONE * s
	cutscene_panel_sprite.modulate.a = 0.0
	cutscene_panel_sprite.scale = Vector2.ONE * s * 0.92
	var tw = create_tween()
	tw.tween_property(cutscene_panel_sprite, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(cutscene_panel_sprite, "scale", Vector2.ONE * s, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Overlay caption text (Godot Labels — SVG <text> doesn't render in Godot's SVG importer)
	var panel_top = float(H)/2 - 30 - (panel_h * s)/2
	var panel_bottom = float(H)/2 - 30 + (panel_h * s)/2
	var panel_center_x = float(W)/2
	if p.has("caption"):
		var box = _make_caption_box(p.caption, 28, Color(1, 0.94, 0.78), Color(0.05, 0.02, 0.0), Color(0, 0, 0))
		# Top-center
		box.set_meta("is_caption", true)
		cutscene_layer.add_child(box)
		var box_w = box.size.x
		box.position = Vector2((W - box_w)/2.0, panel_top + 24)
		_animate_caption_box(box)
	if p.has("big_text"):
		var big_box = _make_caption_box(p.big_text, 56, Color(1, 0.85, 0.2), Color(0.85, 0.1, 0.15), Color(0, 0, 0))
		big_box.set_meta("is_caption", true)
		big_box.rotation = -0.05
		cutscene_layer.add_child(big_box)
		var bw = big_box.size.x
		big_box.position = Vector2((W - bw)/2.0, panel_top + 70)
		_animate_caption_box(big_box, true)
	if p.has("sub_text"):
		var sub_box = _make_caption_box(p.sub_text, 44, Color(1, 0.94, 0.78), Color(0.05, 0.02, 0.0), Color(0, 0, 0))
		sub_box.set_meta("is_caption", true)
		sub_box.rotation = 0.04
		cutscene_layer.add_child(sub_box)
		var sw = sub_box.size.x
		sub_box.position = Vector2((W - sw)/2.0, panel_top + 165)
		_animate_caption_box(sub_box, true, 0.15)
	# Play sting (audio context already primed by start gate)
	if p.has("sting"):
		Sfx.play(p.sting)
	# Auto-advance timer
	var dur = p.get("duration", 4.0)
	cutscene_advance_timer = get_tree().create_timer(dur)
	var current_idx = cutscene_idx
	cutscene_advance_timer.timeout.connect(func():
		if cutscene_idx == current_idx and is_instance_valid(cutscene_layer):
			_advance_cutscene()
	)

func _animate_caption(lbl: Label, punchy := false, delay := 0.0):
	lbl.modulate.a = 0.0
	if punchy:
		lbl.scale = Vector2(0.5, 0.5)
		lbl.pivot_offset = Vector2(W/2.0, 30)
	var tw = create_tween()
	if delay > 0:
		tw.tween_interval(delay)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	if punchy:
		tw.parallel().tween_property(lbl, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.12)

# Comic caption box: solid fill + thick black border + bold text inside
func _make_caption_box(text: String, font_size: int, bg: Color, fg: Color, border: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 5
	sb.border_width_right = 5
	sb.border_width_top = 5
	sb.border_width_bottom = 5
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(4, 4)
	pc.add_theme_stylebox_override("panel", sb)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", fg)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(lbl)
	# Force compute desired size
	pc.reset_size()
	return pc

func _animate_caption_box(box: PanelContainer, punchy := false, delay := 0.0):
	box.modulate.a = 0.0
	box.pivot_offset = box.size / 2.0
	if punchy:
		box.scale = Vector2(0.5, 0.5)
	var tw = create_tween()
	if delay > 0:
		tw.tween_interval(delay)
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	if punchy:
		tw.parallel().tween_property(box, "scale", Vector2(1.1, 1.1), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "scale", Vector2(1.0, 1.0), 0.12)

func _advance_cutscene():
	if not is_instance_valid(cutscene_layer):
		return
	# Fade out current panel
	var tw = create_tween()
	tw.tween_property(cutscene_panel_sprite, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		cutscene_idx += 1
		if cutscene_idx >= cutscene_panels.size():
			_close_cutscene()
		else:
			_render_cutscene_panel()
	)

func _skip_cutscene():
	_close_cutscene()

func _close_cutscene():
	if is_instance_valid(cutscene_layer):
		var tw = create_tween()
		tw.tween_property(cutscene_layer, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			if is_instance_valid(cutscene_layer):
				cutscene_layer.queue_free()
			if cutscene_on_done:
				cutscene_on_done.call()
		)

# ============== CUPPING ROUND DATA ==============
const CUPPING_ROUNDS = [
	{
		"prompt": "SPOT THE SWILL — which is unrecoverable?",
		"cups": [
			{"label":"Cup A","desc":"Roasted today.\nGround fresh, just now.","correct":false},
			{"label":"Cup B","desc":"Pre-ground from a tin.\n6 months old.","correct":true},
			{"label":"Cup C","desc":"Whole bean.\nRoasted 1 week ago.","correct":false}
		],
		"why":"Pre-ground from a tin = double-staling. Whole bean from last week is still excellent."
	},
	{
		"prompt": "SPOT THE SWILL — which roast is burnt?",
		"cups": [
			{"label":"Cup A","desc":"Light roast.\nAgtron 65, fruity.","correct":false},
			{"label":"Cup B","desc":"Medium-dark.\nAgtron 45, balanced.","correct":false},
			{"label":"Cup C","desc":"Espresso roast.\nAgtron 25, charcoal.","correct":true}
		],
		"why":"Agtron under 30 = burnt territory. The bean itself becomes the flavor — not the origin."
	},
	{
		"prompt": "SPOT THE SWILL — which is under-extracted?",
		"cups": [
			{"label":"Cup A","desc":"1:16 ratio.\n28-second pull.","correct":false},
			{"label":"Cup B","desc":"1:30 ratio.\n14-second pull.","correct":true},
			{"label":"Cup C","desc":"1:18 ratio.\n25-second pull.","correct":false}
		],
		"why":"1:30 = brown water. The sweet spot is 1:15-1:18 with adequate contact time."
	},
	{
		"prompt": "SPOT THE SWILL — which milk is botched?",
		"cups": [
			{"label":"Cup A","desc":"Whole milk, 140°F (60°C).\nMicrofoam — silky.","correct":false},
			{"label":"Cup B","desc":"2% milk, 200°F (93°C).\nLarge bubbles.","correct":true},
			{"label":"Cup C","desc":"Oat milk, 145°F.\nSmooth foam.","correct":false}
		],
		"why":"Past 165°F (74°C) milk proteins denature; lactose burns. Steam to body temp + a bit, no more."
	},
	{
		"prompt": "SPOT THE SWILL — which one's got the K-pod problem?",
		"cups": [
			{"label":"Cup A","desc":"Single-origin pour-over.\n14 days off-roast.","correct":false},
			{"label":"Cup B","desc":"K-cup pod.\nSealed 14 months ago.","correct":true},
			{"label":"Cup C","desc":"French press.\nLocal beans, brewed today.","correct":false}
		],
		"why":"K-pods compound EVERY defect: pre-ground + 12+ months sealed + plastic taint."
	},
	{
		"prompt": "SPOT THE SWILL — which is fermented sour?",
		"cups": [
			{"label":"Cup A","desc":"Honey processed.\nSlight fruity notes.","correct":false},
			{"label":"Cup B","desc":"Wet processed.\nClean acidity.","correct":false},
			{"label":"Cup C","desc":"Cherries left 5 days.\nVinegar-like taste.","correct":true}
		],
		"why":"Coffee fruit fermenting on the bean = sour/vinegar defect. Smells/tastes like rotten apples."
	},
	{
		"prompt": "SPOT THE SWILL — which milk shouldn't be served?",
		"cups": [
			{"label":"Cup A","desc":"Steamed once, 145°F.\nUsed immediately.","correct":false},
			{"label":"Cup B","desc":"Steamed once, 150°F.\nSat 2 minutes.","correct":false},
			{"label":"Cup C","desc":"Re-steamed twice.\nWaited 5 min between.","correct":true}
		],
		"why":"Re-steaming = denatured proteins, burnt sugars. Discard cooled milk and start fresh."
	},
	{
		"prompt": "SPOT THE SWILL — which is criminally stale?",
		"cups": [
			{"label":"Cup A","desc":"Roasted 3 days ago.\nOpened today.","correct":false},
			{"label":"Cup B","desc":"Roasted 3 weeks ago.\nValve bag.","correct":false},
			{"label":"Cup C","desc":"Roasted 8 months ago.\nOpen for 2 weeks.","correct":true}
		],
		"why":"8 months past roast + 2 weeks of air = aroma corpse. Drinkable, but flat."
	},
	{
		"prompt": "SPOT THE SWILL — which one fails on grind alone?",
		"cups": [
			{"label":"Cup A","desc":"Whole bean.\nGround 30s before brew.","correct":false},
			{"label":"Cup B","desc":"Vacuum-sealed pre-ground.\nOpened 1 month ago.","correct":true},
			{"label":"Cup C","desc":"Whole bean, frozen.\nGround at use.","correct":false}
		],
		"why":"Vacuum slows oxidation but doesn't stop it. Pre-ground is doomed once ground."
	},
	{
		"prompt": "SPOT THE SWILL — which has it ALL wrong?",
		"cups": [
			{"label":"Cup A","desc":"Whole bean, 1 week.\nGround at use, fresh milk.","correct":false},
			{"label":"Cup B","desc":"Pre-ground + 6 mo old\n+ plastic + re-steamed milk.","correct":true},
			{"label":"Cup C","desc":"Single-origin, fresh.\nV60, 1:16 ratio.","correct":false}
		],
		"why":"Trifecta: stale + pre-ground + plastic + bad milk. The full swill catastrophe."
	}
]

var cupping_round_idx := 0
var cupping_layer: CanvasLayer

func _show_cupping_round():
	if game_over: return
	if cupping_round_idx >= CUPPING_ROUNDS.size():
		return  # ran out of rounds
	var data = CUPPING_ROUNDS[cupping_round_idx]
	cupping_round_idx += 1
	# Layer
	if cupping_layer and is_instance_valid(cupping_layer):
		cupping_layer.queue_free()
	cupping_layer = CanvasLayer.new()
	cupping_layer.layer = 90
	add_child(cupping_layer)
	var dim = ColorRect.new()
	dim.color = Color(0,0,0,0.85)
	dim.size = Vector2(W, H)
	cupping_layer.add_child(dim)
	# Card
	var card = PanelContainer.new()
	card.size = Vector2(900, 540)
	card.position = Vector2((W-900)/2, (H-540)/2)
	cupping_layer.add_child(card)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05)
	sb.border_width_left=4; sb.border_width_right=4; sb.border_width_top=4; sb.border_width_bottom=4
	sb.border_color = Color(0.94, 0.79, 0.53)
	sb.corner_radius_top_left=14; sb.corner_radius_top_right=14
	sb.corner_radius_bottom_left=14; sb.corner_radius_bottom_right=14
	sb.content_margin_left=28; sb.content_margin_right=28
	sb.content_margin_top=20; sb.content_margin_bottom=20
	card.add_theme_stylebox_override("panel", sb)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	# Header
	var header = Label.new()
	header.text = "☕ CUPPING ROUND %d / %d" % [cupping_round_idx, CUPPING_ROUNDS.size()]
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(header)
	var prompt = Label.new()
	prompt.text = data.prompt
	prompt.add_theme_font_size_override("font_size", 26)
	prompt.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt)
	# Three cups in a row
	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	for i in 3:
		var cup_data = data.cups[i]
		var cup_btn = Button.new()
		cup_btn.custom_minimum_size = Vector2(260, 240)
		cup_btn.add_theme_font_size_override("font_size", 14)
		var cup_v = VBoxContainer.new()
		cup_v.alignment = BoxContainer.ALIGNMENT_CENTER
		cup_v.position = Vector2(20, 20)
		cup_v.size = Vector2(220, 200)
		cup_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cup_btn.add_child(cup_v)
		# Cup emoji icon
		var icon = Label.new()
		icon.text = "☕"
		icon.add_theme_font_size_override("font_size", 64)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cup_v.add_child(icon)
		var name_l = Label.new()
		name_l.text = cup_data.label
		name_l.add_theme_font_size_override("font_size", 20)
		name_l.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cup_v.add_child(name_l)
		var desc_l = Label.new()
		desc_l.text = cup_data.desc
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.custom_minimum_size = Vector2(200, 0)
		desc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cup_v.add_child(desc_l)
		var idx = i
		cup_btn.pressed.connect(_on_cup_chosen.bind(idx, data, hb))
		hb.add_child(cup_btn)
	# Result area (initially empty)
	var result_panel = PanelContainer.new()
	result_panel.name = "ResultPanel"
	result_panel.visible = false
	v.add_child(result_panel)
	var rsb = StyleBoxFlat.new()
	rsb.bg_color = Color(0.08, 0.05, 0.02, 0.7)
	rsb.corner_radius_top_left=8; rsb.corner_radius_top_right=8
	rsb.corner_radius_bottom_left=8; rsb.corner_radius_bottom_right=8
	rsb.content_margin_left=14; rsb.content_margin_right=14
	rsb.content_margin_top=10; rsb.content_margin_bottom=10
	result_panel.add_theme_stylebox_override("panel", rsb)
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.add_theme_font_size_override("font_size", 14)
	result_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(820, 0)
	result_panel.add_child(result_label)
	# Continue / Skip row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	v.add_child(btn_row)
	var skip = Button.new()
	skip.name = "SkipBtn"
	skip.text = "Skip Cupping"
	skip.custom_minimum_size = Vector2(160, 44)
	skip.pressed.connect(_close_cupping)
	btn_row.add_child(skip)
	var cont = Button.new()
	cont.name = "ContinueBtn"
	cont.text = "Continue ▶"
	cont.add_theme_font_size_override("font_size", 16)
	cont.custom_minimum_size = Vector2(180, 44)
	cont.visible = false
	cont.pressed.connect(_close_cupping)
	btn_row.add_child(cont)

func _on_cup_chosen(idx: int, data: Dictionary, hb: HBoxContainer):
	var cup = data.cups[idx]
	var correct = cup.correct
	# Highlight all three
	for i in hb.get_child_count():
		var btn = hb.get_child(i)
		btn.disabled = true
		if data.cups[i].correct:
			btn.modulate = Color(0.5, 1.5, 0.5)
		elif i == idx:
			btn.modulate = Color(1.5, 0.5, 0.5)
	# Play sound
	if correct:
		Sfx.play("waveClear")
		beans += 50
		_update_hud()
	else:
		Sfx.play("error")
	# Show result
	var card = cupping_layer.get_child(1)  # PanelContainer
	var v = card.get_child(0)  # VBoxContainer
	var result_panel = v.get_node("ResultPanel")
	var result_label = result_panel.get_node("ResultLabel")
	var prefix = "[✓] CORRECT — +$50!  " if correct else "[✗] Not quite.  "
	result_label.text = prefix + "WHY: " + data.why
	if correct:
		result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	else:
		result_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	result_panel.visible = true
	# Show continue, hide skip
	var btn_row = v.get_child(v.get_child_count() - 1)
	btn_row.get_node("SkipBtn").visible = false
	btn_row.get_node("ContinueBtn").visible = true

func _close_cupping():
	if is_instance_valid(cupping_layer):
		cupping_layer.queue_free()

func _show_briefing():
	# Build the page list
	briefing_pages = [
		{
			"kind": "intro",
			"title": "GROUNDS FOR DEFENSE",
			"subtitle": "COFFEE GEEK ORIENTATION",
			"body": "You're a coffee geek in training.\n\nBad coffee is coming for your cup — stale beans, pre-ground bags, charred roasts, watered-down shots, reheated milk, and worse. All real defects. All swill.\n\nYour mission: spot each defect, deploy the right inspection tool, and fail it before it ruins your morning. No swill makes it into the cup.\n\nThe next pages introduce the threats and your tools.\nClick NEXT to learn them, or SKIP if you've already earned your geek stripes."
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
	briefing_pages.append({ "kind":"section", "title":"YOUR COFFEE GEEK KIT", "subtitle":"Four tools. Each catches specific defects." })
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
		"title": "READY TO GET GEEKY?",
		"body": "★ Right tool → 2× damage + ✓ DEFECT CAUGHT\n✗ Wrong tool → 0.6× damage + ✗ WRONG TOOL\n👁 Sherlock Beans is the generalist — always works.\n☆ Pod-zilla (boss) → all tools apply at 1.3×\n\n🤢 IF A BAD BEAN GETS PAST YOU\n→ You drink it. -1 CUP. Lose at 0 cups.\n\nClick empty slot → place tool.\nClick placed tool → sell (60% refund).\nPress P + click enemy → Perfect Cupping Shot.\n\nHit 'Start Wave' (top right) when you're ready."
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
	# Copyright footer
	var copyright_lbl = Label.new()
	copyright_lbl.text = "© 2026 Kanen Coffee, LLC. All Rights Reserved."
	copyright_lbl.add_theme_font_size_override("font_size", 10)
	copyright_lbl.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53, 0.4))
	copyright_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(copyright_lbl)

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
		badge_lbl.text = "SPECIALTY: %s   |   COST: $%d" % [str(p.specialty).to_upper(), p.cost]
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
	keys.append("person.svg")
	keys.append("person-sip.svg")
	keys.append("person-yuck.svg")
	keys.append("person-male.svg")
	keys.append("person-male-sip.svg")
	keys.append("person-male-yuck.svg")
	keys.append("person-female.svg")
	keys.append("person-female-sip.svg")
	keys.append("person-female-yuck.svg")
	keys.append("person-maya.svg")
	keys.append("person-theo.svg")
	keys.append("person-jun.svg")
	keys.append("person-riley.svg")
	keys.append("person-devin.svg")
	keys.append("comic-burst.svg")
	keys.append("cutscene-1.svg")
	keys.append("cutscene-2.svg")
	keys.append("cutscene-3.svg")
	keys.append("cutscene-4.svg")
	keys.append("cutscene-5.svg")
	keys.append("cutscene-boss.svg")
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

var person_sprite: Sprite2D
var person_busy := false  # true while showing sip or yuck
var character_id := "male"  # "male" or "female"

func _person_key(state: String) -> String:
	# state in {"idle", "sip", "yuck"} → returns the sprite filename for the chosen character.
	# Falls back to the default male sip/yuck if the chosen character doesn't have those variants yet.
	if state == "idle":
		return "person-" + character_id + ".svg"
	var suffix = "-sip" if state == "sip" else "-yuck"
	var specific = "person-" + character_id + suffix + ".svg"
	if textures.has(specific):
		return specific
	# fallback so sip/yuck still work for new characters
	return "person-male" + suffix + ".svg"

func _build_barista():
	person_sprite = Sprite2D.new()
	person_sprite.texture = textures.get(_person_key("idle"))
	person_sprite.position = PATH_PTS[PATH_PTS.size()-1] + Vector2(-110, -80)
	person_sprite.scale = Vector2(1.0, 1.0)
	add_child(person_sprite)
	# Idle bob
	var tw = create_tween().set_loops()
	tw.tween_property(person_sprite, "scale", Vector2(1.04, 1.04), 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(person_sprite, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	# periodic happy sip every 5-9 seconds
	_schedule_idle_sip()

func _schedule_idle_sip():
	var t = randf_range(5.0, 9.0)
	get_tree().create_timer(t).timeout.connect(func():
		if game_over or not is_instance_valid(person_sprite):
			return
		_play_idle_sip()
	)

func _play_idle_sip():
	if person_busy or game_over:
		_schedule_idle_sip()
		return
	person_busy = true
	person_sprite.texture = textures.get(_person_key("sip"))
	# small content scale-up
	var tw = create_tween()
	tw.tween_property(person_sprite, "scale", Vector2(1.06, 1.06), 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.7)
	tw.tween_property(person_sprite, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(person_sprite):
			person_sprite.texture = textures.get(_person_key("idle"))
		person_busy = false
		_schedule_idle_sip()
	)

func _play_yuck_reaction():
	if not is_instance_valid(person_sprite): return
	person_busy = true
	person_sprite.texture = textures.get(_person_key("yuck"))
	# Quick recoil shake animation
	var orig_x = person_sprite.position.x
	var tw = create_tween()
	tw.tween_property(person_sprite, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# horizontal jitter (4 quick shakes)
	for i in 4:
		var dx = 6.0 if i % 2 == 0 else -6.0
		tw.tween_property(person_sprite, "position:x", orig_x + dx, 0.05)
	tw.tween_property(person_sprite, "position:x", orig_x, 0.05)
	tw.tween_interval(0.7)
	tw.tween_property(person_sprite, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(person_sprite):
			person_sprite.texture = textures.get(_person_key("idle"))
		person_busy = false
	)

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

	beans_label = _stat_label("Cash", "$250")
	wave_label = _stat_label("Wave", "0 / 10")
	hp_label = _stat_label("Your Cup", "20")
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
	title.text = "DEPLOY A TOOL"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for k in TOWER_DEFS:
		var d = TOWER_DEFS[k]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(440, 72)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_pick_tower.bind(k))
		# horizontal layout: [icon] [name+cost] [blurb]
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		hb.position = Vector2(8, 4)
		hb.size = Vector2(424, 64)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hb)
		# Icon
		var icon_box = CenterContainer.new()
		icon_box.custom_minimum_size = Vector2(64, 64)
		icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(icon_box)
		var icon = TextureRect.new()
		icon.texture = textures.get(d.sprite)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(60, 60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(icon)
		# Right side: name/cost + blurb
		var right = VBoxContainer.new()
		right.add_theme_constant_override("separation", 2)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(right)
		var name_lbl = Label.new()
		name_lbl.text = "%s   $%d" % [d.name, d.cost]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.94, 0.79, 0.53))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(name_lbl)
		var blurb_lbl = Label.new()
		blurb_lbl.text = d.blurb
		blurb_lbl.add_theme_font_size_override("font_size", 11)
		blurb_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
		blurb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb_lbl.custom_minimum_size = Vector2(340, 0)
		blurb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(blurb_lbl)
		vb.add_child(btn)
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
	# Tiny persistent copyright + legal links in bottom-right corner
	var copyright_corner = RichTextLabel.new()
	copyright_corner.bbcode_enabled = true
	copyright_corner.fit_content = true
	copyright_corner.scroll_active = false
	copyright_corner.size = Vector2(440, 20)
	copyright_corner.position = Vector2(W - 460, H - 24)
	copyright_corner.add_theme_font_size_override("normal_font_size", 10)
	copyright_corner.add_theme_color_override("default_color", Color(0.94, 0.79, 0.53, 0.45))
	copyright_corner.text = "[right]© 2026 Kanen Coffee, LLC. All Rights Reserved.   ·   [url=terms]Terms[/url]   ·   [url=privacy]Privacy[/url][/right]"
	copyright_corner.meta_clicked.connect(_on_legal_link_clicked)
	canvas.add_child(copyright_corner)

func _on_legal_link_clicked(meta):
	var url = ""
	if meta == "terms":
		url = "legal/terms.html"
	elif meta == "privacy":
		url = "legal/privacy.html"
	if url != "":
		# In web export, OS.shell_open opens in a new tab.
		# In editor/desktop, it'll try to open via OS — works for full URLs.
		# Build full URL from current location for web safety.
		OS.shell_open(url)

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
	_flash_info("Sold for $%d" % int(def.cost * 0.6))

func _on_start_wave():
	if spawning or wave_active or game_over:
		return
	if wave_num >= max_waves:
		return
	# Play boss-intro cutscene before the final wave
	if wave_num + 1 == max_waves:
		_show_cutscene([
			{"sprite":"cutscene-boss.svg", "sting":"sting_boss", "duration":4.5,
				"big_text":"POD-ZILLA", "sub_text":"APPROACHES!"}
		], _start_wave_actual)
		return
	_start_wave_actual()

func _start_wave_actual():
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
			# Show cupping round between waves
			get_tree().create_timer(0.6).timeout.connect(_show_cupping_round)
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
	# For root-towers (Father Time): prefer un-rooted enemies so we don't waste shots re-freezing.
	var def = t.get_meta("def")
	var r2 = def.range * def.range
	var prefer_unrooted = def.get("root", 0) > 0
	var now = Time.get_ticks_msec() / 1000.0
	var best = null
	var best_t = -1.0
	var best_fallback = null
	var fallback_t = -1.0
	for e in enemies:
		if not e.get_meta("alive"):
			continue
		if t.position.distance_squared_to(e.position) > r2:
			continue
		var et = e.get_meta("t")
		var is_rooted = e.get_meta("rooted_until") > now
		if prefer_unrooted and is_rooted:
			# remember as fallback in case nothing un-rooted is in range
			if et > fallback_t:
				fallback_t = et
				best_fallback = e
			continue
		if et > best_t:
			best_t = et
			best = e
	return best if best != null else best_fallback

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
			# Pod-zilla: every check applies, but only 1.3× since it's compound
			d *= 1.3
			match_label = "✓ ONE OF MANY"
		elif specialty == defect:
			d *= MATCH_BONUS
			match_label = "✓ DEFECT CAUGHT"
		elif specialty == "visual":
			# Sherlock Beans is the generalist — visual inspection always works at base damage
			pass
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

const DEFECT_KILL_LABEL := {
	"date": "STALE!",
	"aroma": "PRE-GROUND!",
	"visual": "OVER-ROASTED!",
	"taste": "BAD TASTE!",
	"compound": "POD DEFEATED!",
}

func _kill_enemy(e):
	if not e.get_meta("alive"):
		return
	e.set_meta("alive", false)
	var def = e.get_meta("def")
	beans += def.bounty
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
	# Defect-type popup at kill position
	var defect_key = def.get("defect", "")
	var label_text = DEFECT_KILL_LABEL.get(defect_key, "CAUGHT!")
	_spawn_kill_label(e.position, label_text, "+$%d" % def.bounty)

func _spawn_kill_label(pos: Vector2, defect_text: String, bounty_text: String):
	# Comic-book burst with text on top — pops up, scale-punches, drifts, fades
	var root = Node2D.new()
	root.position = pos + Vector2(0, -50)
	add_child(root)
	# Comic burst sprite (background)
	var burst = Sprite2D.new()
	burst.texture = textures.get("comic-burst.svg")
	burst.scale = Vector2(0.85, 0.85)
	root.add_child(burst)
	# Slight rotation for energy
	root.rotation = randf_range(-0.15, 0.15)
	# Defect name on top
	var name_lbl = Label.new()
	name_lbl.text = defect_text
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0, 0, 0))
	name_lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size = Vector2(170, 30)
	name_lbl.position = Vector2(-85, -22)
	root.add_child(name_lbl)
	# Bounty under it
	var bounty_lbl = Label.new()
	bounty_lbl.text = bounty_text
	bounty_lbl.add_theme_font_size_override("font_size", 16)
	bounty_lbl.add_theme_color_override("font_color", Color(0, 0.5, 0))
	bounty_lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	bounty_lbl.add_theme_constant_override("outline_size", 3)
	bounty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bounty_lbl.size = Vector2(170, 22)
	bounty_lbl.position = Vector2(-85, 6)
	root.add_child(bounty_lbl)
	# Animation: scale punch-in, drift up, fade
	root.scale = Vector2(0.2, 0.2)
	var tw = create_tween()
	tw.tween_property(root, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "position:y", root.position.y - 30, 1.0)
	tw.tween_interval(0.45)
	tw.tween_property(root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): root.queue_free())

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
	# Big "SWILL!" reaction at the person
	var person_pos = PATH_PTS[PATH_PTS.size()-1] + Vector2(-110, -80)
	_spawn_swill_alert(person_pos)
	# Animate the yuck face + recoil
	_play_yuck_reaction()
	# Pulse the HP label red
	if hp_label:
		hp_label.modulate = Color(1.0, 0.3, 0.3, 1)
		var tw = create_tween()
		tw.tween_property(hp_label, "modulate", Color(0.94, 0.79, 0.53, 1), 0.6)
	# Camera-style red flash via a full-screen overlay
	_red_flash()
	_update_hud()
	if hp <= 0:
		_lose()

func _spawn_swill_alert(pos: Vector2):
	# Big rotating "🤢 SWILL DRUNK! -1 CUP" pop-up
	var lbl = Label.new()
	lbl.text = "🤢 SWILL DRUNK!  −1 CUP"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = pos + Vector2(-160, -40)
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.18).from(Vector2.ONE)
	tw.tween_interval(0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): lbl.queue_free())

func _red_flash():
	var rect = ColorRect.new()
	rect.color = Color(0.9, 0.1, 0.1, 0.0)
	rect.size = Vector2(W, H)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas = CanvasLayer.new()
	canvas.layer = 50
	canvas.add_child(rect)
	add_child(canvas)
	var tw = create_tween()
	tw.tween_property(rect, "color:a", 0.30, 0.08)
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	tw.tween_callback(func(): canvas.queue_free())

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
	beans_label.text = "$" + str(beans)
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
	_show_message("☕ Pure Brew Achieved!", "You stopped Pod-zilla and every defect on the line. You drank zero swill today. Coffee geek status: confirmed.")

func _lose():
	game_over = true
	Sfx.play("lose")
	_show_message("💀 You Drank Swill", "Bad coffee got past inspection and into your cup. Sad sip. Run it back?")

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
