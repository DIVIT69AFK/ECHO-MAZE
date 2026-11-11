extends Control
## Everything drawn on top of the world: menus, the in-game HUD, and the touch buttons.

const D = preload("res://scripts/data.gd")

var game
var serif: SystemFont
var serif_i: SystemFont
var mono: SystemFont
var vignette: Texture2D
var W := 0.0   # size of the virtual screen the menus are laid out on (real size / UI scale)
var H := 0.0
var shop_hits: Array = []   # clickable areas of the shop: { rect, act }

const GOLD := Color8(255, 235, 160)
const PALE := Color8(220, 230, 250)

const TOUCH_MENUS := {
	"title": [["▲", "ArrowUp"], ["▼", "ArrowDown"], ["OK", "Enter"]],
	"level_select": [["▲", "ArrowUp"], ["▼", "ArrowDown"], ["OK", "Enter"], ["BACK", "Escape"]],
	"journal": [["◀", "ArrowLeft"], ["▶", "ArrowRight"], ["BACK", "Escape"]],
	"achievements": [["BACK", "Escape"]],
	"credits": [["BACK", "Escape"]],
	"settings": [["▲", "ArrowUp"], ["▼", "ArrowDown"], ["◀", "ArrowLeft"], ["▶", "ArrowRight"], ["BACK", "Escape"]],
	"ending": [["OK", "Enter"]],
	"shop": [["BACK", "Escape"]],
	"pause": [["RESUME", "Escape"], ["RESTART", "KeyR"], ["JOURNAL", "KeyJ"], ["MUTE", "KeyM"], ["QUIT", "KeyQ"]],
}


func _ready() -> void:
	serif = _font(["Georgia", "Times New Roman", "serif"], false)
	serif_i = _font(["Georgia", "Times New Roman", "serif"], true)
	mono = _font(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"], false)
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var u = Vector2(x - 63.5, y - 63.5).length() / 64.0
			img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.55, 1.35, u)))
	vignette = ImageTexture.create_from_image(img)


func _font(names: Array, italic: bool) -> SystemFont:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_italic = italic
	return f


func spaced(s: String) -> String:
	return " ".join(s.split(""))


## Draw text. align: 0 = centred on x, -1 = starts at x, 1 = ends at x.
func txt(s: String, x: float, y: float, size: int, a: float, col := Color.WHITE, align := 0, font: Font = null) -> void:
	if font == null:
		font = mono
	var w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align == 0 and w > W - 16.0:
		size = maxi(8, int(size * (W - 16.0) / w))
		w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var px = x - w / 2.0 if align == 0 else (x if align < 0 else x - w)
	draw_string(font, Vector2(px, y + size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, a))


func wrap_text(s: String, max_w: float, font: Font, size: int) -> Array:
	var lines = []
	var cur = ""
	for word in s.split(" "):
		var t = word if cur == "" else cur + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines


func box(r: Rect2, fill: Color, line: Color) -> void:
	draw_rect(r, fill)
	draw_rect(r, line, false, 1.0)


func touch_hint(s: String) -> String:
	return s.replace("SPACE to clap", "Tap CLAP to clap").replace("SHIFT/Z to whisper", "Tap WHISPER to whisper") \
		.replace("Hold C to sneak", "Push the stick gently, or tap SNEAK, to sneak").replace("CLICK to throw a pebble", "Tap the screen to throw a pebble")


# ---------------------------------------------------------------- touch buttons
## The buttons for the current screen, in real screen pixels. Round ones have r, bars have w and h.
func touch_buttons() -> Array:
	var gw: float = game.W
	var gh: float = game.H
	if game.state == "play":
		var r = clampf(minf(gw, gh) * 0.085, 30.0, 44.0)
		return [
			{ "label": "CLAP", "code": "Space", "pos": Vector2(gw - r * 1.6, gh - r * 1.7), "r": r * 1.15 },
			{ "label": "WHISPER", "code": "KeyZ", "pos": Vector2(gw - r * 4.1, gh - r * 1.3), "r": r * 0.9 },
			{ "label": "SNEAK", "code": "KeyX", "pos": Vector2(gw - r * 1.4, gh - r * 4.2), "r": r * 0.9, "on": game.sneak_toggle },
			{ "label": "II", "code": "Escape", "pos": Vector2(gw - 28.0, 84.0), "r": 18.0 },
		] + ([{ "label": "TRADE", "code": "KeyE", "pos": Vector2(gw / 2.0, gh - r * 1.5), "r": r, "on": true }] if game.near_wizard() else [])
	if not TOUCH_MENUS.has(game.state):
		return []
	var list: Array = TOUCH_MENUS[game.state]
	var bw = minf(110.0, (gw - 16.0) / list.size() - 8.0)
	var total = list.size() * (bw + 8.0) - 8.0
	var out = []
	for k in list.size():
		out.append({ "label": list[k][0], "code": list[k][1], "pos": Vector2((gw - total) / 2.0 + k * (bw + 8.0) + bw / 2.0, gh - 34.0),
			"w": bw, "h": 46.0, "on": list[k][1] == "KeyM" and game.sfx.muted })
	return out


func button_at(p: Vector2):
	for b in touch_buttons():
		if b.has("r"):
			if p.distance_to(b.pos) < b.r * 1.2:
				return b
		elif absf(p.x - b.pos.x) < b.w / 2.0 + 4.0 and absf(p.y - b.pos.y) < b.h / 2.0 + 6.0:
			return b
	return null


func _draw_touch_ui() -> void:
	var bs = touch_buttons()
	if game.state != "play" and not bs.is_empty():
		draw_rect(Rect2(0, game.H - 66.0, game.W, 66.0), Color(0, 0, 0, 0.88))
	W = game.W
	for b in bs:
		var fill = Color(0.24, 0.43, 0.59, 0.6) if b.get("on", false) else Color(0.08, 0.11, 0.16, 0.5)
		var line = Color(0.78, 0.88, 1.0, 0.5)
		if b.has("r"):
			draw_circle(b.pos, b.r, fill)
			draw_arc(b.pos, b.r, 0, TAU, 40, line, 1.5, true)
			# the clap button fills back up while the clap recharges
			if b.code == "Space" and game.clap_cd > 0.0:
				draw_arc(b.pos, b.r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - game.clap_cd / game.CLAP_CD), 40, Color(GOLD, 0.9), 3.0, true)
		else:
			box(Rect2(b.pos - Vector2(b.w, b.h) / 2.0, Vector2(b.w, b.h)), fill, line)
		txt(b.label, b.pos.x, b.pos.y, 10 if b.get("r", 99.0) < 30.0 else 12, 0.9)
	if game.state == "play":
		var on: bool = game.joy_id != -1
		var jp: Vector2 = game.joy_origin if on else Vector2(game.W * 0.17, game.H - 110.0)
		draw_arc(jp, game.JOY_R, 0, TAU, 40, Color(0.78, 0.88, 1.0, 0.5 if on else 0.18), 1.5, true)
		draw_circle(jp + game.joy * game.JOY_R, 18.0, Color(0.78, 0.88, 1.0, 0.45 if on else 0.12))


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if game == null:
		return
	var rw: float = game.W
	var rh: float = game.H
	var px: float = game.PX
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	# dark corners, turning red as danger gets close; white or red flash
	draw_texture_rect(vignette, Rect2(0, 0, rw, rh), false, Color(game.danger * 0.31, 0, 0, 0.85))
	if game.flash > 0.0:
		draw_rect(Rect2(0, 0, rw, rh), Color(0.51, 0, 0, game.flash * 0.55) if game.flash_red else Color(1, 1, 1, game.flash * 0.5))

	var uis: float = game.UIS
	W = rw / uis
	H = rh / uis
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(uis, uis) * px)
	_draw_ui()
	_draw_toast()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	if game.touch_mode:
		_draw_touch_ui()


func _menu_line(label: String, k: int, y: float, size: int, locked := false) -> void:
	var sel: bool = game.menu_sel == k
	var col = Color8(120, 120, 130) if locked else (GOLD if sel else PALE)
	txt(("› " if sel else "") + label + (" ‹" if sel else ""), W / 2.0, y, size, 0.35 if locked else (0.95 if sel else 0.65), col)


func _draw_ui() -> void:
	var cx = W / 2.0
	var save: Dictionary = game.save
	match game.state:
		"title":
			txt(spaced("ECHO MAZE"), cx, H * 0.28, int(minf(62.0, W / 10.0)), 0.94, Color.WHITE, 0, serif)
			txt("the dark is listening", cx, H * 0.28 + 48.0, 16, 0.45, Color.WHITE, 0, serif_i)
			var items = [
				"CONTINUE (DEPTH %d)" % save.depth if save.depth > 1 else "BEGIN DESCENT",
				"NEW DESCENT", "SELECT DEPTH",
				("ENDLESS MODE" + (" (BEST: %d)" % save.endlessBest if save.endlessBest > 0 else "")) if save.completed else "ENDLESS (LOCKED)",
				"JOURNAL LORE (%d/%d)" % [save.notes.size(), D.NOTES.size()],
				"ACHIEVEMENTS (%d/%d)" % [save.achievements.size(), D.ACHIEVEMENTS.size()],
				"SETTINGS", "CREDITS",
			]
			for k in items.size():
				_menu_line(items[k], k, H * 0.48 + k * 28.0, 14, k == 3 and not save.completed)
			if not game.touch_mode:
				txt("UP / DOWN / CLICK to select  ·  ENTER to confirm", cx, H - 64.0, 12, 0.35)
				txt("WASD move  ·  SPACE clap  ·  SHIFT whisper  ·  C/X sneak  ·  CLICK pebble", cx, H - 42.0, 13, 0.3, Color.WHITE, 0, serif_i)
			return
		"level_select":
			txt(spaced("SELECT DEPTH"), cx, H * 0.22, 32, 0.9, Color.WHITE, 0, serif)
			for i in D.LEVELS.size():
				var unlocked: bool = i < save.depth
				var best = "%.1fs" % save.best[str(i)] if save.best.has(str(i)) else "--"
				var sel: bool = game.menu_sel == i
				var label = "%d. %s  [Best: %s]" % [i + 1, D.LEVELS[i].name, best] if unlocked else "%d. [LOCKED]" % (i + 1)
				txt(("› " if sel else "") + label + (" ‹" if sel else ""), cx, H * 0.32 + i * 30.0, 14, 0.85 if unlocked else 0.35,
					Color8(100, 100, 110) if not unlocked else (GOLD if sel else PALE))
			if not game.touch_mode:
				txt("ENTER to descend  ·  ESC to return", cx, H - 48.0, 13, 0.45)
			return
		"journal":
			txt(spaced("JOURNAL OF THE CARTOGRAPHER"), cx, H * 0.18, 28, 0.92, Color.WHITE, 0, serif)
			txt("Discovered %d of %d entries" % [save.notes.size(), D.NOTES.size()], cx, H * 0.23, 14, 0.5, Color.WHITE, 0, serif_i)
			for i in D.NOTES.size():
				var sel2: bool = game.menu_sel == i
				var unl: bool = save.notes.has(i)
				txt(("• " if sel2 else "") + "Entry %d" % (i + 1), cx - 240.0 + i * 68.0, H * 0.30, 12, 0.8 if unl else 0.35,
					Color8(90, 90, 100) if not unl else (GOLD if sel2 else Color8(200, 210, 230)))
			var bw = minf(600.0, W - 24.0)
			draw_rect(Rect2(cx - bw / 2.0, H * 0.36, bw, H * 0.45), Color(1, 1, 1, 0.2), false, 1.0)
			if save.notes.has(game.menu_sel):
				var note: Dictionary = D.NOTES[game.menu_sel]
				txt(note.title, cx, H * 0.42, 18, 0.9, Color8(255, 245, 220), 0, serif_i)
				var lines = wrap_text(note.text, bw - 60.0, serif, 15)
				for k in lines.size():
					txt(lines[k], cx, H * 0.48 + k * 26.0, 15, 0.8, Color8(240, 240, 240), 0, serif)
			else:
				txt("[This page remains hidden in the deep]", cx, H * 0.55, 16, 0.35, Color.WHITE, 0, serif_i)
			if not game.touch_mode:
				txt("LEFT / RIGHT to browse  ·  ESC to return", cx, H - 48.0, 13, 0.45)
			return
		"achievements":
			txt(spaced("ACHIEVEMENTS"), cx, H * 0.16, 30, 0.9, Color.WHITE, 0, serif)
			txt("Unlocked %d of %d" % [save.achievements.size(), D.ACHIEVEMENTS.size()], cx, H * 0.21, 14, 0.5, Color.WHITE, 0, serif_i)
			var cols = 2 if W >= 720.0 else 1
			var iw = minf(340.0, W - 24.0)
			var ih = 54.0 if cols == 2 else 34.0
			var sx = cx - (iw if cols == 2 else iw / 2.0) - (10.0 if cols == 2 else 0.0)
			for i in D.ACHIEVEMENTS.size():
				var ach: Dictionary = D.ACHIEVEMENTS[i]
				var x = sx + (i % cols) * (iw + 20.0)
				var y = H * 0.26 + (i / cols) * (ih + (12.0 if cols == 2 else 6.0))
				var unl2: bool = save.achievements.has(ach.id)
				box(Rect2(x, y, iw, ih), Color(0.08, 0.14, 0.18, 0.6) if unl2 else Color(0.06, 0.06, 0.07, 0.4),
					Color(0.39, 0.78, 1.0, 0.4) if unl2 else Color(1, 1, 1, 0.1))
				txt(("✦ " if unl2 else "✧ ") + ach.title, x + 14.0, y + (18.0 if cols == 2 else 17.0), 14, 0.95 if unl2 else 0.4,
					GOLD if unl2 else Color8(150, 150, 150), -1)
				if cols == 2:
					txt(ach.desc, x + 14.0, y + 36.0, 12, 0.75 if unl2 else 0.3, Color8(220, 220, 220), -1, serif_i)
			if not game.touch_mode:
				txt("ESC to return", cx, H - 42.0, 13, 0.45)
			return
		"settings":
			txt(spaced("SETTINGS"), cx, H * 0.22, 32, 0.9, Color.WHITE, 0, serif)
			var s: Dictionary = save.settings
			var opts = [
				"MASTER VOLUME: %d%%" % roundi(s.masterVol * 100), "SFX VOLUME: %d%%" % roundi(s.sfxVol * 100),
				"AMBIENCE VOLUME: %d%%" % roundi(s.ambVol * 100), "SCREEN SHAKE: %s" % ("ENABLED" if s.screenShake else "DISABLED"),
				"CHARACTER: %s" % ("BOY WITH THE RED SCARF" if s.character else "BOY IN THE RED CAP"), "BACK TO TITLE",
			]
			for k in opts.size():
				_menu_line(opts[k], k, H * 0.36 + k * 36.0, 15)
			var pt: Texture2D = game.tex["spr_player%d" % (1 if s.character else 0)]
			draw_texture_rect_region(pt, Rect2(cx - 40.0, H * 0.36 + 6 * 36.0, 80, 80), Rect2((int(game.time * 3.0) % 2) * 24, 0, 24, 24))
			if not game.touch_mode:
				txt("UP / DOWN to navigate  ·  LEFT / RIGHT to adjust  ·  ESC to return", cx, H - 54.0, 13, 0.45)
			return
		"credits":
			txt(spaced("ECHO MAZE"), cx, H * 0.24, 36, 0.92, Color.WHITE, 0, serif)
			txt("A Subterranean Acoustic Horror Adventure", cx, H * 0.24 + 38.0, 15, 0.5, Color.WHITE, 0, serif_i)
			var lines2 = [
				"Original Concept & Architecture by DIVIT69AFK",
				"Sound Physics, the Sleeper, 8 Themed Environments, Chimes,",
				"Acoustic Puzzles, Lore & Journal by Gowreesh V.T",
				"Art, Experience, the Wizard & Godot version by Shrri Pranav",
				"",
				"Built with Godot Engine 4",
				"",
				"Thank you for descending into the dark.",
			]
			for k in lines2.size():
				txt(lines2[k], cx, H * 0.40 + k * 24.0, 13, 0.7)
			if not game.touch_mode:
				txt("ESC to return", cx, H - 48.0, 13, 0.45)
			return
		"ending":
			var all_notes: bool = save.notes.size() == D.NOTES.size()
			var lines3 = [
				"You climb out into a pale grey morning.",
				"The silence of the surface is vast and quiet.",
				"The final page of the journal reads: “If you escaped, you learned to hear the truth of the dark. You are what is left of us.”" if all_notes
					else "Somewhere far below in the obsidian depths, an echo claps twice in answer.",
				"",
				"Descents Complete: 8  ·  Notes Collected: %d/%d" % [save.notes.size(), D.NOTES.size()],
				"Total Descending Time: %.1f minutes  ·  Total Deaths: %d" % [save.stats.timePlayed / 60.0, save.stats.deaths],
				"Endless Mode is unlocked.",
			]
			var y2 = H * 0.30
			for l in lines3:
				if l == "":
					y2 += 32.0
				for w in wrap_text(l, minf(640.0, W - 48.0), serif_i, 19):
					txt(w, cx, y2, 19, 0.85, Color.WHITE, 0, serif_i)
					y2 += 32.0
			txt("ENTER  ·  RETURN TO SURFACE TITLE", cx, y2 + 36.0, 14, 0.8)
			return
	_draw_game_hud()


func _draw_game_hud() -> void:
	var cx = W / 2.0
	var save: Dictionary = game.save
	if not game.has_level:
		return
	var label = ""
	if game.cfg.get("wizard", false):
		label = game.cfg.name.to_upper()
	elif game.mode == "story":
		label = "DEPTH %d: %s" % [game.level_idx + 1, D.LEVELS[game.level_idx].name.to_upper()]
	else:
		label = "ENDLESS DEPTH %d" % game.endless_round
	txt(spaced(label), 22.0, 26.0, 12, 0.45, Color.WHITE, -1)
	if game.sneak_toggle:
		txt(spaced("SNEAKING"), 22.0, 46.0, 11, 0.45, Color.WHITE, -1)

	# the items you own: squares bottom-left. Click one (or press its number) to hold it.
	var owned: Array = game.owned_items()
	for k in owned.size():
		var id: String = owned[k]
		var r = Rect2(22.0 + k * 48.0, H - 64.0, 42, 42)
		var held: bool = game.equipped == id
		box(r, Color(0.2, 0.15, 0.36, 0.95) if held else Color(0.04, 0.055, 0.086, 0.78), Color(0.95, 0.79, 0.3, 0.95) if held else Color(0.59, 0.86, 1.0, 0.35))
		draw_texture_rect_region(game.tex["spr_icon_" + id], Rect2(r.position + Vector2(5, 5), Vector2(32, 32)), Rect2(0, 0, 24, 24))
		txt(str(k + 1), r.position.x + 6.0, r.position.y + 7.0, 9, 0.6, Color.WHITE, -1)
		var count = ""
		if id == "powder" or id == "machine": count = "x%d" % game.item_count(id)
		elif id == "bow": count = str(game.item_count("arrow") + game.item_count("poison"))
		elif id == "gun": count = str(game.item_count("bullet"))
		elif id == "torch": count = "%ds" % int(save.items.torch_charge)
		txt(count, r.position.x + 38.0, r.position.y + 35.0, 9, 0.9, GOLD, 1)

	# status of the item in your hand, on the right
	if game.equipped != "":
		var lines: Array = game.item_status(game.equipped)
		var sw = 230.0
		var sy = 96.0 if W >= 700.0 else 118.0
		var sh = 30.0 + lines.size() * 17.0
		box(Rect2(W - sw - 16.0, sy, sw, sh), Color(0.03, 0.047, 0.078, 0.9), Color(0.95, 0.79, 0.3, 0.6))
		draw_texture_rect_region(game.tex["spr_icon_" + game.equipped], Rect2(W - sw - 10.0, sy + 3.0, 22, 22), Rect2(0, 0, 24, 24))
		txt(spaced(D.ITEMS[game.equipped].name.to_upper()), W - sw + 16.0, sy + 14.0, 10, 0.95, GOLD, -1)
		for k in lines.size():
			txt(lines[k], W - sw - 4.0, sy + 36.0 + k * 17.0, 11, 0.85, Color.WHITE, -1)
		if game.equipped == "torch":
			var frac: float = save.items.torch_charge / D.TORCH_TIME
			draw_rect(Rect2(W - sw - 4.0, sy + sh - 6.0, (sw - 24.0) * frac, 3.0), Color(1.0, 0.6, 0.15, 0.9))

	var dev = []
	if game.light_mode: dev.append("LIGHT")
	if game.has_gun: dev.append("GUN")
	if game.god_mode: dev.append("GOD")
	if not dev.is_empty():
		txt(spaced("DEV: " + " · ".join(dev)), 22.0, 86.0, 11, 0.45, Color8(255, 220, 160), -1)

	var narrow = W < 700.0
	# blue crystals (the currency), always shown
	var cy = 70.0 if narrow else 48.0
	draw_texture_rect_region(game.tex.spr_bluecrystal, Rect2(W - 42.0, cy - 11.0, 22, 22), Rect2(0, 0, 24, 24))
	txt(str(save.crystals), W - 46.0, cy, 12, 0.85, Color8(140, 190, 255), 1)
	if game.wizard_pos != null:
		txt(spaced("EXPERIENCE  %d" % save.xp), W - 22.0, 48.0 if narrow else 26.0, 12, 0.8, Color8(242, 201, 76), 1)
		if game.near_wizard() and game.state == "play" and not game.touch_mode:
			txt("E  ·  TRADE WITH THE WIZARD", cx, H * 0.82, 14, 0.85, GOLD)
	else:
		var py = 37.0 if narrow else 15.0
		for k in game.pebbles:
			draw_texture_rect_region(game.tex.spr_pebble, Rect2(W - 35.0 - k * 14.0, py, 22, 22), Rect2(0, 0, 24, 24))
		txt("PEBBLES", W - 32.0 - game.pebbles * 14.0, py + 11.0, 10, 0.35, Color.WHITE, 1)

	# level name and hint when a level starts
	if game.intro_t > 0.0:
		var a = minf(1.0, minf(game.intro_t / 1.2, (5.5 - game.intro_t) / 0.8))
		txt(label, cx, H * 0.28, 32, 0.9 * a, Color.WHITE, 0, serif)
		var hint: String = game.cfg.get("hint", "")
		if hint != "":
			var ls = wrap_text(touch_hint(hint) if game.touch_mode else hint, minf(580.0, W - 48.0), serif_i, 16)
			for k in ls.size():
				txt(ls[k], cx, H * 0.28 + 44.0 + k * 24.0, 16, 0.65 * a, Color.WHITE, 0, serif_i)

	if game.kill_t > 0.0 and game.state != "dead":
		var a2 = minf(1.0, minf(game.kill_t, (3.5 - game.kill_t) / 0.4))
		txt(game.kill_text, cx, H * 0.72, 22, 0.9 * maxf(a2, 0.0), Color8(255, 225, 225), 0, serif_i)

	# a soft glow at the screen edge pointing to the way down, just after a clap
	if game.exit_hint_t > 0.0 and game.state == "play":
		var sp: Vector2 = Vector2(W, H) / 2.0 + (game.exit_pos - game.cam) * game.ZOOM / game.UIS
		var mg = 26.0
		if sp.x < mg or sp.x > W - mg or sp.y < mg or sp.y > H - mg:
			var dv = sp - Vector2(W, H) / 2.0
			var kk = minf((W / 2.0 - mg) / maxf(0.000001, absf(dv.x)), (H / 2.0 - mg) / maxf(0.000001, absf(dv.y)))
			var hp = Vector2(W, H) / 2.0 + dv * kk
			var a3 = minf(1.0, game.exit_hint_t / 0.8) * 0.28
			draw_texture_rect(game.soft_tex, Rect2(hp - Vector2(50, 50), Vector2(100, 100)), false, Color(0.92, 0.96, 1.0, a3))

	if game.note_t > 0.0 and game.note_obj != null:
		var a4 = minf(1.0, minf(game.note_t / 1.5, 9.5 - game.note_t))
		var nw = minf(600.0, W - 20.0)
		var ls2 = wrap_text("“" + game.note_obj.text + "”", nw - 40.0, serif_i, 14)
		var nh = 46.0 + ls2.size() * 22.0
		box(Rect2(cx - nw / 2.0, H - 40.0 - nh, nw, nh), Color(0, 0, 0, 0.75 * a4), Color(1.0, 0.98, 0.9, 0.3 * a4))
		txt(game.note_obj.title, cx, H - 22.0 - nh, 14, 0.7 * a4, GOLD, 0, serif_i)
		for k in ls2.size():
			txt(ls2[k], cx, H - nh + 2.0 + k * 22.0, 14, 0.9 * a4, Color8(255, 250, 235), 0, serif_i)

	if game.state == "dead":
		var a5 = minf(1.0, (2.8 - game.dead_t) / 0.6)
		txt(game.kill_text, cx, H / 2.0 - 16.0, 28, 0.9 * a5, Color8(255, 190, 190), 0, serif_i)

	if game.state == "pause":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.78))
		txt(spaced("PAUSED"), cx, H * 0.28, 32, 0.95, Color.WHITE, 0, serif)
		if not game.touch_mode:
			var rows = ["ESC / P  ·  RESUME DESCENT", "R  ·  RESTART LEVEL", "J  ·  VIEW DISCOVERED JOURNAL NOTES",
				"M  ·  TOGGLE MUTE", "`  ·  DEVELOPER CONSOLE", "Q  ·  QUIT TO TITLE"]
			for k in rows.size():
				txt(rows[k], cx, H * 0.38 + k * 30.0, 14, 0.75)

	if game.state == "shop":
		_draw_shop()

	if game.console_msg_t > 0.0:
		txt(game.console_msg, 22.0, H - 76.0, 13, 0.85 * minf(1.0, game.console_msg_t), Color8(255, 220, 160), -1)
	if game.console_open:
		draw_rect(Rect2(0, H - 56.0, W, 36.0), Color(0, 0, 0, 0.9))
		txt("> " + game.console_text + ("_" if int(game.time * 2.0) % 2 == 1 else " "), 22.0, H - 38.0, 14, 0.95, Color8(255, 220, 160), -1)


# ---------------------------------------------------------------- the wizard's shop
func shop_action_at(p: Vector2) -> String:
	for h in shop_hits:
		if h.rect.has_point(p):
			return h.act
	return ""


func _draw_shop() -> void:
	var save: Dictionary = game.save
	var cx = W / 2.0
	shop_hits = []
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
	var pw = minf(560.0, W - 20.0)
	var ph = 470.0
	var px = cx - pw / 2.0
	var py = maxf(60.0, H / 2.0 - ph / 2.0 - 20.0)
	box(Rect2(px, py, pw, ph), Color(0.07, 0.05, 0.13, 0.96), Color(0.95, 0.79, 0.3, 0.7))
	txt(spaced("THE WIZARD'S SHOP"), cx, py + 26.0, 14, 0.95, GOLD)

	# what the player has
	draw_texture_rect_region(game.tex.spr_bluecrystal, Rect2(px + 18.0, py + 44.0, 24, 24), Rect2((int(game.time * 2.0) % 2) * 24, 0, 24, 24))
	txt("%d blue crystals" % save.crystals, px + 48.0, py + 56.0, 13, 0.9, Color8(140, 190, 255), -1)
	txt("%d experience" % save.xp, px + pw - 18.0, py + 56.0, 13, 0.9, Color8(242, 201, 76), 1)

	# the two tabs
	var labels = ["SHOP", "SELL"]
	var tw = (pw - 46.0) / 2.0
	for i in 2:
		var r = Rect2(px + 18.0 + i * (tw + 10.0), py + 78.0, tw, 34.0)
		var on = game.shop_tab == i
		box(r, Color(0.2, 0.15, 0.36, 0.95) if on else Color(0.05, 0.04, 0.09, 0.9), Color(0.95, 0.79, 0.3, 0.9 if on else 0.25))
		txt(spaced(labels[i]), r.position.x + tw / 2.0, r.position.y + 17.0, 13, 0.95 if on else 0.55, GOLD if on else PALE)
		shop_hits.append({ "rect": r, "act": "tab%d" % i })

	var top = py + 126.0
	if game.shop_tab == 0:
		# Shop: three tiers of three items, each tier opened by experience
		var lw = 86.0
		var cw2 = (pw - 36.0 - lw - 20.0) / 3.0
		for i in D.ITEM_ORDER.size():
			var id: String = D.ITEM_ORDER[i]
			var it: Dictionary = D.ITEMS[id]
			var tier: Dictionary = D.SHOP_TIERS[it.tier]
			var open: bool = save.xp >= tier.xp
			var ry = top + it.tier * 72.0
			if i % 3 == 0:
				txt(tier.name, px + 18.0, ry + 20.0, 12, 0.95 if open else 0.45, GOLD if open else PALE, -1)
				txt("OPEN" if open else "%d XP" % tier.xp, px + 18.0, ry + 40.0, 10, 0.75 if open else 0.45, Color8(150, 255, 190) if open else PALE, -1)
			var r2 = Rect2(px + 18.0 + lw + (i % 3) * (cw2 + 10.0), ry, cw2, 62.0)
			var sel: bool = game.shop_buy_sel == i
			box(r2, Color(0.16, 0.24, 0.31, 0.92) if sel else Color(0.05, 0.06, 0.1, 0.85), Color(0.59, 0.86, 1.0, 0.95 if sel else 0.25))
			var dim = 1.0 if open else 0.35
			draw_texture_rect_region(game.tex["spr_icon_" + id], Rect2(r2.position.x + 6.0, r2.position.y + 13.0, 36, 36), Rect2(0, 0, 24, 24), Color(1, 1, 1, dim))
			var words: Array = it.name.split(" ")
			txt(words[0], r2.position.x + 46.0, r2.position.y + 15.0, 10, 0.9 * dim, Color.WHITE, -1)
			if words.size() > 1:
				txt(" ".join(words.slice(1)), r2.position.x + 46.0, r2.position.y + 28.0, 10, 0.9 * dim, Color.WHITE, -1)
			draw_texture_rect_region(game.tex.spr_bluecrystal, Rect2(r2.position.x + 44.0, r2.position.y + 38.0, 16, 16), Rect2(0, 0, 24, 24), Color(1, 1, 1, dim))
			txt(str(it.price), r2.position.x + 62.0, r2.position.y + 47.0, 11, 0.9 * dim, Color8(140, 190, 255), -1)
			shop_hits.append({ "rect": r2, "act": "pick%d" % i })
		var pick: Dictionary = D.ITEMS[D.ITEM_ORDER[game.shop_buy_sel]]
		var dl = wrap_text(pick.desc, pw - 40.0, serif_i, 12)
		for k in dl.size():
			txt(dl[k], cx, top + 228.0 + k * 16.0, 12, 0.75, Color.WHITE, 0, serif_i)
		var why: String = game.cannot_buy(D.ITEM_ORDER[game.shop_buy_sel])
		var rb = Rect2(cx - 110.0, top + 268.0, 220.0, 36.0)
		box(rb, Color(0.12, 0.3, 0.2, 0.9) if why == "" else Color(0.06, 0.06, 0.08, 0.8), Color(0.59, 1.0, 0.75, 0.7) if why == "" else Color(1, 1, 1, 0.15))
		txt("BUY  ·  %d crystals" % pick.price, cx, rb.position.y + 18.0, 12, 0.95 if why == "" else 0.4)
		shop_hits.append({ "rect": rb, "act": "buy" })
		txt(game.shop_msg if game.shop_msg != "" else why, cx, top + 318.0, 11, 0.8, Color8(150, 255, 190) if game.shop_msg.begins_with("Bought") else Color8(255, 200, 160))
	else:
		# Sell: a grid of everything creatures drop
		var cw = (pw - 36.0 - 30.0) / 4.0
		for i in D.DROP_ORDER.size():
			var drop: Dictionary = D.DROPS[D.DROP_ORDER[i]]
			var have = int(save.inv.get(drop.id, 0))
			var r3 = Rect2(px + 18.0 + i * (cw + 10.0), top, cw, 150.0)
			var sel = game.shop_sel == i
			box(r3, Color(0.16, 0.24, 0.31, 0.92) if sel else Color(0.05, 0.06, 0.1, 0.85), Color(0.59, 0.86, 1.0, 0.95 if sel else 0.25))
			var isz = minf(64.0, cw - 16.0)
			draw_texture_rect(game.tex["spr_icon_" + drop.id], Rect2(r3.position.x + (cw - isz) / 2.0, r3.position.y + 10.0, isz, isz), false,
				Color(1, 1, 1, 1.0 if have > 0 else 0.35))
			var words = drop.name.split(" ")
			txt(words[0], r3.position.x + cw / 2.0, r3.position.y + 88.0, 11, 0.9 if have > 0 else 0.45)
			txt(words[1], r3.position.x + cw / 2.0, r3.position.y + 102.0, 11, 0.9 if have > 0 else 0.45)
			txt("x %d" % have, r3.position.x + cw / 2.0, r3.position.y + 120.0, 13, 0.95 if have > 0 else 0.4, GOLD)
			draw_texture_rect_region(game.tex.spr_bluecrystal, Rect2(r3.position.x + cw / 2.0 - 34.0, r3.position.y + 128.0, 16, 16), Rect2(0, 0, 24, 24))
			txt("%d each" % drop.price, r3.position.x + cw / 2.0 + 8.0, r3.position.y + 137.0, 10, 0.75, Color8(140, 190, 255))
			shop_hits.append({ "rect": r3, "act": "sel%d" % i })
		var picked: Dictionary = D.DROPS[D.DROP_ORDER[game.shop_sel]]
		var n = int(save.inv.get(picked.id, 0))
		var bw = (pw - 46.0) / 2.0
		var by = top + 164.0
		var names = ["SELL 1  (+%d)" % picked.price, "SELL ALL  (+%d)" % (picked.price * n)]
		var acts = ["sell1", "sellall"]
		for i in 2:
			var r4 = Rect2(px + 18.0 + i * (bw + 10.0), by, bw, 38.0)
			box(r4, Color(0.12, 0.3, 0.2, 0.9) if n > 0 else Color(0.06, 0.06, 0.08, 0.8), Color(0.59, 1.0, 0.75, 0.7) if n > 0 else Color(1, 1, 1, 0.15))
			txt(names[i], r4.position.x + bw / 2.0, r4.position.y + 19.0, 12, 0.95 if n > 0 else 0.4)
			shop_hits.append({ "rect": r4, "act": acts[i] })
		if not game.touch_mode:
			txt("ENTER sells 1  ·  SPACE sells all", cx, by + 56.0, 11, 0.4)

	if not game.touch_mode:
		txt("UP / DOWN switch tab  ·  LEFT / RIGHT pick  ·  ENTER buy or sell  ·  ESC close", cx, py + ph - 16.0, 11, 0.45)


func _draw_toast() -> void:
	if game.toast_current == null or game.toast_timer <= 0.0:
		return
	var a = minf(1.0, minf(game.toast_timer / 0.5, (4.0 - game.toast_timer) / 0.5))
	var cx = W / 2.0
	var tw = minf(400.0, W - 16.0)
	box(Rect2(cx - tw / 2.0, 22.0, tw, 48.0), Color(0.06, 0.1, 0.14, 0.9 * a), Color(0.39, 0.78, 1.0, 0.6 * a))
	txt("ACHIEVEMENT UNLOCKED: %s" % game.toast_current.title.to_upper(), cx, 40.0, 12, 0.95 * a, GOLD)
	txt(game.toast_current.desc, cx, 58.0, 11, 0.75 * a, PALE, 0, serif_i)
