# Current handoff
## LONG-WEAPON AIM CAMERA — IN_PROGRESS
- 2026-09-27 23:00 IST. Objective: match supplied close right-shoulder aiming composition for Enfield and double gun while retaining two-hand support and centered sight. Existing long-gun path uses 0.95 m arm, 0.38 m right offset and 56 degree FOV; player camera/controller files have concurrent edits. Next: tune only long-gun aim values, capture both guns in Forward+/Metal, inspect pixels and run focused firearm checks.
## REFERENCE THIRD-PERSON CAMERA — IN_PROGRESS
- 2026-09-27 22:52 IST. Match user screenshot: behind Arjun, left-of-center silhouette, shoulder-height view, open forward vista. Existing 1.8 m centered spring arm and camera clearance inspected; player controller has concurrent unrelated edits. Next: adjust normal camera framing, run focused camera checks, inspect a fresh rear-view Metal capture.
## AIM HAND / CAMERA — IN_PROGRESS
- 2026-09-27 IST. Pistol scaled to 0.72, grip curl strengthened, recoil and timed reload clicks added; firearm and motion-tree checks PASS. Fresh player-view Metal capture stalled amid concurrent renderer jobs, so grip/trigger contact and normal-speed motion remain unapproved. Next: capture firing and reload in game, inspect hand pixels and correct any finger intersections. Detail: `docs/characters/arjun/animation_tree.md`.
## WEAPON EQUIP / HORSE EXIT — IN_PROGRESS
- Updated 2026-09-27 IST. E equips new/owned shelf weapons; F dismount card persists. Equip/horse tests PASS. Now capturing Metal prompt pixels in isolated renderer scene. Next: inspect captures, repair layout if needed, update `docs/world/interaction_system.md`.
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-27 17:47 IST. Sit/recline pose, fade-covered 8h clock jump, energy restore/control release implemented; `tools/world/validate_charpai.gd` Forward+/Metal PASS (`/tmp/tlm_charpai_rest_final.log`). Captures show a hand below the bed and raised leg: visual approval BLOCKED. Next: author/fit sit and sleep rig clips and verify player-driven entry/wake. Detail: `docs/world/charpai_rest_transition.md`.
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

## INDIAN VILLAGE NPC PAIR — CANDIDATE_TREE_READY / VISUAL_REVIEW_FAILED
- Trees PASS after sleeve/drape repair; studio clip shows knee breakthrough/floating feet. World pair static; visuals FAIL. Next fit cloth/grounded gait. Evidence/limits: `docs/characters/npcs/indian_peasant_pair.md`.

## BRITISH NPC — TREE_READY / CONTACT_REVIEW
- All16 trees/cadence and flat-grade foot targets PASS; Metal poses inspected. Adaptive hip drop reduces crouch; sole/terrain contact, turns, hands/skirts/realism and AI open. Evidence/next: `docs/characters/british/animation_tree.md`.

## VICEREGAL RESIDENCE — IN_PROGRESS
- House checks, Arjun16 and horse6 stair routes PASS; compound landing added, normal horse jump preserved. Mount/exit/climb restart PASS. Side-aware swing added; wrist/stirrup contact fails review. Next fit poses: `docs/world/horse_stable.md`, `docs/world/player_stair_traversal.md`; estate/performance: `docs/world/government_house.md`.
- Landing/rail supports repaired: Metal pixels, 567 terrain samples, 20 piles and actual jetty walk PASS. Period form/joinery open; evidence/next: `docs/world/period_access.md`.

## BUILDING INTERIOR / EXTERIOR REFINEMENT — IN_PROGRESS
- 2026-09-27 IST. Government House hall runner/panels/beams and facade trim/roof coping; civic entrance trim, side visitor benches and runner added in `government_house.gd`, `civic_details.gd`, `civic_building.gd`. Residence headless PASS (65 route/46 stair/8 door); Metal exterior/hall/facade captures inspected. Civic headless/Metal PASS before latest bench/runner edit; validator knife call updated to current API. Next: re-run civic after latest edit, inspect fresh Metal pixels, document limits.

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
