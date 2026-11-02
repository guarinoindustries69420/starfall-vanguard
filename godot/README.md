# Starfall Vanguard: PC build (Godot 4.3)

The downloadable PC version of Starfall Vanguard. The browser version in the repository root stays as a free demo.

This build is for PC only, on Windows, macOS and Linux. Mobile comes later, once the PC game is done.

## Running it

Open this folder in Godot 4.3 and press Play, or run `godot --path .` from the command line. It opens on the galaxy map.

## Controls

On a PlayStation 5 DualSense controller, using the standard layout:

| Control | Action |
| --- | --- |
| Left stick | Move |
| L3 | Sprint |
| Right stick | Aim (with light aim assist) |
| R2 | Fire |
| L2 | Steady aim |
| R1 | Grenade |
| L1 | Artillery call-in |
| Cross | Dive, or vault and climb when something is in the way |
| Circle | Crouch |
| Square | Reload |
| Options | Pause |

In menus, Cross confirms and Circle backs out. The on-screen prompts change between controller and keyboard depending on what you last touched.

On keyboard and mouse:

| Control | Action |
| --- | --- |
| WASD | Move |
| Shift | Sprint |
| Mouse | Aim |
| Left button | Fire |
| Right button | Steady aim |
| G | Grenade |
| B | Artillery |
| Space | Dive, vault or climb |
| C | Crouch |
| R | Reload |
| Esc | Pause |
| F11 | Full screen |

## The galaxy

The game opens on the galactic war map. The galaxy is a spiral disc of 177 worlds:

- Each of the four factions holds its own arm. The Free Reach has 39 worlds, the Sovereign Concord 40, the Meridian Compact 37 and the Hollow Swarm 36.
- A neutral deep core and thin borderlands between the arms hold 25 unclaimed worlds, most of them carrying a booster.
- Every arm is split into four sectors. Hold every world in a sector and its power-up applies to your whole squad.
- Worlds have a biome, a resistance level, cities with their own power-ups, and space lanes to their neighbours. Lanes between rival factions show in red as the front line.

The galaxy is built the same way every time from one seed, so only who holds what is saved, in `user://campaign.json`. The 24 named worlds of the browser demo keep their names and factions.

Map controls on a controller: left stick moves the cursor between worlds, right stick pans, L2 and R2 zoom, L1 and R1 jump between capitals, and Cross drops in. With a mouse: click to select, drag or WASD to pan, wheel to zoom, Q and E for capitals, and Enter or double-click to drop in.

## Hearts and minds

Unclaimed worlds aren't taken by force. Their people side with whoever wins them over, so dropping onto one opens an events hall instead of a battle. Each event is a contest against the faction raiding that world. A win fills your side of the hearts-and-minds meter and a loss fills the rival's. Whoever reaches 100 first gets the world and its booster. Three events are on offer at a time, and the line-up moves on after each one.

| Event | What it is |
| --- | --- |
| Skimmer Rally | Three laps of a canyon circuit in hover skimmers. Finish in the top two and ahead of the rival's ace. |
| Asteroid Rush | A minute in a drifting ore field above the world. Cut rocks apart and haul more ore than the rival miner. |
| Gravball | Two against two in a low-gravity arena. Outscore the rival pair. |
| Ring Run | Full throttle through a canyon of beacon rings. Beat the rival pilot's time; their ghost flies beside you. |
| Marksman Gala | A shooting exhibition in the town square. Spare the civilian cut-outs and outscore the rival marksman. |
| Cargo Sumo | Heavy tugs on a shrinking floating platform. Shove the rival's hauler off before you go over. |

All six work with the controller or with keyboard and mouse.

## Battle damage

Destroyed buildings fall into heaps of rubble and loose chunks, and those stay there for the rest of the mission. They block movement and stop bolts, so you can use them as cover. Grenades and artillery dig craters into the ground, with a raised lip you can shelter behind. Craters never fill back in.

Ruins and craters are saved for each map in `user://battlefields.json`. A city you come back to is still wrecked. To start the test run on a clean map, launch with `-- --sv-fresh`.

Troopers on both sides get over obstacles in the same way:

- Low obstacles, up to about 1 m, are vaulted.
- Chest-high obstacles, up to about 2.1 m, are climbed with both hands on the ledge and the rifle slung.
- Anything taller blocks the way.

## Tests

Three automated checks are included. Each prints PASS or FAIL per check and saves screenshots to `user://`.

- `godot --path . res://scenes/galaxy.tscn -- --sv-test --sv-fresh` checks the galaxy. It confirms there are more than 100 worlds, that each faction's section is one connected piece, that one lane network reaches every world, and that names are unique. It also checks the capitals, boosters, sectors and the 24 demo worlds, and that the seed always builds the same galaxy. It then drops onto an unclaimed world and plays all six events with an autopilot at three times speed.
- `godot --path . res://scenes/main.tscn -- --sv-test --sv-fresh` plays the city mission by itself. It checks controller input, crouching, a kill, a vault and a climb, craters, rubble, settling debris, cover and saving.
- `godot --path . res://scenes/gallery.tscn -- --sv-test` renders a close-up line of troopers, one in each movement pose.

## Licence

MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
