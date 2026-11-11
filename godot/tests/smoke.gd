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
	game.die("listener")
	await frames(120)
	print("after death: ", game.state)
	game.mode = "endless"; game.endless_round = 4
	game.start_level(true)
	await frames(30)
	for cmd in ["light_mode", "level 3", "level wizard 2", "god_mode", "add_pebbles", "help", "light_mode", "god_mode"]:
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
