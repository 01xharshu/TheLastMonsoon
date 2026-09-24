# Rigged horse runtime candidate

Source: [Horse by Quaternius on Poly Pizza](https://poly.pizza/m/qvTrSG9pZF), listed as Public Domain (CC0), animated FBX/GLTF. The untouched `source_horse.glb` has SHA-256 `fae7a7ec91e0d6a33554efb896fac9c4e8c632644183bcb8cc962f673d3ce609`.

`tools/horses/build_rigged_candidate.py` imports the source in Blender, removes an unrelated Icosphere, changes the light coat material toward bay, saves `rigged_horse_candidate.blend`, and exports `assets/animals/horse/rigged_horse_candidate.glb` (SHA-256 `ea436eeed8e5b6e7fe6addf65cb8add773e0fec866d2ce3e0f3b2a9c3009fb78`). Its custom 50-bone skeleton and built-in walk, gallop, idle, and jump clips drive the current horse body. The original procedural body is hidden as a fallback; separate tack and rider remain project-made.

This is a low-poly candidate. It improves the continuous body and legs but its breed, proportions, bone deformation, hoof grounding, tack contact, and rider posture are not historically or visually approved. Animal Animator is installed locally in Blender but applies to Rigify animal rigs; this horse uses its own rig and animations.
