extends SceneTree
## Saves screenshots of a clap spreading through a level.
## Run with:  godot --path . --script res://tests/visual.gd -- <folder>

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

func level(cmd: String) -> void:
	game.run_command(cmd)
	game.intro_t = 0.0
	game.console_msg_t = 0.0
	for e in game.enemies:
		e.pos = e.pos   # keep creatures; they are far from the start
	await wait(0.3)

func _run() -> void:
	await wait(0.3)
	if OS.get_cmdline_user_args().has("phone"):
		game.touch_mode = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(390, 780) * int(game.PX))
		await wait(0.5)
	game.mode = "story"
	await level("level 3")
	await shot("a_dark")
	game.clap()
	for t in [0.25, 0.7, 1.3, 2.2, 3.2]:
		await wait(t - (0.0 if t == 0.25 else [0.25, 0.7, 1.3, 2.2][[0.7, 1.3, 2.2, 3.2].find(t)]))
		await shot("b_clap_%.2f" % t)
	await level("level 8")
	game.clap()
	await wait(0.8)
	await shot("c_heart")
	await level("level 4")
	game.clap()
	await wait(0.9)
	await shot("d_flooded")
	await level("level wizard 1")
	await shot("e_wizard")
	game.to_title()
	await wait(2.0)
	await shot("f_title")
	quit()
