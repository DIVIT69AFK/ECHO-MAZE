# Echo Maze — Godot 4 version

The same game as `../echo-maze.html`, rebuilt in Godot 4 (made with 4.7).

## Run it
1. Install Godot 4 from https://godotengine.org (or `brew install --cask godot` on a Mac).
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **F5** (or the play button).

## What is where
| Path | What it is |
|---|---|
| `scripts/main.gd` | The game: levels, player, creatures, sound waves, input |
| `scripts/data.gd` | Levels, notes, achievements, upgrades, wave settings |
| `scripts/hud.gd` | Menus, in-game HUD, touch buttons |
| `scripts/echo_light.gdshader` | The darkness, the light that travels with sound, the wave fronts |
| `scripts/sfx.gd` | Sound: plays files from `audio/`, or built-in stand-ins |
| `art/` | Sprites, floor tiles and wall art |
| `audio/` | Put sound files here (see `audio/README.md` for the names) |
| `tests/smoke.gd` | Plays through every level automatically to catch errors |

## How the light works
A sound wave does not travel in straight lines through a maze. For each wave the game
works out how far sound has to travel through the passages to reach every spot. A spot
lights up when the wave front arrives and fades about a second later, so you have to keep
making sound to see. Change `AFTERGLOW` in `scripts/main.gd` to make the light last longer
or shorter.

## Test
```
godot --headless --path . --script res://tests/smoke.gd
```
