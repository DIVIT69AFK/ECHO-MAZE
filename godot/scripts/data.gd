class_name GameData
## All the fixed game content: levels, notes, achievements, upgrades, themes.

enum { SURF_STONE, SURF_METAL, SURF_WATER, SURF_SOFT }

const LEVELS := [
	{ "theme": "entrance", "name": "The Forgotten Entrance", "cells": [7, 6], "seed": 11, "surf": SURF_STONE,
	  "listeners": 1, "drifters": 1, "hint": "SPACE to clap. Follow the hum to the way down.", "pebbles": 2 },
	{ "theme": "whispering", "name": "The Whispering Corridors", "cells": [9, 8], "seed": 23, "surf": SURF_STONE, "listeners": 1, "drifters": 2, "hint": "SHIFT/Z to whisper. What you hear fades from memory.", "pebbles": 3 },
	{ "theme": "laboratory", "name": "The Abandoned Laboratory", "cells": [11, 9], "seed": 37, "surf": SURF_METAL, "hasChime": true,
	  "listeners": 2, "drifters": 2, "hint": "Metal reverberates. Hold C to sneak. CLICK to throw a pebble.", "pebbles": 3 },
	{ "theme": "flooded", "name": "The Flooded Cistern", "cells": [12, 10], "seed": 53, "surf": SURF_WATER,
	  "listeners": 1, "drifters": 2, "sleepers": 1, "hint": "Flooded stone ripples. Ancient things sleep in the damp—do not wake them.", "pebbles": 3 },
	{ "theme": "collapsed", "name": "The Collapsed Tunnels", "cells": [13, 11], "seed": 67, "surf": SURF_SOFT,
	  "listeners": 1, "drifters": 2, "sleepers": 2, "hint": "Moss absorbs your tread. Soft ground hides your steps.", "pebbles": 4 },
	{ "theme": "chasm", "name": "The Resonant Chasm", "cells": [14, 12], "seed": 79, "surf": SURF_STONE, "hasChime": true, "hasDoor": true, "chimeCorner": true,
	  "listeners": 2, "drifters": 2, "sleepers": 2, "hint": "Strike the bronze chime to bypass sound-sealed doors and mislead hunters.", "pebbles": 4 },
	{ "theme": "hive", "name": "The Hive of Sleepers", "cells": [15, 13], "seed": 97, "surf": SURF_STONE,
	  "drifters": 1, "sleepers": 1, "mimics": 1, "hint": "A sleeper nests here, and something else is copying your claps. Whisper and crawl.", "pebbles": 4 },
	{ "theme": "heart", "name": "The Heart of the Maze", "cells": [16, 14], "seed": 113, "surf": SURF_METAL, "hasChime": true,
	  "listeners": 2, "drifters": 2, "sleepers": 1, "mimics": 1, "hint": "Something waits by the final threshold. Not every clap you hear is your own.", "pebbles": 5 },
]

## Story mode visits the wizard after these levels (0-based): after Depth 2, Depth 4 and Depth 6
const WIZARD_AFTER := [1, 3, 5]
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
	{ "id": "sleeper_mercy", "title": "Let Sleeping Horrors Lie", "desc": "Sneak through a Sleeper chamber without waking it." },
	{ "id": "chime_master", "title": "Sound of Salvation", "desc": "Ring 3 resonance chimes across your descents." },
	{ "id": "pebble_trick", "title": "Master of Misdirection", "desc": "Distract an alert Listener with a thrown pebble." },
	{ "id": "story_complete", "title": "Surface Ascendant", "desc": "Conquer the Heart of the Maze and escape to the surface." },
	{ "id": "endless_5", "title": "Deep Diver", "desc": "Reach Round 5 in Endless Mode." },
	{ "id": "endless_10", "title": "Abyssal Voyager", "desc": "Reach Round 10 in Endless Mode." },
]

const UPGRADES := [
	{ "id": "phosphor", "name": "Phosphor Dust", "desc": "Echo light lingers 40% longer." },
	{ "id": "soles", "name": "Silent Soles", "desc": "Sneak speed +20%, running footsteps are 40% quieter." },
	{ "id": "crystal", "name": "Echo Crystal", "desc": "Claps project a directional compass shimmer toward the exit." },
	{ "id": "satchel", "name": "Pebble Satchel", "desc": "Carry +2 additional pebbles into each depth." },
]

## What each creature drops when destroyed, and what the wizard pays for it in blue crystals
const DROPS := {
	"listener": { "id": "legs", "name": "Listener Legs", "price": 2 },
	"drifter": { "id": "tentacles", "name": "Drifter Tentacles", "price": 1 },
	"sleeper": { "id": "antennas", "name": "Sleeper Antennas", "price": 5 },
	"mimic": { "id": "hands", "name": "Mimic Hands", "price": 10 },
}
const DROP_ORDER := ["drifter", "listener", "sleeper", "mimic"]

## The wizard's shop tiers (story mode). A tier opens once the player has this much experience.
const SHOP_TIERS := [
	{ "name": "TIER I", "xp": 500 },
	{ "name": "TIER II", "xp": 1500 },
	{ "name": "TIER III", "xp": 3500 },
]

## Things the wizard sells. price is in blue crystals, tier is 0, 1 or 2.
const ITEMS := {
	"powder": { "name": "Sleep Powder", "price": 4, "tier": 0, "desc": "Scatter a mist that hangs for 5 seconds. A raging Sleeper that walks into it falls straight back asleep. One use." },
	"bow": { "name": "Bow", "price": 5, "tier": 0, "desc": "Shoots arrows up to 100 px. The dotted line shows where the arrow will land. Breaks after 5 shots." },
	"arrow": { "name": "Arrow", "price": 1, "tier": 0, "desc": "30 damage. A missed arrow sticks where it lands and can be picked up again. You can carry 3." },
	"quiver": { "name": "Arrow Satchel", "price": 10, "tier": 1, "desc": "Carry up to 5 arrows and 2 special arrows." },
	"poison": { "name": "Poison Arrow", "price": 3, "tier": 1, "desc": "Special arrow. 30 damage, and the creature cannot heal for 10 seconds. Needs the Arrow Satchel." },
	"torch": { "name": "Torch", "price": 15, "tier": 1, "desc": "Lights the way ahead for 15 seconds. Picking up a Drifter Tentacle while holding it adds 2 seconds." },
	"machine": { "name": "Clapping Machine", "price": 20, "tier": 2, "desc": "Place it, then set it off from anywhere. Three claps draw every creature to it, then it explodes. One use." },
	"gun": { "name": "Primitive Gun", "price": 30, "tier": 2, "desc": "100 damage a shot, 4 seconds to reload. Falls apart after 5 shots." },
	"bullet": { "name": "Primitive Bullet", "price": 5, "tier": 2, "desc": "Ammunition for the gun. Cannot be recovered." },
}
const ITEM_ORDER := ["powder", "bow", "arrow", "quiver", "poison", "torch", "machine", "gun", "bullet"]
## The items that are held and used (the rest are ammunition or passive)
const USABLE := ["powder", "bow", "torch", "machine", "gun"]
const BOW_RANGE := 100.0
const GUN_RANGE := 320.0
const TORCH_RANGE := 170.0
const TORCH_TIME := 15.0

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
const CLAP := { "max_r": 190.0, "speed": 320.0, "alpha": 1.0, "light": 1.0, "hurts": true }
const WHISPER := { "max_r": 80.0, "speed": 200.0, "alpha": 0.7, "light": 0.55 }
const STEP := { "max_r": 48.0, "speed": 160.0, "alpha": 0.35, "light": 0.3, "step": true, "tail": 0.35 }
const PEBBLE := { "max_r": 150.0, "speed": 270.0, "alpha": 0.85, "light": 0.8 }
const SHRIEK := { "max_r": 260.0, "speed": 360.0, "alpha": 0.95, "light": 0.9, "kind": "red" }
const CHIME_WAVE := { "max_r": 280.0, "speed": 310.0, "alpha": 0.9, "light": 0.9, "kind": "gold" }
