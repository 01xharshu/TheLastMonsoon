# Current handoff
## THANA POLICE NPCS — STATIC CANDIDATE / VISUAL REVIEW OPEN
- Three 1857 roles (daroga, mohurrir, burkundaz) placed inside DistrictPolice with body collision; headless world load PASS. Next Metal room/cloth/contact review and authored role idles. Evidence and period limits: `docs/characters/npcs/thana_staff.md`.
## DEV — MAKEHUMAN CANDIDATE
- 2026-09-28 IST. Dev MPFB body/53-bone rig, editable Blend, static and rigged idle GLBs. Story premise: sepoy brother disappears; “Find Dev.” Fitted upper and tapered coat skirt; four Godot Metal idle frames inspected after large waist gap repair. Small side seam, A-pose arms, modern collar and coarse shoes remain. Idle motion and world use unapproved. Next: settle unit, tailor uniform/likeness, author expressive idle/travel and review normal-speed contact. Detail: `docs/characters/npcs/arjun_brother.md`.
## ARJUN WALL CLIMB — TREE POSES / CONTACT REVIEW
- Tree reach/pull/mantle PASS structurally; wrist gaps ~0.12 m, native motion/contact open. Next Metal capture/fit: `docs/characters/arjun/animation_tree.md`.
## UPPER SHELF WEAPON REACH — IN_PROGRESS
- Updated 2026-09-28 IST. User reports top shelf equip needs precise positioning. Inspecting focus range, angle and ray against real rack. Next: widen safe standing reach, test off-center E holds. Detail: `docs/world/weapon_store.md`.
## LONG-WEAPON SIZE / SHOULDER ANIMATION — IN_PROGRESS
- Modern long-gun size/shoulder fit in progress; stock sits behind face. Next authored pose, capture and firearm checks: `docs/characters/arjun/firearm_aim_camera.md`.
## REFERENCE THIRD-PERSON CAMERA — IN_PROGRESS
- Rear-view trial matched supplied framing. New defaults applied; rerun clearance/control and inspect production pixels: `docs/world/player_stair_traversal.md`.
## AIM HAND / CAMERA — IN_PROGRESS
- Pistol palm/socket corrected; Metal grip checked. Final art/motion review open: `docs/characters/arjun/firearm_aim_camera.md`.
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-27 IST. Rest/time jump works; `validate_charpai.gd` Metal PASS (`/tmp/tlm_charpai_rest_final.log`). Hand below bed and raised leg BLOCK visual approval. Next: fit rig clips and verify entry/wake: `docs/world/charpai_rest_transition.md`.
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- H toggles nearby cover; G stows/draws. Stance PASS. Distant shelter, contact and enemy sight open: `docs/characters/arjun/stealth_stance.md`.
## ARJUN ANIMATIONTREE — IN_PROGRESS
- Idle/walk/swim/sit blend PASS; charpai boot/body contact still open: `docs/characters/arjun/animation_tree.md`.
## WORLD INTERACTION — IN_PROGRESS
- E/Q card, glint, ammo HUD, holds; chest Metal and five store pickups/save PASS. Contact, kneel and corpse loot open: `docs/world/interaction_system.md`.
Updated: 2026-09-28 IST. Full prior status: `docs/agent/history/2026-09-28-pre-horse-contact-ledger.md`. Archive: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`.

## INDIAN NPCS — FOUR CANDIDATE TREES / VISUAL_REVIEW_FAILED
- Fruit seller and weaving assistant added as independent rigged candidates; all four trees PASS. Metal motion shows knee breakthrough/floating feet; no new world placement. Next fit cloth/grounded gait. Evidence/limits: `docs/characters/npcs/other_indian_npcs.md`, `docs/characters/npcs/indian_peasant_pair.md`.

## BRITISH NPC — TREE_READY / VISUAL_CONTACT_OPEN
- All16 independent trees, cadence, flat-grade foot targets and stationary 0.5s reversal PASS. Relaxed finger poses PASS; close Metal hands/turn pixels inspected. Hands still stiff; female skirt waist gap, sole/terrain contact and AI open. Evidence/next: `docs/characters/british/animation_tree.md`.

## VICEREGAL RESIDENCE — IN_PROGRESS
- Arjun16/horse6 stairs and flexible reins PASS; Metal rope views inspected. Early mount contact open: `docs/world/horse_stable.md`.
- Landing/rail supports repaired: Metal pixels, 567 terrain samples, 20 piles and actual jetty walk PASS. Period form/joinery open; evidence/next: `docs/world/period_access.md`.

## BUILDING SITE PLACEMENT — IN_PROGRESS
- 2026-09-28 IST. Verify Town Hall, Police and Government House against surveyed plots, road endpoints, terrain support and actual entrance clearance after refinement. No building source changes yet; concurrent player/weapon work preserved. Next: run layout/world/player route checks, capture each site in Forward+/Metal and fix any measured mismatch.

## FOREST SHRINE — VISUAL_REVIEW_FAILED
- Forest/cave/idol preview; status, captures, next: `docs/world/forest_shrine.md`.

## EXISTING WORLD / GAME — IN_PROGRESS
- Focused systems PASS; civic traversal, river contact, Arjun approval and horse/cart live-world review open. See `docs/README.md`, `docs/world/horse_stable.md`, `docs/world/horse_cart_candidates.md`.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Sword/boat checks PASS. Row reversal eases through rest; live Metal palms within 0.034 mm, sampled interior dry. Preview/limits: `docs/characters/arjun/combat_motion_2026-09-24.md`. Next: skin/cloth, player feel and sound review; body approval open.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- Input/menu/settings checks PASS; physical DualSense USB/Bluetooth route and feel/gyro tuning open: `docs/world/animal_tools_and_controller.md`. Prior detail in boat-power handoff snapshot above.

## DAY / STAMINA / FORAGE
- Reach/eat/slope + systems PASS; live contact open; `docs/world/day_survival_forage.md`.

## SAFE RESUME
- Civic shelves/table support: evidence: `docs/world/weapon_store.md`. Store/held scales aligned; Enfield length corrected; contact open. See `docs/world/historical_accuracy.md`.
- Preserve concurrent edits; ledger gate: `python3 tools/check_agent_docs.py`.
