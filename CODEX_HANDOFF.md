# Current handoff
## THANA POLICE NPCS — STATIC CANDIDATE / VISUAL REVIEW OPEN
- Three 1857 roles (daroga, mohurrir, burkundaz) placed inside DistrictPolice with body collision; headless world load PASS. Next Metal room/cloth/contact review and authored role idles. Evidence and period limits: `docs/characters/npcs/thana_staff.md`.
## DEV — MAKEHUMAN CANDIDATE
- 2026-09-28 IST. Dev MPFB body/53-bone rig, editable Blend, static and rigged idle GLBs. Story: sepoy brother disappears; “Find Dev.” Relaxed arms replace A-pose; buttons/placket moved toward measured coat surface. Fresh front/profile and four Godot Metal idle phases inspected. Small side/waist seams, modern collar and coarse shoes remain. Motion/world use unapproved. Next: settle unit, tailor uniform/likeness, author travel and review normal-speed contact. Detail: `docs/characters/npcs/arjun_brother.md`.
## ARJUN TALL CLIMB — RENDER REVIEW
- Tree and climb PASS; wrist/boot contact sampled. Metal capture blocked by autoload errors. Next: inspect mantle and feet. `docs/characters/arjun/animation_tree.md`.
## UPPER SHELF WEAPON REACH — IN_PROGRESS
- Updated 2026-09-28 IST. Live Metal E pickup PASS but fixture elevated Arjun above floor; capture angle unsuitable. Correcting standing height and eye-level ray. Next: rerun floor-height upper pickups and normal camera capture; detail: `docs/world/weapon_store.md`.
## LONG-WEAPON SIZE / SHOULDER ANIMATION — IN_PROGRESS
- Modern long-gun size/shoulder fit in progress; stock sits behind face. Next authored pose, capture and firearm checks: `docs/characters/arjun/firearm_aim_camera.md`.
## REFERENCE THIRD-PERSON CAMERA — COMPLETE
- 2026-09-28 10:13 IST. Rear/left-third camera and local setting applied. Metal capture, controls, indoor clearance, whitespace PASS; docs gate fails because shared handoff grew past 6 KB. Evidence: `docs/world/reference_camera.md`. Next: owner moving/indoor play review; condense other task sections with their owners.
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
- E/Q card, glint, ammo HUD, holds; chest Metal and five store pickups/save PASS. Contact, kneel and corpse loot open: `docs/world/interaction_system.md`.
Updated: 2026-09-28 IST. Full prior status: `docs/agent/history/2026-09-28-pre-horse-contact-ledger.md`. Archive: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`.

## INDIAN NPCS — FOUR CANDIDATE TREES / VISUAL_REVIEW_FAILED
- Fruit seller and weaving assistant added as independent rigged candidates; all four trees PASS. Metal motion shows knee breakthrough/floating feet; no new world placement. Next fit cloth/grounded gait. Evidence/limits: `docs/characters/npcs/other_indian_npcs.md`, `docs/characters/npcs/indian_peasant_pair.md`.

## BRITISH NPC — TREE_READY / VISUAL_CONTACT_OPEN
- All 16 independently placed; two endpoint turns, tree/cadence/flat-grade foot targets PASS. Eight skirt waists close in source; Metal shows hard band. Next costume, sole/terrain and normal-speed review: `docs/characters/british/animation_tree.md`.

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
