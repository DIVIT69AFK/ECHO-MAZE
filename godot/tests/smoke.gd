extends SceneTree
## Smoke test: plays through every level by moving the player onto each exit.
## Run with:  godot --headless --path . --script res://tests/smoke.gd
## Add  -- shots <folder>  (without --headless) to also save screenshots.

var game
var shots_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shots":
		shots_dir = args[1]
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	_run()

## wait n game frames' worth of time (at 60 per second)
func frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func shot(name: String) -> void:
	if shots_dir == "":
		return
	await frames(3)
	root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])

func _run() -> void:
	await frames(5)
	var log := []
	game.save.xp = 0
	game.mode = "story"
	game.level_idx = 0
	game.wizard_stop = 0
	game.start_level(false)
	for i in 11:
		if game.state != "play":
			break
		var name: String = game.cfg.theme
		game.enemies.clear()
		game.clap_cd = 0.0
		game.clap()
		await frames(40)
		await shot("level_%02d_%s" % [i, name])
		game.player = game.exit_pos
		await frames(150)
		log.append(name)
	print("STORY: ", " ".join(log), " -> ", game.state)

	# menus
	game.to_title()
	for st in ["title", "level_select", "journal", "achievements", "settings", "credits"]:
		game.state = st
		game.menu_sel = 0
		await frames(4)
		await shot("menu_" + st)
	game.to_title()
	for code in ["ArrowDown", "ArrowDown", "Enter", "Escape", "ArrowDown", "ArrowDown", "ArrowDown", "ArrowDown", "Enter", "ArrowRight", "Escape"]:
		game.on_key(code)
		await frames(2)
	print("MENU NAV end state: ", game.state)

	# experience, death, endless, console
	game.mode = "story"; game.level_idx = 7; game.wizard_stop = 0
	game.start_level(false)
	var seen := {}
	for e in game.enemies.duplicate():
		if not seen.has(e.type):
			seen[e.type] = true
			var b: int = game.save.xp
			game.damage(e, 99999.0)
			print("kill ", e.type, " +", game.save.xp - b)
	print("drops on the ground: ", game.drops.map(func(d): return d.id))
	for d in game.drops.duplicate():
		game.player = d.pos
		await frames(4)
	print("inventory: ", game.save.inv, " drops left: ", game.drops.size())
	game.run_command("level wizard 1")
	game.player = game.wizard_pos + Vector2(30, 0)
	await frames(4)
	game.on_key("KeyE")
	print("near wizard + E -> ", game.state, " tab ", game.shop_tab)
	await shot("shop_sell")
	game.on_key("Enter")            # sell one drifter tentacle
	game.on_key("ArrowRight")
	game.on_key("Space")            # sell all listener legs
	game.shop_action("sel3")
	game.shop_action("sellall")     # mimic hands
	print("after selling: crystals ", game.save.crystals, " inv ", game.save.inv)
	game.on_key("ArrowUp")
	await shot("shop_tiers")
	game.on_key("Escape")
	print("shop closed -> ", game.state)
	game.run_command("level 6")
	var reach = game.bfs(game.gw + 1)
	print("level 6: size ", game.gw, "x", game.gh, " chime tile ", Vector2i(game.chime.pos / 32.0), " exit tile ", Vector2i(game.exit_pos / 32.0),
		" door ", game.door.tile if game.door != null else null, " chime reachable with door shut: ", reach[game.tile_idx(game.chime.pos)] >= 0,
		" steps from start: ", reach[game.tile_idx(game.chime.pos)])
	# ---- shop items
	game.save.xp = 4000
	game.save.crystals = 500
	for id in ["powder", "bow", "arrow", "arrow", "arrow", "arrow", "quiver", "poison", "torch", "machine", "gun", "bullet", "bullet"]:
		game.buy(id)
	print("bought: ", game.save.items, " crystals left ", game.save.crystals, " | 4th arrow refused before satchel: ", game.save.items.arrow == 3)
	game.run_command("level wizard 1")
	await frames(5)
	print("squares: ", game.owned_items())
	game.run_command("spawn_sleeper")          # a dormant Sleeper 40 px to the right, in the open cave
	var target = game.enemies[0]
	game.equip("bow")
	game.use_item(target.pos)
	await frames(30)
	print("arrow hit: sleeper hp ", snappedf(target.hp, 1.0), "/300  arrows ", game.save.items.arrow, " bow shots ", game.save.items.bow)
	game.arrow_kind = "poison"
	game.use_item(target.pos)
	await frames(30)
	print("poison: cannot heal ", target.noregen_t > 8.0, " hp ", snappedf(target.hp, 1.0))
	game.use_item(game.player + Vector2(0, 80))
	await frames(40)
	print("missed arrow stuck: ", game.arrows_stuck.size(), " arrows now ", game.save.items.arrow)
	var back = game.player
	game.player = game.arrows_stuck[0].pos if game.arrows_stuck.size() > 0 else game.player
	await frames(6)
	print("picked back up: arrows ", game.save.items.arrow, " stuck ", game.arrows_stuck.size())
	game.player = back
	game.equip("gun")
	game.use_item(target.pos)
	await frames(6)
	print("gun: sleeper hp ", snappedf(target.hp, 1.0), " rounds ", game.save.items.gun, " bullets ", game.save.items.bullet, " reload ", snappedf(game.gun_reload, 0.1))
	game.run_command("level 5")
	await frames(5)
	target = game.enemies.filter(func(e): return e.type == "listener")[0]
	var sl = game.enemies.filter(func(e): return e.type == "sleeper")[0]
	sl.sleep = "rampage"
	sl.pos = game.player + Vector2(20, 0)
	sl.linger = 99.0
	game.god_mode = true
	game.equip("powder")
	game.use_item(game.player)
	await frames(10)
	print("powder: sleeper is ", sl.sleep, " mists ", game.mists.size(), " powder left ", game.save.items.powder)
	sl.pos = game.player + Vector2(0, 700)
	game.equip("torch")
	await frames(60)
	print("torch charge after 1s: ", snappedf(game.save.items.torch_charge, 0.1))
	game.equip("machine")
	game.use_item(game.player)
	game.player += Vector2(0, 0)
	game.use_item(game.player)
	await frames(100)
	print("machine claps so far: ", game.machine.claps if game.machine != null else "gone", " listener heading to it: ", target.dmap != null)
	await frames(120)
	print("machine after 3.6s: ", "exploded" if game.machine == null else "still there", " waves ", game.waves.filter(func(w): return w != null).size())
	game.god_mode = false
	game.run_command("level 8")
	game.die("listener")
	await frames(120)
	print("after death: ", game.state)
	game.mode = "endless"; game.endless_round = 4
	game.start_level(true)
	await frames(30)
	for cmd in ["light_mode", "level 3", "level wizard 3", "god_mode", "add_pebbles", "help", "light_mode", "god_mode"]:
		game.run_command(cmd)
		await frames(3)
	print("console ok: ", game.cfg.name, " | ", game.console_msg)
	await shot("wizard")

	# pebble, whisper, chime level
	game.run_command("level 3")
	await frames(5)
	game.whisper()
	game.throw_pebble(game.player + Vector2(100, 0))
	await frames(60)
	print("pebbles left: ", game.pebbles, " waves: ", game.waves.filter(func(w): return w != null).size())
	await frames(240)
	print("after 4s: waves ", game.waves.filter(func(w): return w != null).size())
	print("SMOKE DONE")
	quit()
