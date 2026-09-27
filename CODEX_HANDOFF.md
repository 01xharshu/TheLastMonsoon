# Current handoff
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-27 17:47 IST. Sit/recline pose, fade-covered 8h clock jump, energy restore/control release implemented; `tools/world/validate_charpai.gd` Forward+/Metal PASS (`/tmp/tlm_charpai_rest_final.log`). Captures show a hand below the bed and raised leg: visual approval BLOCKED. Next: author/fit sit and sleep rig clips and verify player-driven entry/wake. Detail: `docs/world/charpai_rest_transition.md`.
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- H toggles nearby cover; G stows/draws. Stance PASS. Distant shelter, contact and enemy sight open: `docs/characters/arjun/stealth_stance.md`.
## ARJUN ANIMATIONTREE — IN_PROGRESS
- 2026-09-27 IST. Idle/walk/swim blend PASS. Current task: integrate existing sit clips and rest blend into tree, replace charpai procedural limbs, retest Metal pose/contact. Detail: `docs/characters/arjun/animation_tree.md`.
## WORLD INTERACTION — IN_PROGRESS
- 2026-09-25: E/Q card, object glint, ammo HUD, supply/cart holds. Marker yields to selector inside 3 m; Metal chest capture inspected. Owned number-key weapon selection draws after stow; held-E pickup of five store weapons and save/load PASS. Contact, kneel motion and corpse loot remain open. Detail: `docs/world/interaction_system.md`.
Updated: 2026-09-27 IST. Archive: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`.

## PERIOD PROPS / CIVIC WORLD — COMPLETE
- Civic terrain/routes and Metal nature clearance PASS; detail/evidence: `docs/world/new_prop_integration.md`, `docs/world/period_props.md`. Next: actual traversal and broader art review.

## CC0 PROP EXPANSION — IN_PROGRESS
- 2026-09-27 IST. Poly Haven 1K stool, bench and barrel fetched and MD5-verified; manifest now has 35 source files. Added collidable village/compound instances in `settlement_builder.gd` and extended `validate_period_props.gd`. Next: import in Godot, run headless/Metal validation, inspect placement pixels and adjust if needed. Detail target: `docs/world/period_props.md`.

## INDIAN VILLAGE NPC PAIR — VISUAL_REVIEW_FAILED / MOTION_BLOCKED
- MPFB static/walk candidates load; Metal walk phases have no prior body breakthrough, but drape, foot contact, period tailoring and 8GB performance remain unapproved. Next: tailor fabric, review full motion. Detail: `docs/characters/npcs/indian_peasant_pair.md`.

## BRITISH NPC — ANIMATIONTREE_BASE_READY / REALISM_OPEN
- Sixteen separately placed GLBs have personal idle/walk trees with 0.2s blends. Playback, start/stop/idle recovery, independence, facing/arms and placement PASS. Bone axes, knee/elbow/ankle motion and torso straps repaired; full-cycle forward gait samples PASS all16.
- Representative Metal tree views inspected. Skirts, sole contact, stride-speed matching and period realism open; no navigation/gameplay AI. Evidence/next: `docs/characters/british/animation_tree.md`; HTML: `docs/characters/british/model_analysis_2026-09-27.html`.

## VICEREGAL RESIDENCE — IN_PROGRESS
- House checks, Arjun16 and horse6 stair routes PASS; compound landing added, normal horse jump preserved. Raised-landing dismount/ledge checks PASS; mount hand/foot contact open: `docs/world/horse_stable.md`, `docs/world/player_stair_traversal.md`; estate/performance: `docs/world/government_house.md`.
- Landing/rail supports repaired: Metal pixels, 567 terrain samples, 20 piles and actual jetty walk PASS. Period form/joinery open; evidence/next: `docs/world/period_access.md`.

## BUILDING INTERIOR / EXTERIOR REFINEMENT — IN_PROGRESS
- 2026-09-27 IST. Scope: improve visible Government House hall/facade and civic hall/police details using current procedural assets; preserve concurrent character/prop work. Existing captures reviewed: Government House hall is broad and sparse; civic facade reads as flat repeated bays. Next: implement restrained architectural/furnishing detail, capture fresh Metal views, rerun civic/residence traversal tests, record visual limits.

## FOREST SHRINE — VISUAL_REVIEW_FAILED
- Forest/cave/idol preview; status, captures, next: `docs/world/forest_shrine.md`.

## EXISTING WORLD / GAME — IN_PROGRESS
- Layout, menus, save/load and river systems have focused PASS results; actual civic traversal, river hand contact and owner-approved Arjun remain open. Horse and cart candidates are not live-world approved. Status: `docs/README.md`, `docs/world/horse_stable.md`, `docs/world/horse_cart_candidates.md`; prior detail in `docs/agent/history/2026-09-27-1215-handoff-snapshot.md`.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Wall-blocked sword and full forward/reverse/steering boat cycles PASS; blade-entry ripple added, Metal capture inspected, dry interior preserved. Final body/contact and sound open: `docs/world/historical_accuracy.md`, `docs/characters/arjun/combat_motion_2026-09-24.md`.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- 2026-09-24 06:16 IST. Input/rumble/glyphs/menu and Settings implemented; headless input, map, menu, rifle, bow, river and save tests PASS. Hardware verification remains. Next: physical DualSense USB/Bluetooth route and feel/gyro tuning. Limits/evidence: `docs/world/animal_tools_and_controller.md`; full prior status in history file above.

## DAY / STAMINA / FORAGE
- Movement drain/frame clock fixed; checks PASS: `docs/world/day_survival_forage.md`.

## SAFE RESUME
- Civic weapon shelves repaired; six support/bounds/access checks PASS. Render/history limits: `docs/world/weapon_store.md`.
- Preserve concurrent edits; no broad reset/clean/stage. Ledger gate: `python3 tools/check_agent_docs.py`. Later: NPC/story and combat.
