# Current handoff
## ARJUN WALL CLIMB — TREE POSES / CONTACT REVIEW
- 2026-09-28 IST. Added reach, pull, mantle and recovery rig poses to the AnimationTree, driven by climb progress; wall hand targets and timed landing remain. Motion tree and river climb headless validators PASS. Sampled pull wrist gaps: left 0.119 m, right 0.120 m, so contact is not approved. Native Metal capture stalled after the first boat frame; no new climb pixels were inspected. Next: focused Metal climb capture, tune palm and foot contact plus mantle weight transfer. Detail: `docs/characters/arjun/animation_tree.md`.
## UPPER SHELF WEAPON REACH — IN_PROGRESS
- Updated 2026-09-28 IST. User reports top shelf equip needs precise positioning. Inspecting focus range, angle and ray against real rack. Next: widen safe standing reach, test off-center E holds. Detail: `docs/world/weapon_store.md`.
## LONG-WEAPON SIZE / SHOULDER ANIMATION — IN_PROGRESS
- Updated: 2026-09-28 05:08 IST. Scope: user now prioritizes modern long-gun visual proportions, shouldered stock/head fit and animation-library integration over prior exact Enfield scale. Current Enfield 1.39 m and double gun 0.72 scale; aim hands use procedural IK after locomotion AnimationTree. Side capture shows stock behind face. Files under review: `player/arjun_equipment.gd`, `player/arjun_motion_tree.gd`, `player/arjun_visual.gd`. Next: tune held/stowed sizes and shoulder anchor, add authored long-gun library pose, capture idle/aim/motion and run focused checks. Preserve concurrent edits.
## LONG-WEAPON AIM CAMERA — COMPLETE
- Updated: 2026-09-28 05:02 IST. Long-gun aim: 0.95 m arm, 0.50 m offset, 54° FOV; Enfield/double-gun Metal captures `/tmp/tlm_aim_long_{enfield,double_gun}.png` inspected; both firearm checks PASS. Files and details: `player/player_controller.gd`, `tools/weapons/capture_{long_weapon,double_gun}_aim.gd`, `docs/characters/arjun/firearm_aim_camera.md`. Next: separate moving/cover and final Arjun art review.
## REFERENCE THIRD-PERSON CAMERA — IN_PROGRESS
- 2026-09-28 IST. Normal camera reference: rear view, Arjun at left third, head near 40% frame, open forward vista. Metal trial `/tmp/tlm_reference_camera_rear.png` visually matched with 0.55 m pivot, -10° pitch, 1.25 m arm, 0.8 m right offset. Applied defaults in `player/player.tscn`, `player/player_controller.gd`, `world/suryagarh/suryagarh_world.gd`, `systems/save_manager.gd`, `ui/settings_panel.gd`; added `tools/world/capture_reference_camera.gd`; camera clearance fixture bound updated for configurable spring length. Earlier camera controls Metal PASS (`/tmp/tlm_reference_camera_controls.log`); earlier clearance FAIL from stale fixed 1.5 m bound, not an observed wall hit. Next: rerun controls/clearance and fresh production-default rear capture, inspect pixels and `git diff --check`.
## AIM HAND / CAMERA — IN_PROGRESS
- 2026-09-28 IST. Reversed pistol palm fixed by finger-aligned socket; fresh Metal `/tmp/tlm_aim_camera_reference.png` inspected, grip error 0.015 mm, barrel dot 1.0, rifle test PASS. Firing/reload motion review open. Detail: `docs/characters/arjun/firearm_aim_camera.md`.
## WEAPON EQUIP / HORSE EXIT — COMPLETE
- Updated 2026-09-28 IST. Shelf E equips new/owned arms; F dismount card persists. Integrated five-weapon/card and horse checks PASS; Metal prompt captures inspected. Files, commands, evidence and owner play limit: `docs/world/interaction_system.md`. Next: owner normal-speed play review.
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-27 IST. Rest/time jump works; `validate_charpai.gd` Metal PASS (`/tmp/tlm_charpai_rest_final.log`). Hand below bed and raised leg BLOCK visual approval. Next: fit rig clips and verify entry/wake: `docs/world/charpai_rest_transition.md`.
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- H toggles nearby cover; G stows/draws. Stance PASS. Distant shelter, contact and enemy sight open: `docs/characters/arjun/stealth_stance.md`.
## ARJUN ANIMATIONTREE — IN_PROGRESS
- 2026-09-27 IST. Idle/walk/swim/sit blend and visual checks PASS. Imported sit clip now drives charpai entry; fresh Metal seated frame still shows floating boots. Recline remains procedural, and full rest capture did not finish. Next: fit seat/feet, author rigged lie clip, capture complete entry/wake motion. Detail: `docs/characters/arjun/animation_tree.md`.
## WORLD INTERACTION — IN_PROGRESS
- E/Q card, glint, ammo HUD, holds; chest Metal and five store pickups/save PASS. Contact, kneel and corpse loot open: `docs/world/interaction_system.md`.
Updated: 2026-09-27 IST. Archive: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`.

## PERIOD PROP PHYSICAL / PLACEMENT AUDIT — COMPLETE
- Real Player 14/14, moved-prop Metal/ground and stair checks PASS; 8GB/crowd review open: `docs/world/period_props.md`. Prior detail: `docs/agent/history/2026-09-27-boat-power-stroke-handoff.md`.

## PERIOD PROP ROUTE / FAST CONTACT CHECK — COMPLETE
- 2026-09-28 IST. Headless/Metal PASS: live Player sprint stops at bucket/pot/basket; compound gate and village aisle remain clear. Evidence: `docs/world/period_props.md`, `docs/world/period_prop_route_validation.json`. Next: NPC body and 8GB-device review when available.

## INDIAN VILLAGE NPC PAIR — CANDIDATE_TREE_READY / VISUAL_REVIEW_FAILED
- Trees PASS after sleeve/drape repair; studio clip shows knee breakthrough/floating feet. World pair static; visuals FAIL. Next fit cloth/grounded gait. Evidence/limits: `docs/characters/npcs/indian_peasant_pair.md`.

## BRITISH NPC — TREE_READY / CONTACT_REVIEW
- All16 trees/cadence and flat-grade foot targets PASS; Metal poses inspected. Adaptive hip drop reduces crouch; sole/terrain contact, turns, hands/skirts/realism and AI open. Evidence/next: `docs/characters/british/animation_tree.md`.
- 2026-09-28 05:10 IST. Current task: actors are crossable because `british_npc_actor.gd` extends Node3D without collision. Add per-actor physical capsule while retaining personal AnimationTree; verify Player collision at each of 16 placements, run tree regression and inspect in-world behavior. Files: British actor, focused collision validator/docs only; preserve concurrent player/world edits.

## VICEREGAL RESIDENCE — IN_PROGRESS
- House checks, Arjun16 and horse6 stair routes PASS; compound landing added, normal horse jump preserved. Mount/exit/climb restart PASS. Side-aware swing added; wrist/stirrup contact fails review. Next fit poses: `docs/world/horse_stable.md`, `docs/world/player_stair_traversal.md`; estate/performance: `docs/world/government_house.md`.
- Landing/rail supports repaired: Metal pixels, 567 terrain samples, 20 piles and actual jetty walk PASS. Period form/joinery open; evidence/next: `docs/world/period_access.md`.

## BUILDING INTERIOR / EXTERIOR REFINEMENT — COMPLETE
- 2026-09-28 IST. House/civic trim, panels, benches and runners added. Residence headless PASS (65/46/8); civic headless PASS after final edit. House and focused civic Metal pixels inspected. Full Metal civic rerun ended without a final marker; art/performance approval open. Evidence/next: `docs/world/building_refinement_2026-09-27.md`.

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
- Reach/systems PASS; terrain contact open; `docs/world/day_survival_forage.md`.

## SAFE RESUME
- Civic shelves/table support: evidence: `docs/world/weapon_store.md`. Store/held scales aligned; Enfield length corrected; contact open. See `docs/world/historical_accuracy.md`.
- Preserve concurrent edits; ledger gate: `python3 tools/check_agent_docs.py`.
