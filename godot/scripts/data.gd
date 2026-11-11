class_name GameData
## All the fixed game content: levels, notes, achievements, upgrades, themes.

enum { SURF_STONE, SURF_METAL, SURF_WATER, SURF_SOFT }

const LEVELS := [
	{ "theme": "entrance", "name": "The Forgotten Entrance", "cells": [7, 6], "seed": 11, "surf": SURF_STONE,
	  "hint": "SPACE to clap. Follow the hum to the way down.", "pebbles": 2 },
	{ "theme": "whispering", "name": "The Whispering Corridors", "cells": [9, 8], "seed": 23, "surf": SURF_STONE,
	  "listeners": 1, "hint": "SHIFT/Z to whisper. What you hear fades from memory.", "pebbles": 3 },
	{ "theme": "laboratory", "name": "The Abandoned Laboratory", "cells": [11, 9], "seed": 37, "surf": SURF_METAL,
	  "listeners": 1, "drifters": 1, "hasChime": true,
	  "hint": "Metal reverberates. Hold C to sneak. CLICK to throw a pebble.", "pebbles": 3 },
	{ "theme": "flooded", "name": "The Flooded Cistern", "cells": [12, 10], "seed": 53, "surf": SURF_WATER,
	  "drifters": 2, "sleepers": 1,
	  "hint": "Flooded stone ripples. Ancient things sleep in the damp—do not wake them.", "pebbles": 3 },
	{ "theme": "collapsed", "name": "The Collapsed Tunnels", "cells": [13, 11], "seed": 67, "surf": SURF_SOFT,
	  "listeners": 1, "sleepers": 1, "hasSecret": true, "upgrade": "phosphor",
	  "hint": "Moss absorbs your tread. Seek hollow walls where echoes ring hollow.", "pebbles": 4 },
	{ "theme": "chasm", "name": "The Resonant Chasm", "cells": [14, 12], "seed": 79, "surf": SURF_STONE,
	  "listeners": 2, "drifters": 2, "hasChime": true, "hasDoor": true, "upgrade": "soles",
	  "hint": "Strike the bronze chime to bypass sound-sealed doors and mislead hunters.", "pebbles": 4 },
	{ "theme": "hive", "name": "The Hive of Sleepers", "cells": [15, 13], "seed": 97, "surf": SURF_STONE,
	  "listeners": 1, "drifters": 2, "sleepers": 2, "hasSecret": true, "upgrade": "crystal",
	  "hint": "More than one sleeper nests here. Whisper and crawl—a single clap is fatal.", "pebbles": 4 },
	{ "theme": "heart", "name": "The Heart of the Maze", "cells": [16, 14], "seed": 113, "surf": SURF_METAL,
	  "listeners": 2, "drifters": 2, "sleepers": 1, "mimics": 1, "hasChime": true, "hasSecret": true, "upgrade": "satchel",
	  "hint": "Something waits by the final threshold. Not every clap you hear is your own.", "pebbles": 5 },
]

## Story mode visits the wizard after these levels (0-based): after Depth 4 and after Depth 6
const WIZARD_AFTER := [3, 5]
const WIZARD_CFG := { "theme": "wizard", "name": "The Wizard's Hollow", "cells": [12, 9], "surf": SURF_STONE,
	"wizard": true, "safe": true, "hint": "A warm light in the rock. Someone lives down here." }

const NOTES := [
	{ "title": "Delver Log: Day 1 — The Descent",
	  "text": "They told us the dark down here was hollow. It is not. It listens. The walls themselves seem carved from resonant obsidian that drink sound and remember it for seconds afterward." },
	{ "title": "Delver Log: Day 3 — The Lost Lantern",
	  "text": "I shattered my carbide lantern escaping the upper collapse. In absolute blindness, I learned to clap. The reverberation traces doorways, alcoves, and sudden drops—if only for a fleeting heartbeat." },
	{ "title": "Delver Log: Day 6 — The Eyeless Stalkers",
	  "text": "Something answered my hands today. It has no eyes, only flared auditory horns that shudder at every footfall. It does not hunt my scent—it hunts the exact point where sound last struck the stone." },
	{ "title": "Delver Log: Day 9 — The Slumbering Carapaces",
	  "text": "In the lower cisterns lie creatures curled like fossilized ammonites. They sleep deeply, ignoring soft whispers and careful creeps. But a loud clap or a thrown stone will shatter their trance into blind fury." },
	{ "title": "Delver Log: Day 14 — Misdirection",
	  "text": "A stone tossed down a side corridor saved my life twice today. The hunters pursue the impact, giving me three precious seconds to slip past. Always conserve your pebbles; they are your only voice at a distance." },
	{ "title": "Delver Log: Day 19 — Acoustic Bulkheads",
	  "text": "The architects of this maze sealed doors with harmonic frequencies. Strike the suspended bronze chimes with a stone: the pure harmonic tone unlocks the barrier while echoing across every hall." },
	{ "title": "Delver Log: Day 24 — The Wandering Wailers",
	  "text": "The floating Drifters are blind and harmless until brushed. Touch one, and its scream ripples through half a league of stone. Everything in the abyss comes running to that cry." },
	{ "title": "Delver Log: Day 31 — The Echo of Myself",
	  "text": "Yesterday I heard my own clap echo from a dead-end corridor ahead of me. I had not clapped for hours. Something down here mimics our survival cries to draw us into its jaws. If you find these notes… you clap as I did. Escape." },
]

const ACHIEVEMENTS := [
	{ "id": "first_descent", "title": "First Frequency", "desc": "Complete Depth 1 and descend into the abyss." },
	{ "id": "silent_run", "title": "Silent as Stone", "desc": "Complete any story level without clapping once." },
	{ "id": "ghost", "title": "Ghost in the Deep", "desc": "Complete Depth 3 or deeper without alerting any creature." },
	{ "id": "cartographer", "title": "The Cartographer", "desc": "Recover all 8 lost story notes." },
	{ "id": "secret_finder", "title": "Acoustic Archeologist", "desc": "Discover a secret room hidden behind a cracked wall." },
	{ "id": "sleeper_mercy", "title": "Let Sleeping Horrors Lie", "desc": "Sneak through a Sleeper chamber without waking it." },
	{ "id": "chime_master", "title": "Sound of Salvation", "desc": "Ring 3 resonance chimes across your descents." },
	{ "id": "pebble_trick", "title": "Master of Misdirection", "desc": "Distract an alert Listener with a thrown pebble." },
	{ "id": "story_complete", "title": "Surface Ascendant", "desc": "Conquer the Heart of the Maze and escape to the surface." },
	{ "id": "endless_5", "title": "Deep Diver", "desc": "Reach Round 5 in Endless Mode." },
	{ "id": "endless_10", "title": "Abyssal Voyager", "desc": "Reach Round 10 in Endless Mode." },
	{ "id": "upgraded", "title": "Attuned Perception", "desc": "Collect all 4 sound upgrade artifacts." },
]

const UPGRADES := [
	{ "id": "phosphor", "name": "Phosphor Dust", "desc": "Echo light lingers 40% longer." },
	{ "id": "soles", "name": "Silent Soles", "desc": "Sneak speed +20%, running footsteps are 40% quieter." },
	{ "id": "crystal", "name": "Echo Crystal", "desc": "Claps project a directional compass shimmer toward the exit." },
	{ "id": "satchel", "name": "Pebble Satchel", "desc": "Carry +2 additional pebbles into each depth." },
]

const XP_REWARD := { "listener": 200, "drifter": 100, "sleeper": 500, "mimic": 1000 }
const MAX_HP := { "listener": 160, "drifter": 35, "mimic": 520, "sleeper": 300 }
const NAMES := { "listener": "The Listener", "drifter": "A Drifter", "mimic": "The Mimic", "sleeper": "The Sleeper" }

## Wall edge colour and line style, used on levels with no wall art (level 2 and the wizard's cave)
const THEMES := {
	"entrance": { "edge": Color("e6eeff"), "style": "rock" },
	"whispering": { "edge": Color("cfe0ff"), "style": "brick" },
	"laboratory": { "edge": Color("c8f0ff"), "style": "line" },
	"flooded": { "edge": Color("a8e0f5"), "style": "brick" },
	"collapsed": { "edge": Color("d2f0d0"), "style": "rock" },
	"chasm": { "edge": Color("e0d0ff"), "style": "rock" },
	"hive": { "edge": Color("ffe0a0"), "style": "line" },
	"heart": { "edge": Color("ffc8d0"), "style": "line" },
	"wizard": { "edge": Color("ffe8c0"), "style": "rock" },
}

## The sound waves. max_r = how far the sound travels through the passages (px), speed in px/s,
## light = how bright the light it carries is, tail = how long that light lingers (1 = normal)
const CLAP := { "max_r": 540.0, "speed": 320.0, "alpha": 1.0, "light": 1.0, "hurts": true }
const WHISPER := { "max_r": 160.0, "speed": 200.0, "alpha": 0.7, "light": 0.55 }
const STEP := { "max_r": 70.0, "speed": 160.0, "alpha": 0.35, "light": 0.3, "step": true, "tail": 0.35 }
const PEBBLE := { "max_r": 340.0, "speed": 270.0, "alpha": 0.85, "light": 0.8 }
const SHRIEK := { "max_r": 650.0, "speed": 360.0, "alpha": 0.95, "light": 0.9, "kind": "red" }
const CHIME_WAVE := { "max_r": 700.0, "speed": 310.0, "alpha": 0.9, "light": 0.9, "kind": "gold" }
