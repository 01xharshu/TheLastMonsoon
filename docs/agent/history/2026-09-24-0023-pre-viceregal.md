# Current handoff
Updated: 2026-09-23 19:36 IST. Read this, then only relevant code via `docs/README.md`. Older detail: `docs/agent/history/2026-09-23-1926-progress.md`.

## WORLD — IN_PROGRESS
- Goal: grounded civic plots/routes and usable map. Layout authority: `world/suryagarh/landscape_layout.gd`.
- Done: terrain/road mask/1024² map rebaked; town hall entrance regraded and segmented. `tools/world/audit_civic_layout.gd` PASS. Forward+/Metal `tools/world/validate_civic_world.gd` PASS: four foundations, 97 road samples (max 0.035 m mismatch), 2116 trees/748 rocks with zero intrusions. Map zoom/pan/marker PASS via `tools/world/validate_field_map.gd`; captures `docs/world/captures/10_map_zoom.png`, `11_town_hall_approach.png` inspected.
- Changed: `world/suryagarh/{landscape_layout.gd,settlements/civic_building.gd,settlements/settlement_builder.gd,shaders/terrain.gdshader,generated/}`, `player/world_map.gd`, `tools/world/{bake_landscape.gd,bake_field_map.gd,audit_civic_layout.gd,validate_civic_world.gd,validate_field_map.gd,capture_civic_approaches.gd}`.
- Next: player traversal of hall/police/compound approaches. No known plot/tree/grounding blocker.
- River/boat/climb status: `docs/world/river_boat_climb_status.md`. Native captures PASS; animation approval open.

## GAME FLOW — IN_PROGRESS
- Goal: title Play/Continue/Load; in-game Save/Load; persistent useful settings; river drinking/pouch fill.
- Done: three versioned slots and settings in `systems/save_manager.gd`; `ui/{main_menu,game_menu,settings_panel,menu_style}.gd`; wired `project.godot`, world and player. `tools/world/validate_save_flow.gd` PASS in isolated user:// path (position, time, inventory/water, vitals, weapons, mouse setting). `tools/world/capture_menu_ui.gd` PASS; title/pause captures inspected. Real user saves untouched.
- River: `player/river_water_component.gd` wired to player/empty pouch, E drink and Shift+E fill prompts at grounded waterline, weapons stow; crouch pose in `player/arjun_visual.gd`. `tools/world/validate_river_water.gd` GUI PASS, bank (61.066, 180), hydration ~45→75, pouch 0→2 L, full/distant rejection; `docs/world/captures/20_river_drink.png` inspected. Hand-to-water/mouth contact needs art refinement. `tools/world/validate_menu_navigation.gd` PASS: pause Save slot and title Continue restored position; save-flow recheck PASS. `README.md` controls and `docs/README.md` index refreshed. Next: actual civic approach traversal and refine river pose; then user play review.

## ARJUN / EQUIPMENT — IN_PROGRESS
- New-game Arjun is unarmed; inventory gates weapon controls/visuals. Armoury pickups lie on a rear rack and persist in saves. `tools/world/validate_weapon_store.gd` PASS, including room-side ray; Metal rack capture inspected. Period basis/limits: `docs/world/historical_accuracy.md`. Next: final weapon contact and period dressing.
- Owner **universally rejected** the Arjun appearance shown holding the Enfield on 2026-09-23. Exact image/hash, linked runtime/source and scope: `docs/characters/arjun/rejection_2026-09-23.md`. `characters/arjun/arjun.glb` remains wired temporarily but is not an accepted character; older `runtime_enfield.png` is rejection evidence only. Do not assess gun fit against it. Next: establish a new owner-reviewed Arjun appearance, then recapture gun scale/contact. Existing equipment controls remain; no likeness or contact approval.
- `tools/world/validate_arjun_equipment.gd` now stops on the rejected export. Independent `tools/weapons/audit_enfield_scale.gd` measures 1.41 m model length; fit remains open. Owner requested pistol/sword/bow/arrows/quiver/spear set: existing pistol/talwar retained, new standalone bow/arrow/quiver/spear source+GLB in `environment/weapons/period_*`. Forward+/Metal contact sheet and hashes in `docs/characters/arjun/weapon_set_status.md`; no character attachment or combat approval. Next: refine these standalone props, then use an accepted Arjun for carry/contact.

## HORSE / STABLE — IN_PROGRESS
- `horses/` adds one rideable horse and village stable. Original body: `WorkingAssets/Horse/village_horse_body.blend` → `assets/animals/horse/village_horse_body.glb`. Bent-knee pose, tack alignment, and per-leg hoof-height correction updated. `tools/world/validate_horse_stable.gd` PASS for mount, tack proximity, stable exit, moving hoof clearance, jump, dismount, and surface sounds. Metal side/walk/jump captures: `docs/world/captures/19_horse_rider_side.png`, `21_horse_walk.png`, `22_horse_jump.png`; details/hashes in `docs/world/horse_stable.md`.
- Timed mount/dismount PASS seat/release; Metal transition captures `20_horse_mount_transition.png` to `22_horse_dismount_transition.png` inspected. Contact unapproved.
- Sound: `audio/horses/` adds generated earth/road/timber hoof, landing, leather, and snort WAVs and a public-domain neigh; `tools/world/validate_horse_stable.gd` checks gait/landing triggers. Provenance: `audio/horses/README.md`. Next: in-game sound mix/listen, improve horse anatomy and hoof grounding/jump, verify hands/boots during full gait, add witness/persistence response. Historical and visual approval pending.

## ARJUN TRAVERSAL — IN_PROGRESS
- Ground snap/0.38 m step and Space climb on reachable static ledges added. `tools/world/validate_arjun_traversal.gd` PASS for single step, shallow road, three stairs, high barrier and ledge landing; tagged wall test PASS. Metal stair capture `docs/world/captures/23_arjun_stair_traversal.png` inspected; real world approach contact remains unverified. Climb palms miss targets by 0.44–0.63 m.
- Next: inspect world stairs/roads and refine climb/horse contact on accepted Arjun.

## SAFE RESUME
- Worktree has concurrent Arjun, weapons, horse, boat, fish, grove and generated assets. Inspect exact diffs; never broad reset/clean/stage. Charpai complete: `docs/world/charpai_validation.json`.
- Keep under 60 lines/6000 characters (`python3 tools/check_agent_docs.py`). Later: Blake and NPC/story systems.
