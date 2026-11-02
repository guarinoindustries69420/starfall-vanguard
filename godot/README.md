# Starfall Vanguard: PC build (Godot 4.3)

The downloadable PC version of Starfall Vanguard. The browser version in the repository root stays as a free demo.

This build is for PC only, on Windows, macOS and Linux. Mobile comes later, once the PC game is done.

## Running it

Open this folder in Godot 4.3 and press Play. You can also run it from the command line with `godot --path .`

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

## Battle damage

Destroyed buildings fall into heaps of rubble and loose chunks, and those stay there for the rest of the mission. They block movement and stop bolts, so you can use them as cover. Grenades and artillery dig craters into the ground, with a raised lip you can shelter behind. Craters never fill back in.

Ruins and craters are saved for each map in `user://battlefields.json`. A city you come back to is still wrecked. To start the test run on a clean map, launch with `-- --sv-fresh`.

Troopers on both sides get over obstacles in the same way:

- Low obstacles, up to about 1 m, are vaulted.
- Chest-high obstacles, up to about 2.1 m, are climbed with both hands on the ledge and the rifle slung.
- Anything taller blocks the way.

## Tests

Two automated checks are included:

- `godot --path . -- --sv-test --sv-fresh` plays the mission by itself. It checks controller input, crouching, a kill, a vault and a climb, craters, rubble, settling debris, cover and saving. It prints PASS or FAIL for each check and saves screenshots to `user://`.
- `godot --path . res://scenes/gallery.tscn -- --sv-test` renders a close-up line of troopers, one in each movement pose.

## Licence

MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
