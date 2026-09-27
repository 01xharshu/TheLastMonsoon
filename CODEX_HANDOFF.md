# Current handoff
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-27 IST. Current `objects/charpai.gd` jumps time immediately; no sit/lie animation or fade. Scope: add controlled sit-to-sleep transition, fade-covered time jump, wake/restore, and live validation; preserve concurrent player/world edits. Next: implement and run focused Metal test.
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- H toggles nearby cover; G stows/draws. Stance PASS. Distant shelter, contact and enemy sight open: `docs/characters/arjun/stealth_stance.md`.
## ARJUN ANIMATIONTREE — IN_PROGRESS
- Idle/walk/swim blend PASS; motion/contact review open: `docs/characters/arjun/animation_tree.md`.
## WORLD INTERACTION — IN_PROGRESS
- 2026-09-25: E/Q card, object glint, ammo HUD, supply/cart holds. Marker yields to selector inside 3 m; Metal chest capture inspected. Owned number-key weapon selection draws after stow; held-E pickup of five store weapons and save/load PASS. Contact, kneel motion and corpse loot remain open. Detail: `docs/world/interaction_system.md`.
Updated: 2026-09-24 05:51 IST. Detail before this task: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`. Read only relevant `docs/README.md` rows.

## NEW PROP ASSET INTEGRATION — COMPLETE
- Prop test PASS. Metal civic run found zero nature intrusions; older headless count was a MultiMesh readback artifact. Detail: `docs/world/new_prop_integration.md`.

## CC0 PERIOD PROP ADDITIONS — COMPLETE
- 2026-09-27 IST. Poly Haven CC0 crate and bucket added to live world with collision. Headless/Metal structural checks PASS; fresh pixels inspected. Sources, hashes, captures, commands and remaining limits: `docs/world/period_props.md`. Next: broader player traversal and composition review when the world art pass resumes.

## NEW PROP FOLLOW-UP / CIVIC NATURE CHECK — COMPLETE
- 2026-09-27 IST. Metal: zero intrusions across 2,120 trees and 720 rocks. Civic validator now marks nature unchecked headless; prop test PASS again. Separate civic FAIL: Police foundation +1.87 m and fort access collision gaps 0.128/0.163 m after concurrent trail edits. Next for terrain owner: reconcile grade and rebake, rerun Metal civic/fort checks. Detail: `docs/world/new_prop_integration.md`.

## INDIAN VILLAGE NPC PAIR — VISUAL_REVIEW_FAILED / MOTION_BLOCKED
- Two independent MPFB sources; fitted top, original drapes, 9.73 MB combined static Godot previews at Bhairavpur. Fresh Metal still: `docs/characters/npcs/indian_peasant_pair_world.png`. Hands/legs now attached; period tailoring and sari/dhoti drape still fail visual review. Detail/provenance: `docs/characters/npcs/indian_peasant_pair.md`.
- Separate rigged idle/walk studies now use baked MPFB body/garment masks and load in Godot. Four Metal walk phases per figure at `docs/characters/npcs/indian_peasant_{male,female}_walk_{00,25,50,75}.png` show no prior body/trouser breakthrough; stiff drapes, full-cycle motion and foot contact remain unapproved. Do not promote. Next: tailor period cloth and review normal-speed motion/contact, then NPC behavior. 8GB-device performance untested.

## BRITISH NPC MAKEHUMAN CANDIDATES — BASE_MOTION_READY / REALISM_OPEN
- 2026-09-27 IST. Eight MPFB sources retained; sixteen independent GLBs use baked masks/fabric colors. Seven military men placed in compound; eight women and official separately in Government House grounds. Personal idle/walk players, distinct profiles, all16 pose playback and independent stop test PASS; surveyed world placement PASS.
- Representative Metal walk phases inspected: prior severe body breakthrough repaired; outward arms, stiff skirts, foot contact and all-costume deformation remain unapproved. Analysis/evidence: `docs/characters/british/model_analysis_2026-09-27.md` and `.html`. Next: full-cycle contact review and later period/realism pass; patrols have no navigation/gameplay AI.

## VICEREGAL RESIDENCE — IN_PROGRESS
- Government House estate/room checks PASS. Real player stair up/down PASS for both flights, Town Hall and Police (Metal + headless): `docs/world/player_stair_traversal.md`. Low-lip step probe corrected; feet/contact unapproved. Full walk-through, 499-body profile and art open: `docs/world/government_house.md`.

## FOREST SHRINE — VISUAL_REVIEW_FAILED
- Forest/cave/idol preview; status, captures, next: `docs/world/forest_shrine.md`.

## EXISTING WORLD / GAME — IN_PROGRESS
- Layout, menus, save/load and river systems have focused PASS results; actual civic traversal, river hand contact and owner-approved Arjun remain open. Horse and cart candidates are not live-world approved. Status: `docs/README.md`, `docs/world/horse_stable.md`, `docs/world/horse_cart_candidates.md`; prior detail in `docs/agent/history/2026-09-27-1215-handoff-snapshot.md`.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Blade/flag and boat paddle/deck Metal tests PASS; body/contact, sound and police NPCs open: `docs/characters/arjun/combat_motion_2026-09-24.md`.
- Weapon rack: five props measured/laid flat on supported shelves; standing reach and Metal pixels checked. Stable pickup IDs preserve saves across furnishing edits. Details/period limits: `docs/world/weapon_store.md`, `docs/world/historical_accuracy.md`. Next: exact weapon forms and location evidence, then Arjun contact.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- 2026-09-24 06:16 IST. Input/rumble/glyphs/menu and Settings implemented; headless input, map, menu, rifle, bow, river and save tests PASS. Hardware verification remains. Next: physical DualSense USB/Bluetooth route and feel/gyro tuning. Limits/evidence: `docs/world/animal_tools_and_controller.md`; full prior status in history file above.

## SAFE RESUME
- Inspect exact diffs before edits; no broad reset/clean/stage. Keep this ledger under 60 lines/6000 chars (`python3 tools/check_agent_docs.py`). Preserve historical detail in focused docs. Later: NPC/story and combat.
