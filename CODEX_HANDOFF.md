# Current handoff
Updated: 2026-09-23 19:29 IST. Read this, then only relevant code via `docs/README.md`. Older detail: `docs/agent/history/2026-09-23-1926-progress.md`.

## WORLD — IN_PROGRESS
- Goal: stable civic plots, connected grounded access, clear vegetation and useful field map. Shared authority: `world/suryagarh/landscape_layout.gd`; settlement/bake/map consume it.
- Done: terrain/road mask/1024² map rebaked; town hall entrance regraded and segmented. `tools/world/audit_civic_layout.gd` PASS. Forward+/Metal `tools/world/validate_civic_world.gd` PASS: four foundations, 97 road samples (max 0.035 m mismatch), 2116 trees/748 rocks with zero intrusions. Map zoom/pan/marker PASS via `tools/world/validate_field_map.gd`; captures `docs/world/captures/10_map_zoom.png`, `11_town_hall_approach.png` inspected.
- Changed: `world/suryagarh/{landscape_layout.gd,settlements/civic_building.gd,settlements/settlement_builder.gd,shaders/terrain.gdshader,generated/}`, `player/world_map.gd`, `tools/world/{bake_landscape.gd,bake_field_map.gd,audit_civic_layout.gd,validate_civic_world.gd,validate_field_map.gd,capture_civic_approaches.gd}`.
- Next: actual player traversal of hall/police/compound approach before marking full path acceptance. No known plot/tree/grounding blocker.

## GAME FLOW — IN_PROGRESS
- Goal: title Play/Continue/Load; in-game Save/Load; persistent useful settings; river drinking/pouch fill.
- Done: three versioned slots and settings in `systems/save_manager.gd`; `ui/{main_menu,game_menu,settings_panel,menu_style}.gd`; wired `project.godot`, world and player. `tools/world/validate_save_flow.gd` PASS in isolated user:// path (position, time, inventory/water, vitals, weapons, mouse setting). `tools/world/capture_menu_ui.gd` PASS; title/pause captures inspected. Real user saves untouched.
- Current: `player/river_water_component.gd` drafted, not wired/tested. Next: connect to player/pouch, animate and verify reachable shore plus E/Shift+E; then exercise save UI transitions. No known blocker.

## ARJUN / EQUIPMENT — IN_PROGRESS
- Owner chose improved MPFB candidate; references `WorkingAssets/Arjun/references/`, recoverable candidate `WorkingAssets/Arjun/candidate/`, runtime `characters/arjun/arjun.glb`. Enfield colors corrected. H/hold-~ wheel/swim stow implemented; sword palm grip and right rifle palm error (~3 cm) remain. Likeness, cloth motion and gameplay clips need rendered/contact review. Next: `tools/world/validate_arjun_equipment.gd`, inspect captures, integrate keyed walk/sit/prone/swim. Horse riding later.

## SAFE RESUME
- Worktree has concurrent Arjun, weapons, horse, boat, fish, grove and generated assets. Inspect exact diffs; never broad reset/clean/stage. Charpai complete: `docs/world/charpai_validation.json`.
- Keep this file under 60 lines/6000 characters (`python3 tools/check_agent_docs.py`); move completed detail to focused docs/history. Later user priorities: Blake combat/climbing and British/Indian NPC/story systems.
