extends Node2D
## A thin drawing node. The game script does the actual drawing in draw_<kind>().

var game
var kind := ""


func _draw() -> void:
	game.call("draw_" + kind, self)
