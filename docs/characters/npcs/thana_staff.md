# Thana staff candidates — 1857 Suryagarh

Status: **IN_WORLD_STATIC_CANDIDATE / VISUAL_REVIEW_OPEN** (2026-09-28).

Three Indian adult staff now remain on the District Police ground floor: a daroga near the public hall, a mohurrir by the record room, and a burkundaz at the hall side. Each has a separate model, a simple body collider, and a fixed post inside the thana. They have no patrol, dialogue, combat, schedule, or rank-driven behavior yet. The front entrance, central aisle, stair run, tables, and armoury shelf remain outside their body positions. Their names are role metadata, not floating labels.

## Period basis and art limits

The [Indian Bureau of Police Research and Development's history](https://bprd.nic.in/uploads/pdf/201905071150110985311Report-1.pdf) describes a daroga in charge of a thana with armed men before the 1861 police law. [Research on colonial Bengal policing](https://academic.oup.com/past/article/270/1/223/8112899) identifies darogahs, mohurrirs and burkundazes among Indian station staff before 1861. These references support the role set, not a specific uniform for fictional Suryagarh. We use cotton garments, cloth head wraps, a record folio and a wooden watch staff as **provisional visual choices**. No post-1861 khaki uniform or modern rank insignia is claimed.

The builder `tools/characters/build_thana_staff.py` derives three static exports from the project's MPFB village adult base (`characters/npcs/village_farmer.glb`) and adds original role details. The generated files and review images are in `characters/npcs/thana/`. Base MPFB core assets are CC0, as recorded in the source model's [village NPC notes](indian_peasant_pair.md). The source character already has known modern collar, turban shape and cloth problems; these carry into this pass. The Blender review images show the exported form, but are not world lighting or gameplay approval.

## Verification and next work

`tools/characters/validate_thana_staff.gd` loads the live Suryagarh world and checks that all three imported models and body colliders are present inside the police footprint, with fixed station-bound metadata. **PASS** on Godot 4.7.2 headless. This is a structural check only. Inspect their feet, skin/garment appearance, prop grip, room clearance and performance in Forward+/Metal. Replace the base costume with fitted 1857 clothing, verify the period dress against a local primary source, then author seated/writing/watch idle actions and player interactions before treating these as finished NPCs.
