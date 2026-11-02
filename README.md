# Starfall Vanguard

A top-down mission shooter with a real-time commander war game on top, made by Guarino Gaming Group (G³), a department of Guarino Industries LLC.

Pick a faction (Free Reach, Sovereign Concord or Meridian Compact), drop onto contested worlds, finish the objectives and get to the shuttle. Reach Captain and the war map turns into a real-time strategy game with supply lines, sieges, air support and Auxiliary Corps bases.

The game is one HTML file (`index.html`). Open it in a browser, or play it online:

- GitHub Pages: https://guarinoindustries69420.github.io/starfall-vanguard/
- Hugging Face Space: https://huggingface.co/spaces/GuarinoIndustriesLLC/starfall-vanguard

Loadout scores, supply, readiness and the enemy's stance draw on the Guarino Metric Suite (DOI 10.5281/zenodo.22803865). Faction emblems and title art were generated for this game with Z-Image Turbo on Hugging Face.

Released under the MIT License. See `LICENSE`.

## Models

The 3D models are built in Blender from the Python scripts in `blender/` (run with the `bpy` module: `python3 trooper2.py -- out`). `trooper2.py` builds the trooper kit (undersuit, armor sets, helmets and weapons, with baked shading), `packkit.py` packs it into the compact form the game embeds, and `swapkit.py` puts it into the game file. The enemy, prop and mech scripts work the same way.
