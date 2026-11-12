extends SceneTree
## Saves screenshots of the wizard's shop, the torch and the item squares.
## Run with:  godot --path . --script res://tests/shop_shot.gd -- <folder>

var game
var dir := ""

func _initialize() -> void:
	dir = OS.get_cmdline_user_args()[0]
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://test_save.json"   # never touch the real save
	root.add_child(game)
	game.admin_ok = true   # tests skip the console password
	_run()

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])

func _run() -> void:
	await wait(0.3)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1100, 760) * int(game.PX))
	await wait(0.5)
	game.save.inv = { "legs": 3, "tentacles": 7, "antennas": 0, "hands": 1 }
	game.save.xp = 1800
	game.save.crystals = 64
	game.save.items = { "powder": 2, "bow": 4, "arrow": 3, "quiver": 1, "poison": 1, "torch": 1, "torch_charge": 11.0, "machine": 1, "gun": 5, "bullet": 3 }
	game.mode = "story"
	game.run_command("level wizard 1")
	game.intro_t = 0.0
	game.console_msg_t = 0.0
	game.player = game.wizard_pos + Vector2(-34, 6)
	game.cam = game.player
	game.on_key("KeyE")
	game.on_key("ArrowUp")
	game.shop_buy_sel = 5
	await wait(0.3)
	await shot("shop_buy")
	game.on_key("Escape")
	game.run_command("level 3")
	game.intro_t = 0.0
	game.console_msg_t = 0.0
	game.mouse_pos = Vector2(game.W, game.H) / 2.0 + Vector2(10, 120)
	game.equip("torch")
	await wait(0.4)
	await shot("torch")
	game.equip("bow")
	game.use_item(game.player)        # scatter nothing: bow shot straight down the corridor
	game.equip("powder")
	game.use_item(game.player)
	game.equip("bow")
	await wait(0.5)
	await shot("bow_aim")
	quit()
