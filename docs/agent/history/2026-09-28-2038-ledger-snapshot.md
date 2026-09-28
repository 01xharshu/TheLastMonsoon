# Current handoff
Updated: 2026-09-28 15:36 IST.
## BHAIRAVPUR VILLAGE CONSTRUCTION — IN_PROGRESS
- Updated: 2026-09-28 20:37 IST. Objective: extend the live village with a gathering/water area and clear walkable approach. Scope: settlement geometry and focused validation; preserve concurrent player/charpai edits.
- Completed: added stone well, apron, timber roller frame and two seats to live Bhairavpur settlement, east of the existing central aisle.
- Files/assets changed: `world/suryagarh/settlements/settlement_builder.gd`, this ledger. Tests/evidence: `git diff --check` PASS; Godot check pending. Blockers: none. Next: run focused Godot parse/world check and inspect any runtime errors, then document evidence/limitations.
## UI FONTS / ICONS — OWNER PLAY REVIEW OPEN
- CC0 fonts wired, icons clarified; headless PASS. Metal title, pause and chest captures inspected. No mission screen yet; owner play review: `docs/world/interaction_system.md`.
## RIVER REFINEMENT — IN_PROGRESS
- Fish 36→144; ripples/glints, transparent water. Headless PASS; Metal inspected. Art/play open. Next: fish/wake/reflection and route review: `docs/world/river_boat_climb_status.md`.
## THANA POLICE NPCS — STATIC CANDIDATE / VISUAL REVIEW OPEN
- Three roles placed with body collision; headless PASS. Next Metal cloth/contact and role idles: `docs/characters/npcs/thana_staff.md`.
## DEV — MAKEHUMAN CANDIDATE
- 2026-09-28 IST. Dev MPFB body/53-bone rig, editable Blend, static and rigged idle GLBs. Story: sepoy brother disappears; “Find Dev.” Relaxed arms replace A-pose; buttons/placket moved toward measured coat surface. Fresh front/profile and four Godot Metal idle phases inspected. Small side/waist seams, modern collar and coarse shoes remain. Motion/world use unapproved. Next: settle unit, tailor uniform/likeness, author travel and review normal-speed contact. Detail: `docs/characters/npcs/arjun_brother.md`.
## ARJUN TALL CLIMB — RENDER REVIEW
- Legs and wrist poses corrected; close Metal frames and palm contact check PASS. Next: full-world grip/mantle motion. `docs/characters/arjun/animation_tree.md`.
## UPPER SHELF WEAPON REACH — COMPLETE
- PASS; owner feel review open: `docs/world/weapon_store.md`.
## LONG-WEAPON SIZE / SHOULDER ANIMATION — IN_PROGRESS
- Updated: 2026-09-28 20:36 IST. Both held/stowed lengths now ~1.20 m; existing AnimationTree has filtered head/spine ready and aim library clips, with palm solve after blend. Scale audit, motion tree, rifle and double-gun headless PASS. Earlier Metal aim captures show barrels/hands; latest side fixture produced one stale and one black frame. Files: `player/arjun_equipment.gd`, `player/arjun_motion_tree.gd`, `tools/characters/validate_arjun_motion_tree.gd`, `tools/weapons/audit_enfield_scale.gd`, `tools/weapons/capture_longgun_fit.gd`. Next: fresh isolated Metal aim/side captures, review cheek/stock and grip, update focused docs; visual approval open.
## REFERENCE THIRD-PERSON CAMERA — COMPLETE
- 2026-09-28 15:37 IST. Reference framing and local setting applied; stationary/walking/indoor Metal views inspected. Movement 8.12 m, controls and clearance PASS; docs gate PASS. Files, evidence and fixture limit: `docs/world/reference_camera.md`. Next: owner normal-play review.
## AIM HAND / CAMERA — IN_PROGRESS
- Pistol palm/socket corrected; Metal grip checked. Final art/motion review open: `docs/characters/arjun/firearm_aim_camera.md`.
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-28 IST. Rest sequence and world Metal PASS; seat/feet improved. Middle stiff, raised sleep hand. Next: lie clip and normal-speed player review. `docs/world/charpai_rest_transition.md`.
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- H toggles nearby cover; G stows/draws. Stance PASS. Distant shelter, contact and enemy sight open: `docs/characters/arjun/stealth_stance.md`.
## ARJUN ANIMATIONTREE — IN_PROGRESS
- Idle/walk/swim/sit blend PASS; charpai sampled contact improved, continuous motion open: `docs/characters/arjun/animation_tree.md`.
## WORLD INTERACTION — IN_PROGRESS
- Key cards, chest/store PASS. Controls text removed; chest feed handles pickups. Metal frames inspected; live play, contact and loot open: `docs/world/interaction_system.md`.
History: `docs/agent/history/2026-09-28-pre-horse-contact-ledger.md`.
## INDIAN NPCS — FOUR CANDIDATE TREES / VISUAL_REVIEW_FAILED
- Fruit seller and weaving assistant added as independent rigged candidates; all four trees PASS. Metal motion shows knee breakthrough/floating feet; no new world placement. Next fit cloth/grounded gait. Evidence/limits: `docs/characters/npcs/other_indian_npcs.md`, `docs/characters/npcs/indian_peasant_pair.md`.
## BRITISH NPC — TREE_READY / VISUAL_CONTACT_OPEN
- IN_PROGRESS: 16 trees and isolated body sweeps PASS; full-world Player crosses OfficialWoman (1/2 PASS). Actor body transform, test/report and `docs/characters/british/animation_tree.md` updated. Diff check PASS. Next diagnose Player physics sweep, fix, rerun world/tree checks. Costume/contact review open.
## VICEREGAL RESIDENCE — IN_PROGRESS
- Arjun16/horse6 stairs and flexible reins PASS; Metal rope views inspected. Early mount contact open: `docs/world/horse_stable.md`.
- Landing/rail supports repaired: Metal pixels, 567 terrain samples, 20 piles and actual jetty walk PASS. Period form/joinery open; evidence/next: `docs/world/period_access.md`.

## BUILDING SITE PLACEMENT — COMPLETE
- 2026-09-28 10:16 IST. Town Hall, Police, House placement COMPLETE: grade bleed fixed, terrain rebaked, sites/routes/collision/Metal views PASS. Changed files, commands, evidence, Old Fort audit and concurrent player compile blockers: `docs/world/building_site_placement_2026-09-28.md`. Next: manual player approach review when compile clears.

## FOREST SHRINE — VISUAL_REVIEW_FAILED
- Forest/cave/idol preview; status, captures, next: `docs/world/forest_shrine.md`.

## EXISTING WORLD / GAME — IN_PROGRESS
- Three carts: six seats, short drives, turn, body collision and side obstacle PASS; Metal placement inspected. Long routes, entry motion, seat fit open: `docs/world/horse_cart_candidates.md`.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Sword/boat checks PASS. Row reversal eases through rest; live Metal palms within 0.034 mm, sampled interior dry. Preview/limits: `docs/characters/arjun/combat_motion_2026-09-24.md`. Next: skin/cloth, player feel and sound review; body approval open.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- Input/menu/settings checks PASS; physical DualSense USB/Bluetooth route and feel/gyro tuning open: `docs/world/animal_tools_and_controller.md`. Prior detail in boat-power handoff snapshot above.

## DAY / STAMINA / FORAGE
- Reach/eat/slope + systems PASS; live contact open; `docs/world/day_survival_forage.md`.

## SAFE RESUME
- Civic shelves/table support: evidence: `docs/world/weapon_store.md`. Store/held scales aligned; Enfield length corrected; contact open. See `docs/world/historical_accuracy.md`.
- Preserve concurrent edits; ledger gate: `python3 tools/check_agent_docs.py`.
