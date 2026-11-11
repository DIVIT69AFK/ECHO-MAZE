extends Node2D
## Echo Maze — main game script.
## Holds the game state, builds each level, moves the player and monsters,
## runs the sound waves, and manages the lights. Drawing of the world is done
## by small View nodes that call back into the draw_* functions here.

const D = preload("res://scripts/data.gd")
const T := 32                       # size of one maze tile in world pixels
const WALL_TH := 10.0               # thickness of the wall art band
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CLAP_CD := 2.2
const AFTERGLOW := 0.8              # seconds for an echo's light to fade once the wave front has passed
const CELL := 8                     # size of one cell of the sound-distance grid, in world pixels
const FAR := 60000.0                # distance value meaning "sound never reaches here"
const STEP_SLOT := 5                # the wave slot kept for footsteps
const SAVE_PATH := "user://save.json"

# ---------------------------------------------------------------- state
var state := "title"   # title, play, pause, dead, clear, ending, journal, achievements, settings, level_select, credits
var mode := "story"    # story, endless
var level_idx := 0
var endless_round := 1
var cur_seed := 0
var wizard_stop := 0   # 0 = not at the wizard, 1 or 2 = which visit
var menu_sel := 0
var time := 0.0

var save := {
	"depth": 1, "completed": false, "notes": [], "best": {}, "endlessBest": 0, "xp": 0, "atWizard": 0,
	"achievements": [], "upgrades": [],
	"stats": { "deaths": 0, "steps": 0, "claps": 0, "whispers": 0, "pebbles": 0, "chimes": 0, "sleepersAwakened": 0, "secrets": 0, "timePlayed": 0.0 },
	"settings": { "masterVol": 0.8, "sfxVol": 0.9, "ambVol": 0.75, "screenShake": true, "character": 0 },
}

# ---------------------------------------------------------------- current level
var has_level := false
var g := PackedByteArray()          # 1 = wall, 0 = open
var gw := 0
var gh := 0
var cfg := {}
var exit_pos := Vector2.ZERO
var exit_seen := 0.0
var exit_floor := 0.0
var note_pos = null
var note_idx := 0
var note_taken := false
var pebbles := 0
var chime = null                    # { pos, ringing, cooldown }
var door = null                     # { tile, pos, open }
var secret = null                   # { tile, pos, broken, seen }
var upgrade_item = null             # { pos, id, taken }
var wizard_pos = null

var player := Vector2.ZERO
const PLAYER_R := 6.0
var enemies: Array = []
var waves: Array = [null, null, null, null, null, null]   # the sound waves now travelling (6 slots)
var blocked := PackedByteArray()    # which cells of the sound grid are wall
var fw := 0
var fh := 0
var flying: Array = []
var water_ripples: Array = []
var shots: Array = []

var cam := Vector2.ZERO
var shake := 0.0
var danger := 0.0
var level_time := 0.0
var intro_t := 0.0
var note_t := 0.0
var note_obj = null
var dead_t := 0.0
var clear_t := 0.0
var title_t := 0.0
var hb_t := 0.0
var step_t := 0.0
var kill_t := 0.0
var kill_text := ""
var exit_hint_t := 0.0
var player_loud := false
var clap_cd := 0.0
var whisper_cd := 0.0
var flash := 0.0
var flash_red := false
var level_claps := 0
var level_alerts := 0
var ambient_t := 5.0
var sneak_toggle := false
var toast_queue: Array = []
var toast_current = null
var toast_timer := 0.0

# dev console
var console_open := false
var console_text := ""
var console_msg := ""
var console_msg_t := 0.0
var light_mode := false
var has_gun := false
var god_mode := false
var gun_cd := 0.0
var mouse_held := false
var mouse_pos := Vector2.ZERO

# input
var keys := {}
var touch_mode := false
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy := Vector2.ZERO
const JOY_R := 46.0

# screen
var W := 1280.0
var H := 800.0
var ZOOM := 1.0
var UIS := 1.0
var PX := 1.0

# nodes
var floor_view: Node2D
var wall_view: Node2D
var entity_view: Node2D
var echo_view: Node2D
var overlay: Sprite2D
var overlay_mat: ShaderMaterial
var blank_field: ImageTexture
var cam_node: Camera2D
var hud: Control
var sfx: Node
var tex := {}
var soft_tex: Texture2D


# ================================================================ setup
func _ready() -> void:
	randomize()
	# how many real pixels make one layout pixel (2 on Retina screens, more on phones)
	PX = maxf(1.0, DisplayServer.screen_get_dpi() / 160.0) if OS.has_feature("mobile") else maxf(1.0, DisplayServer.screen_get_scale())
	touch_mode = DisplayServer.is_touchscreen_available()
	load_save()
	_load_textures()
	_build_nodes()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	sfx.apply_volumes(save.settings)


func _load_textures() -> void:
	for n in ["player0", "player1", "listener", "drifter", "sleeper0", "sleeper1", "sleeper2", "mimic", "wizard",
			"exit", "note", "pebble", "chime", "door", "crack", "phosphor", "soles", "crystal", "satchel"]:
		tex["spr_" + n] = load("res://art/spr_%s.png" % n)
	for th in D.THEMES.keys():
		tex["tile_" + th] = load("res://art/tile_%s.png" % th)
		var p = "res://art/wall_%s.png" % th
		if ResourceLoader.exists(p):
			tex["wall_" + th] = load(p)
		for k in 3:
			var fp = "res://art/floor_%s_%d.png" % [th, k]
			if ResourceLoader.exists(fp):
				tex["floor_%s_%d" % [th, k]] = load(fp)
	soft_tex = _make_glow_texture()


## A soft round glow, used for the hint that points toward the way down
func _make_glow_texture() -> Texture2D:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half = size / 2.0
	for y in size:
		for x in size:
			var u = Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			img.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0.0, 1.0 - u), 2.0)))
	return ImageTexture.create_from_image(img)


func _make_view(kind: String, parent: Node, linear := false) -> Node2D:
	var v = Node2D.new()
	v.set_script(preload("res://scripts/view.gd"))
	v.game = self
	v.kind = kind
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(v)
	return v





func _build_nodes() -> void:
	floor_view = _make_view("floor", self)
	wall_view = _make_view("walls", self, true)
	entity_view = _make_view("entities", self)

	# The darkness. One rectangle over the whole level whose shader lets light through
	# only where a sound wave has just passed (see echo_light.gdshader).
	var white = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	overlay = Sprite2D.new()
	overlay.texture = ImageTexture.create_from_image(white)
	overlay.centered = false
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = preload("res://scripts/echo_light.gdshader")
	overlay.material = overlay_mat
	add_child(overlay)
	var one = PackedByteArray()
	one.resize(2)
	one.encode_half(0, FAR)
	blank_field = ImageTexture.create_from_image(Image.create_from_data(1, 1, false, Image.FORMAT_RH, one))
	for i in 6:
		overlay_mat.set_shader_parameter("f%d" % i, blank_field)

	echo_view = _make_view("echo", self, true)
	cam_node = Camera2D.new()
	add_child(cam_node)
	cam_node.make_current()

	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = Control.new()
	hud.set_script(preload("res://scripts/hud.gd"))
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)

	sfx = Node.new()
	sfx.set_script(preload("res://scripts/sfx.gd"))
	add_child(sfx)


func _on_resize() -> void:
	var s = get_viewport().get_visible_rect().size
	W = s.x / PX
	H = s.y / PX
	ZOOM = maxf(0.85, minf(W, H) / 580.0)
	UIS = clampf(minf(W / 560.0, H / 640.0), 0.6, 1.0)


# ================================================================ save
func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in save.keys():
		if not parsed.has(k):
			continue
		if typeof(save[k]) == TYPE_DICTIONARY and k != "best":
			for k2 in parsed[k].keys():
				save[k][k2] = parsed[k][k2]
		else:
			save[k] = parsed[k]
	save.depth = int(save.depth)
	save.xp = int(save.xp)
	save.atWizard = int(save.atWizard)
	save.endlessBest = int(save.endlessBest)
	save.notes = save.notes.map(func(v): return int(v))


func persist() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func has_upgrade(id: String) -> bool:
	return save.upgrades.has(id)


func unlock_achievement(id: String) -> void:
	if save.achievements.has(id):
		return
	save.achievements.append(id)
	persist()
	for a in D.ACHIEVEMENTS:
		if a.id == id:
			toast_queue.append(a)
			sfx.play("achievement")


func unlock_upgrade(id: String) -> void:
	if has_upgrade(id):
		return
	save.upgrades.append(id)
	persist()
	for u in D.UPGRADES:
		if u.id == id:
			kill_text = "Artifact Discovered: %s" % u.name
			kill_t = 4.0
			sfx.play("secret")
	if save.upgrades.size() >= D.UPGRADES.size():
		unlock_achievement("upgraded")


# ================================================================ maze helpers
## Same random number generator as the HTML game, so story mazes come out the same.
class Rng:
	var a = 0
	func _init(s: int) -> void:
		a = s & 0xFFFFFFFF
	func _imul(x: int, y: int) -> int:
		return ((x & 0xFFFF) * y + ((((x >> 16) & 0xFFFF) * y) & 0xFFFF) * 65536) & 0xFFFFFFFF
	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xFFFFFFFF
		var t = _imul(a ^ (a >> 15), 1 | a)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


func gen_maze(cw: int, ch: int, rng: Rng) -> void:
	gw = cw * 2 + 1
	gh = ch * 2 + 1
	g = PackedByteArray()
	g.resize(gw * gh)
	g.fill(1)
	var vis = PackedByteArray()
	vis.resize(cw * ch)
	var stack = [Vector2i(0, 0)]
	vis[0] = 1
	g[gw + 1] = 0
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var nb = []
		for d in DIRS:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < cw and n.y < ch and vis[n.y * cw + n.x] == 0:
				nb.append(d)
		if nb.is_empty():
			stack.pop_back()
			continue
		var dd: Vector2i = nb[int(rng.next() * nb.size())]
		var nn: Vector2i = c + dd
		vis[nn.y * cw + nn.x] = 1
		g[(2 * c.y + 1 + dd.y) * gw + (2 * c.x + 1 + dd.x)] = 0
		g[(2 * nn.y + 1) * gw + (2 * nn.x + 1)] = 0
		stack.append(nn)
	# knock out some walls to make loops and other ways round
	for y in range(1, gh - 1):
		for x in range(1, gw - 1):
			if g[y * gw + x] != 1:
				continue
			var between = (x % 2 == 0 and y % 2 == 1) or (x % 2 == 1 and y % 2 == 0)
			if between and rng.next() < 0.11:
				g[y * gw + x] = 0
	# a central chamber on bigger levels
	if cw >= 12 and ch >= 10 and rng.next() < 0.8:
		var cx = gw / 2
		var cy = gh / 2
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				g[(cy + dy) * gw + (cx + dx)] = 0


func is_wall_t(tx: int, ty: int) -> bool:
	if not has_level:
		return false
	if tx < 0 or ty < 0 or tx >= gw or ty >= gh:
		return true
	if door != null and not door.open and door.tile == Vector2i(tx, ty):
		return true
	if secret != null and not secret.broken and secret.tile == Vector2i(tx, ty):
		return true
	return g[ty * gw + tx] == 1


func is_wall(p: Vector2) -> bool:
	return is_wall_t(floori(p.x / T), floori(p.y / T))


func tile_idx(p: Vector2) -> int:
	return floori(p.y / T) * gw + floori(p.x / T)


func center_of(i: int) -> Vector2:
	return Vector2((i % gw + 0.5) * T, (i / gw + 0.5) * T)


func open_neighbors(i: int) -> Array:
	var x = i % gw
	var y = i / gw
	var out = []
	for d in DIRS:
		var tx: int = x + d.x
		var ty: int = y + d.y
		if tx >= 0 and ty >= 0 and tx < gw and ty < gh and not is_wall_t(tx, ty):
			out.append(ty * gw + tx)
	return out


## Distance in steps from `start` to every open tile (-1 = cannot be reached)
func bfs(start: int) -> PackedInt32Array:
	var d = PackedInt32Array()
	d.resize(gw * gh)
	d.fill(-1)
	if start < 0 or start >= d.size():
		return d
	var q = [start]
	d[start] = 0
	var h = 0
	while h < q.size():
		var i: int = q[h]
		h += 1
		for j in open_neighbors(i):
			if d[j] < 0:
				d[j] = d[i] + 1
				q.append(j)
	return d


func clear_line(a: Vector2, b: Vector2) -> bool:
	var n = ceili(a.distance_to(b) / 8.0)
	for k in range(1, n):
		if is_wall(a.lerp(b, float(k) / n)):
			return false
	return true


# ================================================================ level building
func endless_cfg(r: int) -> Dictionary:
	var themes = ["entrance", "whispering", "laboratory", "flooded", "collapsed", "chasm", "hive", "heart"]
	var surfs = [D.SURF_STONE, D.SURF_METAL, D.SURF_WATER, D.SURF_SOFT]
	return {
		"theme": themes[(r - 1) % themes.size()], "name": "The Endless Dark — Depth %d" % r,
		"cells": [mini(24, 9 + r), mini(20, 7 + r)], "surf": surfs[(r - 1) % surfs.size()],
		"listeners": mini(4, 1 + r / 2), "drifters": mini(4, r / 2) if r >= 2 else 0,
		"sleepers": mini(3, (r - 1) / 3) if r >= 3 else 0, "mimics": (1 if r % 2 == 0 else 0) if r >= 4 else 0,
		"hasChime": r >= 2 and randf() < 0.6, "hasDoor": r >= 3 and randf() < 0.4, "hasSecret": randf() < 0.35,
		"pebbles": 3, "lSpeed": minf(1.45, 1.0 + r * 0.04),
		"hint": "Endless descent. How deep into the silence can you survive?" if r == 1 else "",
	}


func build_level(c: Dictionary, seed_value: int) -> void:
	var rng = Rng.new(seed_value)
	cfg = c
	has_level = false
	door = null
	secret = null
	chime = null
	upgrade_item = null
	note_pos = null
	wizard_pos = null
	gen_maze(c.cells[0], c.cells[1], rng)

	# The wizard's cave: knock out every inner wall so it is one plain open cavern
	if c.get("wizard", false):
		for y in range(1, gh - 1):
			for x in range(1, gw - 1):
				g[y * gw + x] = 0
	has_level = true

	exit_seen = 0.0
	exit_floor = 0.0
	note_taken = false
	pebbles = c.get("pebbles", 3) + (2 if has_upgrade("satchel") else 0)

	var start_i = gw + 1
	var d = bfs(start_i)
	var cells = []
	var far = 0
	var fi = start_i
	for cy in c.cells[1]:
		for cx in c.cells[0]:
			var i: int = (2 * cy + 1) * gw + 2 * cx + 1
			cells.append(i)
			if d[i] > far:
				far = d[i]
				fi = i
	exit_pos = center_of(fi)

	# a story note in a dead end
	if mode == "story" and not c.get("wizard", false) and level_idx < D.NOTES.size():
		var pool = cells.filter(func(i): return i != fi and d[i] > 4 and open_neighbors(i).size() == 1)
		if pool.is_empty():
			pool = cells.filter(func(i): return i != fi and d[i] > 4)
		if not pool.is_empty():
			note_pos = center_of(pool[int(rng.next() * pool.size())])
			note_idx = level_idx

	# cracked secret wall, with the level's upgrade behind it
	if c.get("hasSecret", false) or c.has("upgrade"):
		var cand = []
		for ty in range(1, gh - 1):
			for tx in range(1, gw - 1):
				var idx = ty * gw + tx
				if g[idx] == 1:
					var adj = []
					for o in [idx - 1, idx + 1, idx - gw, idx + gw]:
						if g[o] == 0:
							adj.append(o)
					if adj.size() >= 2:
						cand.append({ "tile": Vector2i(tx, ty), "adj": adj })
		if not cand.is_empty():
			var ch = cand[int(rng.next() * cand.size())]
			secret = { "tile": ch.tile, "pos": (Vector2(ch.tile) + Vector2(0.5, 0.5)) * T, "broken": false, "seen": 0.0 }
			if c.has("upgrade") and not has_upgrade(c.upgrade):
				upgrade_item = { "pos": center_of(ch.adj[0]), "id": c.upgrade, "taken": false }

	# resonance chime
	if c.get("hasChime", false):
		var pool2 = cells.filter(func(i): return i != fi and i != start_i and d[i] > 3 and d[i] < far * 0.7)
		if not pool2.is_empty():
			chime = { "pos": center_of(pool2[int(rng.next() * pool2.size())]), "ringing": 0.0, "cooldown": 0.0 }

	if c.get("wizard", false):
		pebbles = 0
		wizard_pos = center_of(((gh >> 1) | 1) * gw + ((gw >> 1) | 1))

	# sealed door near the exit, opened by the chime
	var d_exit = bfs(fi)
	if c.get("hasDoor", false) and chime != null:
		var pool3 = cells.filter(func(i): return d_exit[i] >= 2 and d_exit[i] <= 5 and open_neighbors(i).size() <= 2)
		if not pool3.is_empty():
			var di: int = pool3[int(rng.next() * pool3.size())]
			door = { "tile": Vector2i(di % gw, di / gw), "pos": center_of(di), "open": false }

	# monsters
	enemies = []
	var start_c = center_of(start_i)
	var far_ok = func(i): return i != fi and d[i] > maxi(6, int(far * 0.4))
	var spawn = cells.filter(func(i): return far_ok.call(i) and center_of(i).distance_to(start_c) > 8 * T)
	if spawn.is_empty():
		spawn = cells.filter(far_ok)
	var pick = func() -> Vector2:
		if spawn.is_empty():
			return center_of(fi)
		var k = int(rng.next() * spawn.size())
		var v: int = spawn[k]
		spawn.remove_at(k)
		return center_of(v)
	var ls: float = c.get("lSpeed", 1.0)
	for k in c.get("listeners", 0):
		enemies.append({ "type": "listener", "pos": pick.call(), "r": 11.0, "hunt": 82.0 * ls, "wander": 25.0, "kills": true,
			"state": "patrol", "alert_t": 0.0, "search_t": 0.0 })
	for k in c.get("drifters", 0):
		enemies.append({ "type": "drifter", "pos": pick.call(), "r": 9.0, "hunt": 38.0, "wander": 36.0, "kills": false, "shriek_cd": 0.0 })
	for k in c.get("sleepers", 0):
		enemies.append({ "type": "sleeper", "pos": pick.call(), "r": 14.0, "hunt": 110.0 * ls, "wander": 0.0, "kills": true,
			"sleep": "dormant", "agitation": 0.0, "wake_t": 0.0, "snore_t": randf_range(0, 3) })
	var guard = cells.filter(func(i): return d_exit[i] >= 2 and d_exit[i] <= 4)
	for k in c.get("mimics", 0):
		var gp: Vector2 = center_of(fi) if guard.is_empty() else center_of(guard[int(rng.next() * guard.size())])
		enemies.append({ "type": "mimic", "pos": gp, "r": 12.0, "hunt": 74.0 * ls, "wander": 0.0, "kills": true,
			"clap_t": randf_range(4, 7), "mimic": "lurk" })
	for e in enemies:
		_init_enemy(e)

	_rebuild_blocked()
	floor_view.queue_redraw()
	wall_view.queue_redraw()


func _init_enemy(e: Dictionary) -> void:
	e["next"] = null
	e["prev"] = -1
	e["linger"] = 0.0
	e["dmap"] = null
	e["max_hp"] = float(D.MAX_HP.get(e.type, 100))
	e["hp"] = e.max_hp
	e["slow_t"] = 0.0
	e["bar_t"] = 0.0
	e["reveal"] = 0.0   # glows for a moment when a sound wave reaches it


## The grid sound travels over: 4 x 4 cells per maze tile, each marked wall or open.
func _rebuild_blocked() -> void:
	var q = T / CELL
	fw = gw * q
	fh = gh * q
	blocked = PackedByteArray()
	blocked.resize(fw * fh)
	for ty in gh:
		for tx in gw:
			if not is_wall_t(tx, ty):
				continue
			for y in q:
				for x in q:
					blocked[(ty * q + y) * fw + tx * q + x] = 1


func start_level(new_seed: bool) -> void:
	var c: Dictionary
	if mode != "story":
		c = endless_cfg(endless_round)
		if new_seed:
			cur_seed = randi()
	elif wizard_stop > 0:
		c = D.WIZARD_CFG
		cur_seed = 700 + wizard_stop
	else:
		c = D.LEVELS[level_idx]
		cur_seed = c.seed
	_clear_effects()
	build_level(c, cur_seed)
	player = Vector2(1.5 * T, 1.5 * T)
	cam = player
	intro_t = 5.5
	note_t = 0.0
	kill_t = 0.0
	exit_hint_t = 0.0
	level_time = 0.0
	danger = 0.0
	clap_cd = 0.0
	whisper_cd = 0.0
	shake = 0.0
	level_claps = 0
	level_alerts = 0
	ambient_t = randf_range(3, 6)
	state = "play"
	sfx.start_level_audio(cfg.surf, exit_pos)


func _clear_effects() -> void:
	for i in waves.size():
		waves[i] = null
	flying = []
	water_ripples = []


func next_level() -> void:
	if mode == "story":
		if wizard_stop == 0 and D.WIZARD_AFTER.has(level_idx):
			wizard_stop = D.WIZARD_AFTER.find(level_idx) + 1
			save.depth = maxi(save.depth, level_idx + 2)
			save.atWizard = wizard_stop
			persist()
			start_level(true)
			return
		wizard_stop = 0
		save.atWizard = 0
		if level_idx >= D.LEVELS.size() - 1:
			save.completed = true
			save.depth = D.LEVELS.size()
			unlock_achievement("story_complete")
			persist()
			state = "ending"
			title_t = 0.0
			has_level = false
			floor_view.queue_redraw()
			wall_view.queue_redraw()
			_clear_effects()
			sfx.stop_level_audio()
			return
		level_idx += 1
		save.depth = maxi(save.depth, level_idx + 1)
		if level_idx == 1:
			unlock_achievement("first_descent")
		persist()
	else:
		endless_round += 1
		save.endlessBest = maxi(save.endlessBest, endless_round - 1)
		if endless_round > 5:
			unlock_achievement("endless_5")
		if endless_round > 10:
			unlock_achievement("endless_10")
		persist()
	start_level(true)


func to_title() -> void:
	state = "title"
	wizard_stop = 0
	has_level = false
	floor_view.queue_redraw()
	wall_view.queue_redraw()
	enemies = []
	_clear_effects()
	cam = Vector2.ZERO
	sfx.stop_level_audio()


# ================================================================ sound waves
## Start a sound wave at `pos`.
##
## Sound does not travel in straight lines through a maze: it runs along the corridors and
## bends round corners. So for each wave we work out, for every open spot within reach, how
## far sound must travel through the passages to get there. The wave front is simply all the
## spots at the same travel distance, and it reaches creatures and objects when it gets to them.
func spawn_ripple(pos: Vector2, o: Dictionary, src = null, alpha_mul := 1.0) -> void:
	var w = { "origin": pos, "r": 0.0, "max_r": float(o.max_r), "speed": float(o.speed),
		"strength": o.get("light", o.alpha) * alpha_mul, "kind": o.get("kind", "normal"), "src": src,
		"hurts": o.get("hurts", false), "tail": float(o.speed) * AFTERGLOW * (1.4 if has_upgrade("phosphor") else 1.0) * o.get("tail", 1.0),
		"dist": null, "tex": blank_field, "radial": not has_level, "hit": [], "chime_done": false, "secret_done": false }
	if has_level:
		_compute_field(w)
	var slot = STEP_SLOT
	if not o.get("step", false):
		# use a free slot, or replace the wave that is furthest along
		slot = 0
		var best = -1.0
		for i in STEP_SLOT:
			if waves[i] == null:
				slot = i
				break
			var age = waves[i].r / waves[i].max_r
			if age > best:
				best = age
				slot = i
	waves[slot] = w


## Fill in the travel distance from the wave's origin to every cell it can reach.
## (Dijkstra's shortest-path search, using buckets: straight steps cost 10, diagonal steps 14.)
func _compute_field(w: Dictionary) -> void:
	var dist = PackedInt32Array()
	dist.resize(fw * fh)
	dist.fill(1 << 30)
	var ox = clampi(floori(w.origin.x / CELL), 0, fw - 1)
	var oy = clampi(floori(w.origin.y / CELL), 0, fh - 1)
	var start = oy * fw + ox
	var limit = int(w.max_r / CELL * 10.0)
	var buckets = []
	buckets.resize(limit + 16)
	if blocked[start] == 0:
		dist[start] = 0
		buckets[0] = PackedInt32Array([start])
	for b in limit + 1:
		var cells = buckets[b]
		if cells == null:
			continue
		for c in cells:
			if dist[c] != b:
				continue
			var x = c % fw
			var y = c / fw
			var l = x > 0
			var r = x < fw - 1
			var u = y > 0
			var d = y < fh - 1
			var ol = l and blocked[c - 1] == 0
			var o_r = r and blocked[c + 1] == 0
			var ou = u and blocked[c - fw] == 0
			var od = d and blocked[c + fw] == 0
			for k in 8:
				var n = -1
				var cost = 10
				match k:
					0: if l: n = c - 1
					1: if r: n = c + 1
					2: if u: n = c - fw
					3: if d: n = c + fw
					4: if ol and ou: n = c - fw - 1
					5: if o_r and ou: n = c - fw + 1
					6: if ol and od: n = c + fw - 1
					7: if o_r and od: n = c + fw + 1
				if n < 0:
					continue
				if k >= 4:
					cost = 14
				var nd = b + cost
				if nd >= dist[n] or nd > limit:
					continue
				dist[n] = nd
				if blocked[n] == 1:
					continue   # the face of a wall is reached (so it lights up) but sound goes no further
				if buckets[nd] == null:
					buckets[nd] = PackedInt32Array()
				buckets[nd].append(n)
	# pack the distances (in pixels) into a small texture for the light shader
	var bytes = PackedByteArray()
	bytes.resize(fw * fh * 2)
	var px = PackedFloat32Array()
	px.resize(fw * fh)
	var scale = CELL / 10.0
	for i in fw * fh:
		var v = dist[i] * scale if dist[i] < (1 << 30) else FAR
		px[i] = v
		bytes.encode_half(i * 2, v)
	w.dist = px
	w.tex = ImageTexture.create_from_image(Image.create_from_data(fw, fh, false, Image.FORMAT_RH, bytes))


## How far sound from wave `w` has to travel to reach world position `p` (FAR if it cannot)
func wave_dist(w: Dictionary, p: Vector2) -> float:
	if w.radial:
		return p.distance_to(w.origin)
	var x = floori(p.x / CELL)
	var y = floori(p.y / CELL)
	if x < 0 or y < 0 or x >= fw or y >= fh:
		return FAR
	return w.dist[y * fw + x]








func update_ripples(dt: float) -> void:
	for i in waves.size():
		var w = waves[i]
		if w == null:
			continue
		w.r += w.speed * dt
		if w.r > w.max_r + w.tail * 4.0:
			waves[i] = null
			continue
		if not has_level or w.radial:
			continue
		var front = minf(w.r, w.max_r)

		# the wave reaches the chime
		if chime != null and not w.chime_done and not is_same(w.src, chime) and chime.cooldown <= 0.0 and wave_dist(w, chime.pos) <= front:
			w.chime_done = true
			trigger_chime()

		# the wave reaches the way down
		if wave_dist(w, exit_pos) <= front:
			exit_seen = 1.0
			exit_floor = 0.35

		# a strong clap cracks open a secret wall
		if secret != null and not secret.broken:
			var best = FAR
			for d in DIRS:
				best = minf(best, wave_dist(w, secret.pos + Vector2(d) * T * 0.75))
			if best <= front:
				var inten = w.strength * (1.0 - 0.6 * best / w.max_r)
				secret.seen = maxf(secret.seen, inten)
				if w.hurts and inten > 0.6 and not w.secret_done:
					w.secret_done = true
					_break_secret()

		# the wave reaches a creature
		for e in enemies.duplicate():
			if is_same(e, w.src) or w.hit.has(e):
				continue
			var d2 = wave_dist(w, e.pos)
			if d2 > front:
				continue
			w.hit.append(e)
			e.reveal = 1.0
			if e.type == "sleeper" and e.sleep != "rampage":
				disturb_sleeper(e, 100.0 if w.kind == "red" else (80.0 if w.kind == "gold" else (70.0 if w.hurts else 15.0)))
			if w.hurts:
				hurt(e, d2)

	for k in range(water_ripples.size() - 1, -1, -1):
		var wr = water_ripples[k]
		wr.r += 28.0 * dt
		wr.alpha -= dt * 0.7
		if wr.alpha <= 0.0 or wr.r >= wr.max_r:
			water_ripples.remove_at(k)


func _break_secret() -> void:
	secret.broken = true
	g[secret.tile.y * gw + secret.tile.x] = 0
	shake = maxf(shake, 6.0)
	sfx.play("kill", secret.pos)
	kill_text = "A secret passage cracked open!"
	kill_t = 3.5
	unlock_achievement("secret_finder")
	save.stats.secrets += 1
	persist()
	_rebuild_blocked()
	floor_view.queue_redraw()
	wall_view.queue_redraw()
	spawn_ripple(secret.pos, { "max_r": 180.0, "speed": 200.0, "alpha": 0.8, "light": 0.6 })


const WAVE_COL := { "normal": Color(0.92, 0.96, 1.0), "red": Color(1.0, 0.3, 0.3), "gold": Color(1.0, 0.84, 0.4) }

## Hand the light shader everything it needs each frame: the waves and the small steady glows.
func update_overlay(dt: float) -> void:
	var wave = PackedVector4Array()
	var wcol = PackedColorArray()
	var worigin = PackedVector2Array()
	for i in waves.size():
		var w = waves[i]
		if w == null:
			wave.append(Vector4.ZERO)
			wcol.append(Color(0, 0, 0, 0))
			worigin.append(Vector2.ZERO)
			continue
		wave.append(Vector4(w.r, w.max_r, w.strength, w.tail))
		wcol.append(Color(WAVE_COL[w.kind], 1.0 if w.radial else 0.0))
		worigin.append(w.origin)
		overlay_mat.set_shader_parameter("f%d" % i, w.tex)
	overlay_mat.set_shader_parameter("wave", wave)
	overlay_mat.set_shader_parameter("wcol", wcol)
	overlay_mat.set_shader_parameter("worigin", worigin)

	# small steady lights: the player, the way down, the chime, the wizard, creatures
	var glow = PackedVector4Array()
	var playing = has_level and state != "title"
	if playing:
		if state != "dead":
			glow.append(Vector4(player.x, player.y, 78.0, (0.36 + 0.04 * sin(time * 2.2)) * (0.75 if is_sneaking() else 1.0)))
		if exit_seen > 0.01:
			glow.append(Vector4(exit_pos.x, exit_pos.y, 64.0, exit_seen * 0.7 * (0.75 + 0.25 * sin(time * 3.0))))
		if chime != null:
			glow.append(Vector4(chime.pos.x, chime.pos.y, 90.0 if chime.ringing > 0.0 else 40.0, (0.8 + 0.2 * sin(time * 15.0)) if chime.ringing > 0.0 else 0.14))
		if wizard_pos != null:
			glow.append(Vector4(wizard_pos.x, wizard_pos.y, 300.0, 0.95 + 0.05 * sin(time * 2.0)))
		if upgrade_item != null and not upgrade_item.taken:
			glow.append(Vector4(upgrade_item.pos.x, upgrade_item.pos.y, 34.0, 0.25))
		for e in enemies:
			e.reveal = maxf(0.0, e.reveal - dt / 1.2)
			var own = 0.0
			if e.type == "drifter":
				own = 0.22
			elif e.type == "sleeper":
				own = 0.7 if e.sleep == "rampage" else (0.4 if e.sleep == "awakening" else 0.0)
			var strength = maxf(own, e.reveal * 0.8)
			if strength > 0.01 and glow.size() < 16:
				glow.append(Vector4(e.pos.x, e.pos.y, e.r * 4.0, strength))
	var n = glow.size()
	glow.resize(16)
	overlay_mat.set_shader_parameter("glow", glow)
	overlay_mat.set_shader_parameter("glow_n", n)
	overlay_mat.set_shader_parameter("ambient", 1.0 if light_mode else (0.6 if (playing and cfg.get("safe", false)) else 0.0))

	# the darkness covers the level, or the whole screen when there is no level
	var origin = Vector2.ZERO
	var size = Vector2(gw, gh) * T
	if not has_level:
		size = Vector2(W, H) / ZOOM + Vector2(64, 64)
		origin = cam - size / 2.0
	else:
		# reach a little past the level so the black beyond its edge is covered too
		origin = cam - Vector2(W, H) / ZOOM / 2.0 - Vector2(32, 32)
		size = Vector2(W, H) / ZOOM + Vector2(64, 64)
	overlay.position = origin
	overlay.scale = size
	overlay_mat.set_shader_parameter("rect_origin", origin)
	overlay_mat.set_shader_parameter("rect_size", size)
	overlay_mat.set_shader_parameter("level_size", Vector2(maxi(gw, 1), maxi(gh, 1)) * T)


# ================================================================ creatures
func hurt(e: Dictionary, dist: float) -> void:
	var rng_ = 8.0 * T
	if dist > rng_:
		return
	damage(e, 32.0 - 12.0 * (dist / rng_))


func damage(e: Dictionary, amount: float) -> void:
	e.hp -= amount
	e.slow_t = 2.0
	e.bar_t = 3.5
	if e.hp <= 0.0:
		enemies.erase(e)
		save.xp += D.XP_REWARD.get(e.type, 0)
		persist()
		kill_text = "%s is destroyed." % D.NAMES[e.type]
		kill_t = 3.5
		sfx.play("kill", e.pos)
	else:
		sfx.play("hurt", e.pos)


func make_noise(at: Vector2, loud: float, src = null) -> void:
	if not has_level:
		return
	var ti = tile_idx(at)
	if ti < 0 or ti >= g.size() or g[ti] == 1:
		return
	for e in enemies:
		if is_same(e, src):
			continue
		var reach = loud if clear_line(e.pos, at) else loud * 0.52
		var dist: float = e.pos.distance_to(at)
		if dist >= reach:
			continue
		if e.type == "listener":
			level_alerts += 1
			e.state = "alert"
			e.alert_t = 0.45
			e.dmap = bfs(ti)
			e.linger = 0.0
			e.search_t = 0.0
			sfx.play("growl", e.pos, 0.6)
		elif e.type == "mimic":
			e.dmap = bfs(ti)
			e.linger = 0.0
			e.mimic = "stalk"
		elif e.type == "sleeper":
			disturb_sleeper(e, (1.0 - dist / reach) * (90.0 if loud > 400.0 else 40.0))


func disturb_sleeper(e: Dictionary, amount: float) -> void:
	if e.sleep == "rampage":
		return
	e.agitation = minf(100.0, e.agitation + amount)
	if e.agitation >= 80.0 and e.sleep == "dormant":
		e.sleep = "awakening"
		e.wake_t = 1.1
		shake = maxf(shake, 7.0)
		sfx.play("sleeper_wake", e.pos)


func trigger_chime() -> void:
	if chime == null or chime.cooldown > 0.0:
		return
	chime.cooldown = 7.0
	chime.ringing = 2.5
	shake = maxf(shake, 6.0)
	sfx.play("chime", chime.pos)
	spawn_ripple(chime.pos, D.CHIME_WAVE, chime)
	make_noise(chime.pos, 850.0, chime)
	if door != null and not door.open:
		door.open = true
		sfx.play("door", door.pos)
		kill_text = "The acoustic chime resonated. The sealed bulkhead opens!"
		kill_t = 4.0
		_rebuild_blocked()
		wall_view.queue_redraw()
	save.stats.chimes += 1
	if save.stats.chimes >= 3:
		unlock_achievement("chime_master")
	persist()


func choose_next(e: Dictionary) -> void:
	var i = tile_idx(e.pos)
	var opts = open_neighbors(i)
	if e.dmap != null:
		var dm: PackedInt32Array = e.dmap
		if dm[i] == 0:
			e.dmap = null
			if e.type == "listener":
				e.state = "search"
				e.search_t = 3.5
			elif e.type == "sleeper":
				e.sleep = "calming"
				e.linger = 4.0
			else:
				e.linger = randf_range(1.5, 3.0)
			return
		var best = -1
		var bd = 1000000000
		for j in opts:
			if dm[j] >= 0 and dm[j] < bd:
				bd = dm[j]
				best = j
		if best >= 0:
			e.prev = i
			e.next = center_of(best)
			return
		e.dmap = null
	if e.type == "mimic":
		return
	if e.type == "sleeper":
		if e.sleep == "calming":
			e.sleep = "dormant"
			e.agitation = 0.0
		return
	if e.type == "listener" and e.state == "search":
		if not opts.is_empty():
			e.prev = i
			e.next = center_of(opts.pick_random())
		return
	var c = opts.filter(func(j): return j != e.prev)
	if c.is_empty():
		c = opts
	if c.is_empty():
		return
	if e.type == "listener" and randf() < 0.16:
		e.linger = randf_range(1.2, 2.5)
	e.prev = i
	e.next = center_of(c.pick_random())


func update_enemies(dt: float) -> void:
	for e in enemies.duplicate():
		e.hp = minf(e.max_hp, e.hp + 4.0 * dt)
		e.slow_t -= dt
		e.bar_t -= dt

		if e.type == "listener":
			if e.alert_t > 0.0:
				e.alert_t -= dt
				continue   # stops for a moment to work out where the sound came from
			if e.search_t > 0.0:
				e.search_t -= dt
				if e.search_t <= 0.0:
					e.state = "patrol"

		if e.type == "sleeper":
			if e.sleep == "dormant":
				e.snore_t -= dt
				if e.snore_t <= 0.0:
					e.snore_t = randf_range(3.5, 6.0)
					sfx.play("sleeper_breathe", e.pos, 0.45)
				e.agitation = maxf(0.0, e.agitation - dt * 4.0)
				continue
			elif e.sleep == "awakening":
				e.wake_t -= dt
				if e.wake_t <= 0.0:
					e.sleep = "rampage"
					e.dmap = bfs(tile_idx(player))
					save.stats.sleepersAwakened += 1
					persist()
				continue
			elif e.sleep == "calming":
				e.agitation = maxf(0.0, e.agitation - dt * 15.0)
				if e.agitation <= 0.0:
					e.sleep = "dormant"
					e.dmap = null

		if e.linger > 0.0:
			e.linger -= dt
		else:
			if e.next == null:
				choose_next(e)
			if e.next != null:
				var base: float = e.wander
				if e.type == "sleeper" and e.sleep == "rampage":
					base = e.hunt
				elif e.dmap != null:
					base = e.hunt
				elif e.type == "listener" and e.state == "search":
					base = e.wander * 1.3
				var sp: float = base * (0.45 if e.slow_t > 0.0 else 1.0)
				var to: Vector2 = e.next - e.pos
				if to.length() <= sp * dt:
					e.pos = e.next
					e.next = null
				else:
					e.pos += to.normalized() * sp * dt

		var pd: float = e.pos.distance_to(player)
		var blind_miss: bool = e.type == "listener" and not player_loud
		if e.kills and not blind_miss and pd < e.r + PLAYER_R - 2.0:
			die(e.type)
			return

		if e.type == "drifter":
			e.shriek_cd -= dt
			if pd < e.r + PLAYER_R + 5.0 and e.shriek_cd <= 0.0:
				e.shriek_cd = 6.0
				spawn_ripple(e.pos, D.SHRIEK, e)
				make_noise(e.pos, 820.0, e)
				shake = 10.0
				sfx.play("shriek", e.pos)

		if e.type == "mimic":
			e.clap_t -= dt
			if e.clap_t <= 0.0:
				e.clap_t = randf_range(5, 9)
				if pd < 650.0:
					if randf() < 0.6:
						spawn_ripple(e.pos, D.CLAP.merged({ "hurts": false }), e)
						make_noise(e.pos, 480.0, e)
						sfx.play("clap", e.pos)
					else:
						spawn_ripple(e.pos, D.PEBBLE, e)
						make_noise(e.pos, 350.0, e)
						sfx.play("pebble", e.pos)

	if chime != null:
		chime.cooldown = maxf(0.0, chime.cooldown - dt)
		chime.ringing = maxf(0.0, chime.ringing - dt)


func die(killer := "unknown") -> void:
	if state != "play" or god_mode:
		return
	state = "dead"
	dead_t = 2.8
	flash = 1.0
	flash_red = true
	shake = 14.0
	save.stats.deaths += 1
	persist()
	match killer:
		"sleeper": kill_text = "The Sleeper was disturbed."
		"mimic": kill_text = "The Mimic fooled you in the dark."
		"drifter": kill_text = "The Drifter summoned the shadows."
		_: kill_text = "It heard you."
	sfx.play("death")
	sfx.stop_level_audio()


# ================================================================ player actions
func is_sneaking() -> bool:
	return keys.get("KeyC", false) or sneak_toggle or (joy_id != -1 and joy.length() < 0.55)


func clap() -> void:
	if clap_cd > 0.0:
		return
	clap_cd = CLAP_CD
	level_claps += 1
	save.stats.claps += 1
	persist()
	spawn_ripple(player, D.CLAP)
	exit_hint_t = 1.8
	make_noise(player, 470.0)
	shake = maxf(shake, 3.5)
	sfx.play("clap", player)
	if has_upgrade("crystal"):
		sfx.play("compass", exit_pos)


func whisper() -> void:
	if whisper_cd > 0.0:
		return
	whisper_cd = 0.38
	save.stats.whispers += 1
	spawn_ripple(player, D.WHISPER)
	make_noise(player, 115.0)
	sfx.play("whisper", player)


func throw_pebble(target: Vector2) -> void:
	if not has_level or pebbles <= 0:
		return
	var to = target - player
	if to.length() < 4.0:
		return
	pebbles -= 1
	save.stats.pebbles += 1
	flying.append({ "pos": player, "vel": to.normalized() * 390.0, "left": minf(to.length(), 340.0) })
	sfx.play("toss", player)


func update_pebbles(dt: float) -> void:
	for k in range(flying.size() - 1, -1, -1):
		var p = flying[k]
		var np: Vector2 = p.pos + p.vel * dt
		p.left -= 390.0 * dt
		if is_wall(np) or p.left <= 0.0:
			if not is_wall(np):
				p.pos = np
			flying.remove_at(k)
			spawn_ripple(p.pos, D.PEBBLE)
			make_noise(p.pos, 430.0)
			sfx.play("pebble", p.pos)
			if chime != null and p.pos.distance_to(chime.pos) < 20.0:
				trigger_chime()
			for e in enemies:
				if e.type == "listener" and e.pos.distance_to(p.pos) < 320.0:
					unlock_achievement("pebble_trick")
		else:
			p.pos = np


func collides(p: Vector2) -> bool:
	var r = PLAYER_R
	return is_wall(p + Vector2(-r, -r)) or is_wall(p + Vector2(r, -r)) or is_wall(p + Vector2(-r, r)) or is_wall(p + Vector2(r, r))


func shoot(target: Vector2) -> void:
	var dir = (target - player).normalized()
	var p = player
	var hit = null
	for s in 160:
		p += dir * 4.0
		if is_wall(p):
			break
		for e in enemies:
			if p.distance_to(e.pos) < e.r:
				hit = e
		if hit != null:
			break
	shots.append({ "a": player, "b": p, "life": 1.0 })
	if hit != null:
		damage(hit, 100.0)


# ================================================================ main loop
func _process(delta: float) -> void:
	var dt = minf(0.033, delta)
	update_game(dt)
	update_overlay(dt)
	cam_node.zoom = Vector2(ZOOM, ZOOM) * PX
	cam_node.position = cam
	var sh = shake if save.settings.screenShake else 0.0
	cam_node.offset = Vector2(randf_range(-sh, sh), randf_range(-sh, sh)) / ZOOM
	entity_view.queue_redraw()
	echo_view.queue_redraw()
	hud.queue_redraw()


func held(code: String) -> bool:
	return keys.get(code, false)


func update_game(dt: float) -> void:
	time += dt
	console_msg_t -= dt
	for k in range(shots.size() - 1, -1, -1):
		shots[k].life -= dt * 6.0
		if shots[k].life <= 0.0:
			shots.remove_at(k)
	shake *= pow(0.002, dt)
	flash = maxf(0.0, flash - dt * 0.8)

	if toast_timer > 0.0:
		toast_timer -= dt
	elif not toast_queue.is_empty():
		toast_current = toast_queue.pop_front()
		toast_timer = 4.0
	else:
		toast_current = null

	if state == "title" or state == "ending":
		title_t -= dt
		if title_t <= 0.0:
			title_t = 1.5
			spawn_ripple(Vector2(randf_range(-W / 3, W / 3), randf_range(-H / 5, H / 5)) / ZOOM, { "max_r": 360.0, "speed": 130.0, "alpha": 0.45, "tail": 0.25 })
		update_ripples(dt)
		return
	if state in ["pause", "journal", "achievements", "settings", "level_select", "credits"] or console_open or not has_level:
		return

	update_ripples(dt)
	exit_seen = maxf(exit_floor, exit_seen - dt / 3.0)
	if secret != null:
		secret.seen = maxf(0.0, secret.seen - dt / 5.0)

	if state == "dead":
		dead_t -= dt
		if dead_t <= 0.0:
			start_level(false)
		return
	if state == "clear":
		clear_t -= dt
		if clear_t <= 0.0:
			next_level()
		return

	level_time += dt
	save.stats.timePlayed += dt
	intro_t -= dt
	note_t -= dt
	kill_t -= dt
	exit_hint_t -= dt
	clap_cd -= dt
	whisper_cd -= dt
	ambient_t -= dt
	if ambient_t <= 0.0:
		ambient_t = randf_range(4, 9)
		var ang = randf() * TAU
		sfx.play("ambient_%d" % cfg.surf, player + Vector2(cos(ang), sin(ang)) * randf_range(120, 360), 0.5)

	# player movement
	var m = Vector2.ZERO
	if held("KeyA") or held("ArrowLeft"): m.x -= 1
	if held("KeyD") or held("ArrowRight"): m.x += 1
	if held("KeyW") or held("ArrowUp"): m.y -= 1
	if held("KeyS") or held("ArrowDown"): m.y += 1
	m += joy
	var sneaking = is_sneaking()
	var moving = m.length() > 0.2
	if moving:
		var sp = (68.0 if has_upgrade("soles") else 55.0) if sneaking else 118.0
		var step = m.normalized() * sp * dt
		if not collides(player + Vector2(step.x, 0)): player.x += step.x
		if not collides(player + Vector2(0, step.y)): player.y += step.y
		save.stats.steps += 1
		if not sneaking:
			step_t -= dt
			if step_t <= 0.0:
				step_t = 0.38
				var vol = 0.6 if has_upgrade("soles") else 1.0
				spawn_ripple(player, D.STEP, null, vol)
				make_noise(player, (60.0 if cfg.surf == D.SURF_SOFT else 150.0) * vol)
				sfx.play("step_%d" % cfg.surf, player, vol)
				if cfg.surf == D.SURF_WATER:
					water_ripples.append({ "pos": player, "r": 2.0, "max_r": 18.0, "alpha": 0.6 })
	else:
		step_t = 0.1
	player_loud = moving and not sneaking and cfg.surf != D.SURF_SOFT

	gun_cd -= dt
	if has_gun and mouse_held and gun_cd <= 0.0:
		gun_cd = 0.2
		shoot(screen_to_world(mouse_pos))

	update_pebbles(dt)
	update_enemies(dt)
	if state != "play":
		return

	# reached the way down
	if player.distance_to(exit_pos) < 15.0:
		state = "clear"
		clear_t = 1.9
		flash = 1.0
		flash_red = false
		sfx.play("descend")
		sfx.stop_level_audio()
		if cfg.get("wizard", false):
			return
		if level_claps == 0:
			unlock_achievement("silent_run")
		if level_alerts == 0 and level_idx >= 2:
			unlock_achievement("ghost")
		var sleepers = enemies.filter(func(e): return e.type == "sleeper")
		if not sleepers.is_empty() and not sleepers.any(func(e): return e.sleep == "rampage"):
			unlock_achievement("sleeper_mercy")
		if mode == "story":
			var key = str(level_idx)
			if not save.best.has(key) or level_time < save.best[key]:
				save.best[key] = level_time
			persist()
		return

	if note_pos != null and not note_taken and player.distance_to(note_pos) < 16.0:
		note_taken = true
		note_obj = D.NOTES[note_idx]
		note_t = 9.5
		if not save.notes.has(note_idx):
			save.notes.append(note_idx)
			if save.notes.size() >= D.NOTES.size():
				unlock_achievement("cartographer")
			persist()
		sfx.play("note")

	if upgrade_item != null and not upgrade_item.taken and player.distance_to(upgrade_item.pos) < 16.0:
		upgrade_item.taken = true
		unlock_upgrade(upgrade_item.id)

	danger = 0.0
	for e in enemies:
		if not e.kills:
			continue
		var mul = 1.2 if (e.type == "sleeper" and e.sleep == "rampage") else (1.0 if e.dmap != null else 0.6)
		danger = maxf(danger, clampf(1.0 - e.pos.distance_to(player) / 380.0, 0.0, 1.0) * mul)
	if danger > 0.05:
		hb_t -= dt
		if hb_t <= 0.0:
			hb_t = 1.3 - danger * 0.9
			sfx.play("heartbeat", null, 0.25 + danger * 0.75)
	else:
		hb_t = 0.0

	sfx.update_listener(player, exit_pos, not clear_line(player, exit_pos))
	cam += (player - cam) * minf(1.0, dt * 6.0)


func screen_to_world(p: Vector2) -> Vector2:
	return (p - Vector2(W, H) / 2.0) / ZOOM + cam


# ================================================================ drawing the world
func theme_name() -> String:
	return cfg.theme if has_level and D.THEMES.has(cfg.theme) else "entrance"


func draw_floor(c: CanvasItem) -> void:
	if not has_level:
		return
	var th = theme_name()
	var tiles: Texture2D = tex["tile_" + th]
	for ty in gh:
		for tx in gw:
			if g[ty * gw + tx] == 1:
				continue
			var n = tx * 7 + ty * 13
			var rect = Rect2(tx * T, ty * T, T, T)
			var art = tex.get("floor_%s_%d" % [th, [0, 1, 0, 1, 2][n % 5]])
			if art != null:
				c.draw_texture_rect(art, rect, false)
			else:
				c.draw_texture_rect_region(tiles, rect, Rect2((n % 3) * 16, 0, 16, 16))


func _hash01(n: float) -> float:
	var v = sin(n * 127.1) * 43758.5453
	return v - floorf(v)


func draw_walls(c: CanvasItem) -> void:
	if not has_level:
		return
	var th = theme_name()
	var strip = tex.get("wall_" + th)
	var style: Dictionary = D.THEMES[th]
	for ty in gh:
		for tx in gw:
			if not is_wall_t(tx, ty):
				continue
			for d in 4:
				if is_wall_t(tx + DIRS[d].x, ty + DIRS[d].y):
					continue
				# the two ends of this wall edge, and the direction pointing into the wall
				var x = float(tx * T)
				var y = float(ty * T)
				var a = Vector2(x, y)
				var b = Vector2(x, y + T)
				var nrm = Vector2(1, 0)
				if d == 0:
					a.x += T; b.x += T; nrm = Vector2(-1, 0)
				elif d == 2:
					a.y += T; b = Vector2(x + T, y + T); nrm = Vector2(0, -1)
				elif d == 3:
					b = Vector2(x + T, y); nrm = Vector2(0, 1)
				var seed_v = tx * 31 + ty * 17 + d * 7
				if strip != null:
					# where the path turns, the horizontal band runs on to fill the blank corner
					var e0 = 0.0
					var e1 = 0.0
					if d >= 2:
						var oy: int = DIRS[d].y
						if is_wall_t(tx - 1, ty) and is_wall_t(tx - 1, ty + oy): e0 = WALL_TH
						if is_wall_t(tx + 1, ty) and is_wall_t(tx + 1, ty + oy): e1 = WALL_TH
					var u = (b - a) / T
					var length = T + e0 + e1
					var sw = float(strip.get_width())
					var sh = float(strip.get_height())
					var seg = minf(sh, sw * length / WALL_TH)
					var sy = floorf(_hash01(seed_v) * (sh - seg))
					c.draw_set_transform_matrix(Transform2D(-nrm, u, a + nrm * WALL_TH - u * e0))
					c.draw_texture_rect_region(strip, Rect2(0, 0, WALL_TH, length), Rect2(0, sy, sw, seg))
					c.draw_set_transform_matrix(Transform2D.IDENTITY)
				else:
					var pts = PackedVector2Array([a])
					if style.style == "rock":
						for i in range(1, 5):
							pts.append(a.lerp(b, i / 5.0) + nrm * _hash01(seed_v + i) * 4.0)
					pts.append(b)
					c.draw_polyline(pts, style.edge, 1.6, true)
					if style.style == "brick":
						for i in range(1, 4):
							var p = a.lerp(b, i / 4.0)
							c.draw_line(p, p + nrm * 3.5, style.edge, 1.4, true)
	if door != null:
		var fr = 1 if door.open else 0
		c.draw_texture_rect_region(tex.spr_door, Rect2(door.pos - Vector2(T, T) / 2.0, Vector2(T, T)), Rect2(fr * 16, 0, 16, 16))


func _sprite(c: CanvasItem, name: String, pos: Vector2, size: float, fps := 6.0, off := 0.0, alpha := 1.0) -> void:
	var t: Texture2D = tex["spr_" + name]
	var fh = t.get_height()
	var frames = t.get_width() / fh
	var f = int(time * fps + off) % frames
	c.draw_texture_rect_region(t, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), Rect2(f * fh, 0, fh, fh), Color(1, 1, 1, alpha))


func draw_entities(c: CanvasItem) -> void:
	if not has_level:
		return
	_sprite(c, "exit", exit_pos, 28, 2)
	if note_pos != null and not note_taken:
		_sprite(c, "note", note_pos, 20)
	if chime != null:
		_sprite(c, "chime", chime.pos, 26, 12.0 if chime.ringing > 0.0 else 0.0)
	if secret != null and not secret.broken:
		_sprite(c, "crack", secret.pos, T, 0)
	if upgrade_item != null and not upgrade_item.taken:
		_sprite(c, upgrade_item.id, upgrade_item.pos, 22, 3)
	if wizard_pos != null:
		_sprite(c, "wizard", wizard_pos, 40, 2)
	for e in enemies:
		var name: String = e.type
		var fps = 6.0
		if e.type == "sleeper":
			var st = 2 if e.sleep == "rampage" else (1 if e.sleep == "awakening" else 0)
			name = "sleeper%d" % st
			fps = [1.0, 6.0, 10.0][st]
		_sprite(c, name, e.pos, e.r * 3.0, fps, e.r)
	for p in flying:
		_sprite(c, "pebble", p.pos, 14)
	if state != "dead":
		_sprite(c, "player%d" % (1 if save.settings.character else 0), player, 21.0 if is_sneaking() else 25.0, 8.0 if player_loud else 0.0)


## Things drawn on top of the darkness: water rings, gun tracers, creature health bars.
## (The sound waves themselves are drawn by the light shader.)
func draw_echo(c: CanvasItem) -> void:
	for wr in water_ripples:
		c.draw_arc(wr.pos, wr.r, 0, TAU, 24, Color(0.6, 0.9, 1.0, wr.alpha), 1.0, true)
	for s in shots:
		c.draw_line(s.a, s.b, Color(1, 1, 1, s.life * 0.9), 1.2)
	for e in enemies:
		if e.hp < e.max_hp - 0.5 and e.bar_t > 0.0:
			var w = 44.0 if e.type == "mimic" else (36.0 if e.type == "sleeper" else 28.0)
			var top: Vector2 = e.pos + Vector2(-w / 2.0, -e.r - 12.0)
			var a2 = clampf(e.bar_t, 0.0, 1.0)
			c.draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.7 * a2))
			c.draw_rect(Rect2(top, Vector2(w * maxf(0.0, e.hp) / e.max_hp, 4)), Color(1, 0.23, 0.23, a2))


# ================================================================ input
const KEY_NAMES := {
	KEY_W: "KeyW", KEY_A: "KeyA", KEY_S: "KeyS", KEY_D: "KeyD", KEY_C: "KeyC", KEY_X: "KeyX", KEY_Z: "KeyZ", KEY_R: "KeyR",
	KEY_P: "KeyP", KEY_M: "KeyM", KEY_J: "KeyJ", KEY_Q: "KeyQ", KEY_N: "KeyN", KEY_E: "KeyE",
	KEY_UP: "ArrowUp", KEY_DOWN: "ArrowDown", KEY_LEFT: "ArrowLeft", KEY_RIGHT: "ArrowRight",
	KEY_SPACE: "Space", KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter", KEY_ESCAPE: "Escape", KEY_SHIFT: "ShiftLeft",
	KEY_BACKSPACE: "Backspace", KEY_QUOTELEFT: "Backquote",
}


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: String = KEY_NAMES.get(event.physical_keycode, "")
		if event.pressed:
			if console_open and code not in ["Escape", "Enter", "Backspace", "Backquote"]:
				if event.unicode >= 32 and console_text.length() < 40:
					console_text += char(event.unicode)
				return
			if code != "":
				if not event.echo or console_open:
					on_key(code)
				keys[code] = true
		elif code != "":
			keys[code] = false
	elif event is InputEventMouseMotion:
		mouse_pos = event.position / PX
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_down(event.position / PX)
			else:
				mouse_held = false
	elif event is InputEventScreenTouch:
		touch_mode = true
		var tp = event.position / PX
		if event.pressed:
			var b = hud.button_at(tp)
			if b != null:
				press_key(b.code)
			elif state == "play" and joy_id == -1 and tp.x < W * 0.45 and tp.y > H * 0.3 and not on_item_icons(tp):
				joy_id = event.index
				joy_origin = tp
				joy = Vector2.ZERO
			else:
				pointer_down(tp)
		else:
			if event.index == joy_id:
				joy_id = -1
				joy = Vector2.ZERO
			mouse_held = false
	elif event is InputEventScreenDrag and event.index == joy_id:
		joy = ((event.position / PX - joy_origin) / JOY_R).limit_length(1.0)


## A touch button acts like one quick key press
func press_key(code: String) -> void:
	on_key(code)
	keys[code] = false


func on_item_icons(p: Vector2) -> bool:
	return p.y / UIS > H / UIS - 66.0 and p.x / UIS < 22.0 + save.upgrades.size() * 48.0


func pointer_down(p: Vector2) -> void:
	mouse_pos = p
	var uy = p.y / UIS
	var uh = H / UIS
	if state == "title":
		var k = floori((uy - uh * 0.48 + 14.0) / 28.0)
		if k >= 0 and k < 8:
			menu_sel = k
			trigger_title_menu(k)
		return
	if state == "level_select":
		var k2 = floori((uy - uh * 0.32 + 15.0) / 30.0)
		if k2 >= 0 and k2 < D.LEVELS.size():
			menu_sel = k2
			if k2 < save.depth:
				mode = "story"
				wizard_stop = 0
				level_idx = k2
				start_level(true)
		return
	if state != "play" or console_open or on_item_icons(p):
		return
	if has_gun:
		mouse_held = true
		return
	throw_pebble(screen_to_world(p))


func on_key(code: String) -> void:
	if code == "Backquote":
		console_open = not console_open
		console_text = ""
		keys.clear()
		return
	if console_open:
		if code == "Escape":
			console_open = false
		elif code == "Enter":
			run_command(console_text)
			console_text = ""
			console_open = false
		elif code == "Backspace":
			console_text = console_text.left(-1)
		return
	if code == "KeyM":
		sfx.muted = not sfx.muted
		sfx.apply_volumes(save.settings)
		return

	var up = code == "ArrowUp" or code == "KeyW"
	var down = code == "ArrowDown" or code == "KeyS"
	var left = code == "ArrowLeft" or code == "KeyA"
	var right = code == "ArrowRight" or code == "KeyD"
	var ok = code == "Enter" or code == "Space"

	match state:
		"title":
			if up: menu_sel = (menu_sel + 7) % 8
			elif down: menu_sel = (menu_sel + 1) % 8
			elif ok: trigger_title_menu(menu_sel)
		"level_select":
			var n = D.LEVELS.size()
			if code == "Escape":
				state = "title"; menu_sel = 2
			elif up: menu_sel = (menu_sel + n - 1) % n
			elif down: menu_sel = (menu_sel + 1) % n
			elif ok and menu_sel < save.depth:
				mode = "story"; wizard_stop = 0; level_idx = menu_sel
				start_level(true)
		"journal":
			var n2 = D.NOTES.size()
			if code == "Escape":
				state = "title"; menu_sel = 4
			elif left: menu_sel = (menu_sel + n2 - 1) % n2
			elif right: menu_sel = (menu_sel + 1) % n2
		"achievements":
			if code == "Escape" or code == "Enter":
				state = "title"; menu_sel = 5
		"settings":
			if code == "Escape" or (ok and menu_sel == 5):
				state = "title"; menu_sel = 6
				persist()
			elif up: menu_sel = (menu_sel + 5) % 6
			elif down: menu_sel = (menu_sel + 1) % 6
			elif left: adjust_setting(menu_sel, -1)
			elif right or ok: adjust_setting(menu_sel, 1)
		"credits":
			if code == "Escape" or code == "Enter":
				state = "title"; menu_sel = 7
		"ending":
			if ok or code == "Escape":
				to_title()
		"pause":
			if code == "Escape" or code == "KeyP": state = "play"
			elif code == "KeyR": start_level(false)
			elif code == "KeyJ":
				state = "journal"; menu_sel = 0
			elif code == "KeyQ": to_title()
		"play":
			if code == "Escape" or code == "KeyP": state = "pause"
			elif code == "Space": clap()
			elif code == "ShiftLeft" or code == "KeyZ": whisper()
			elif code == "KeyX": sneak_toggle = not sneak_toggle
			elif code == "KeyR": start_level(false)


func trigger_title_menu(idx: int) -> void:
	match idx:
		0:
			mode = "story"
			level_idx = mini(save.depth, D.LEVELS.size()) - 1
			wizard_stop = save.atWizard
			if wizard_stop > 0:
				level_idx = D.WIZARD_AFTER[wizard_stop - 1]
			start_level(true)
		1:
			mode = "story"
			level_idx = 0
			wizard_stop = 0
			save.depth = 1
			save.atWizard = 0
			persist()
			start_level(true)
		2:
			state = "level_select"; menu_sel = 0
		3:
			if save.completed:
				mode = "endless"
				endless_round = 1
				start_level(true)
		4:
			state = "journal"; menu_sel = 0
		5:
			state = "achievements"
		6:
			state = "settings"; menu_sel = 0
		7:
			state = "credits"


func adjust_setting(idx: int, dir: int) -> void:
	var s: Dictionary = save.settings
	match idx:
		0: s.masterVol = clampf(s.masterVol + dir * 0.1, 0.0, 1.0)
		1: s.sfxVol = clampf(s.sfxVol + dir * 0.1, 0.0, 1.0)
		2: s.ambVol = clampf(s.ambVol + dir * 0.1, 0.0, 1.0)
		3: s.screenShake = not s.screenShake
		4: s.character = 0 if s.character else 1
	sfx.apply_volumes(s)
	persist()


# ================================================================ developer console
func run_command(raw: String) -> void:
	var parts = raw.strip_edges().to_lower().split(" ", false)
	if parts.is_empty():
		return
	var a = parts[1] if parts.size() > 1 else ""
	var b = parts[2] if parts.size() > 2 else ""
	console_msg_t = 4.5
	match parts[0]:
		"light_mode":
			light_mode = not light_mode
			console_msg = "light mode %s" % ("on" if light_mode else "off")
		"give_gun":
			has_gun = not has_gun
			console_msg = "gun equipped: click or hold to fire (100 dmg)" if has_gun else "gun removed"
		"god_mode":
			god_mode = not god_mode
			console_msg = "god mode %s" % ("on" if god_mode else "off")
		"tp":
			if not has_level:
				console_msg = "start a level first"
			elif collides(screen_to_world(mouse_pos)):
				console_msg = "cannot teleport into a wall"
			else:
				player = screen_to_world(mouse_pos)
				cam = player
				console_msg = "teleported"
		"unlock_all":
			save.depth = D.LEVELS.size()
			save.completed = true
			for i in D.NOTES.size():
				if not save.notes.has(i): save.notes.append(i)
			for u in D.UPGRADES:
				if not save.upgrades.has(u.id): save.upgrades.append(u.id)
			for ac in D.ACHIEVEMENTS:
				if not save.achievements.has(ac.id): save.achievements.append(ac.id)
			persist()
			console_msg = "all depths, notes, upgrades, and achievements unlocked"
		"spawn_sleeper":
			if not has_level:
				console_msg = "start a level first"
			else:
				var e = { "type": "sleeper", "pos": player + Vector2(40, 0), "r": 14.0, "hunt": 110.0, "wander": 0.0, "kills": true,
					"sleep": "dormant", "agitation": 0.0, "wake_t": 0.0, "snore_t": 2.0 }
				_init_enemy(e)
				enemies.append(e)
				console_msg = "sleeper spawned nearby"
		"next_level":
			if state != "play":
				console_msg = "start level first"
			else:
				next_level()
				console_msg = "skipped to next level"
		"add_pebbles":
			pebbles += 5
			console_msg = "+5 pebbles added"
		"level":
			var usage = "usage: level <1-%d>, level wizard <1-2> or level endless <round>" % D.LEVELS.size()
			if a == "endless" or a == "e":
				if b.to_int() < 1:
					console_msg = usage
				else:
					mode = "endless"
					wizard_stop = 0
					endless_round = b.to_int()
					start_level(true)
					console_msg = "jumped to endless round %d" % endless_round
			elif a == "wizard" or a == "w":
				mode = "story"
				wizard_stop = 2 if b.to_int() == 2 else 1
				level_idx = D.WIZARD_AFTER[wizard_stop - 1]
				start_level(false)
				console_msg = "jumped to the wizard's hollow (visit %d)" % wizard_stop
			elif a.to_int() >= 1 and a.to_int() <= D.LEVELS.size():
				mode = "story"
				wizard_stop = 0
				level_idx = a.to_int() - 1
				start_level(false)
				console_msg = "jumped to depth %d: %s" % [level_idx + 1, D.LEVELS[level_idx].name]
			else:
				console_msg = usage
		"help":
			console_msg = "commands: light_mode, give_gun, god_mode, tp, unlock_all, spawn_sleeper, next_level, add_pebbles, level, help"
		_:
			console_msg = "unknown command: %s (type help)" % parts[0]
