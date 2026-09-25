# Current handoff
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- Prone and crate/tree/cart cover controls, collision and poses integrated; test PASS, Metal captures inspected. Motion/contact and enemy sight remain. Detail: `docs/characters/arjun/stealth_stance.md`.
## WORLD INTERACTION — IN_PROGRESS
- 2026-09-25: E/Q card, object glint, ammo HUD, supply/cart holds. Marker yields to selector inside 3 m; Metal chest capture inspected. Owned number-key weapon selection draws after stow; held-E pickup of five store weapons and save/load PASS. Contact, kneel motion and corpse loot remain open. Detail: `docs/world/interaction_system.md`.
Updated: 2026-09-24 05:51 IST. Detail before this task: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`. Read only relevant `docs/README.md` rows.

## NEW PROP ASSET INTEGRATION — COMPLETE
- Test PASS; 21 civic nature intrusions remain. Detail: `docs/world/new_prop_integration.md`.

## INDIAN VILLAGE NPC PAIR — VISUAL_REVIEW_FAILED / MOTION_BLOCKED
- Two independent MPFB sources; fitted top, original drapes, 9.73 MB combined static Godot previews at Bhairavpur. Fresh Metal still: `docs/characters/npcs/indian_peasant_pair_world.png`. Hands/legs now attached; period tailoring and sari/dhoti drape still fail visual review. Detail/provenance: `docs/characters/npcs/indian_peasant_pair.md`.
- Separate rigged idle/walk studies now use baked MPFB body/garment masks and load in Godot. Four Metal walk phases per figure at `docs/characters/npcs/indian_peasant_{male,female}_walk_{00,25,50,75}.png` show no prior body/trouser breakthrough; stiff drapes, full-cycle motion and foot contact remain unapproved. Do not promote. Next: tailor period cloth and review normal-speed motion/contact, then NPC behavior. 8GB-device performance untested.

## BRITISH NPC MAKEHUMAN CANDIDATES — IN_PROGRESS
- Eight MPFB pair candidates and renders exist; hashes match. Detail: `docs/characters/british/README.md`.
- Current task reworked private woman's skirt with gathered folds in `tools/characters/build_british_private_pair.py`; rebuilt `WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend` (SHA `14953ce1414e59c786678f7345ec8d87d7b9531da4ca9403c7ddd2a92df6f7f1`) and rerendered three views. Blender and render completed; front/side inspected. A cap/strap experiment clipped and was reverted.
- Blockers: all remain static unapproved blockouts. Private pair has modern donor seams, floating buttons/straps, oversized headwear and bodice/skirt join; no pose, motion, Godot, or historical costume approval. Next: hand-tailor this pair and verify deformation before propagating changes across ranks.

## VICEREGAL RESIDENCE — IN_PROGRESS
- 2026-09-24 12:07 IST. `world/suryagarh/settlements/government_house.gd`: walled estate, road, garden, three floors, wings, 74 windows, stairs. Final site rebake PASS (`/tmp/tlm_government_house_site_rebake.log`); `tools/world/validate_government_house.gd` Forward+/Metal PASS (`/tmp/tlm_government_house_final.log`): 65 gate/hall, 46 stair, 8 door clearances. Fresh `docs/world/captures/28_government_house_map.png` inspected after farm marker move; labels now separate. Estate/interior captures 24–27 inspected. Details/limits: `docs/world/government_house.md`. Next: controlled player traversal, 499-body performance profile, room/window/garden art refinement; production and exact historical approval open.

## FOREST SHRINE — VISUAL_REVIEW_FAILED
- Forest/cave/idol preview; status, captures, next: `docs/world/forest_shrine.md`.

## EXISTING WORLD / GAME — IN_PROGRESS
- Shared plot/route and civic audits previously passed; actual hall/police/compound traversal remains. World audits `tools/world/{audit_civic_layout,validate_civic_world,validate_field_map}.gd` and renders indexed in `docs/README.md`.
- Title/save/load/settings and river drink/pouch function; `tools/world/{validate_save_flow,validate_menu_navigation,validate_river_water}.gd` passed. River pose hand contact remains open.
- Arjun runtime appearance owner-rejected (`docs/characters/arjun/rejection_2026-09-23.md`); weapon contact open. Horse: rigged candidate and recorded road hooves; status/limits in `docs/world/horse_stable.md`. Rider/tack/hoof contact and listening open; carts follow. Boat/climb in focused docs.
- Horse carts: ekka, goods cart, and family carriage remain isolated candidates. Arjun E boarding points, passenger/driver sockets, F exit, basic trial movement and driver rein pose added; isolated player test PASS and Metal driver/cabin captures inspected. Collision, entry motion, passenger fit, roads/turns and 8GB performance still block live-world use. Status/evidence: `docs/world/horse_cart_candidates.md`.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Town hall/police interiors, props, rifle, Adams revolver, knife and combat input implemented; focused Godot tests PASS. Metal captures and historical limits: `docs/world/historical_accuracy.md`, `docs/world/civic_materials.json`, `docs/characters/arjun/combat_motion_2026-09-24.md`. Weapon pose/contact and sound balance unapproved. Next: obtain owner-approved Arjun body, import and visually assess equipment fit; police NPCs remain blockouts. Full prior status: `docs/agent/history/2026-09-24-1207-handoff-full.md`.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- 2026-09-24 06:16 IST. Input/rumble/glyphs/menu and Settings implemented; headless input, map, menu, rifle, bow, river and save tests PASS. Hardware verification remains. Next: physical DualSense USB/Bluetooth route and feel/gyro tuning. Limits/evidence: `docs/world/animal_tools_and_controller.md`; full prior status in history file above.

## SAFE RESUME
- Inspect exact diffs before edits; no broad reset/clean/stage. Keep this ledger under 60 lines/6000 chars (`python3 tools/check_agent_docs.py`). Preserve historical detail in focused docs. Later: NPC/story and combat.
