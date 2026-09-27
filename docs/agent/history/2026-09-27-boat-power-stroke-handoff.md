# Current handoff
## LONG-WEAPON AIM CAMERA — IN_PROGRESS
- 2026-09-27 23:00 IST. Objective: match supplied close right-shoulder aiming composition for Enfield and double gun while retaining two-hand support and centered sight. Existing long-gun path uses 0.95 m arm, 0.38 m right offset and 56 degree FOV; player camera/controller files have concurrent edits. Next: tune only long-gun aim values, capture both guns in Forward+/Metal, inspect pixels and run focused firearm checks.
## REFERENCE THIRD-PERSON CAMERA — IN_PROGRESS
- 2026-09-27 22:52 IST. Match user screenshot: behind Arjun, left-of-center silhouette, shoulder-height view, open forward vista. Existing 1.8 m centered spring arm and camera clearance inspected; player controller has concurrent unrelated edits. Next: adjust normal camera framing, run focused camera checks, inspect a fresh rear-view Metal capture.
## AIM HAND / CAMERA — IN_PROGRESS
- 2026-09-27 IST. Camera capture `/tmp/tlm_aim_camera_reference.png` exposed reversed pistol palm; fixing grip/wrist in `player/arjun_equipment.gd`. Next: fresh Metal capture and firearm check. Detail: `docs/characters/arjun/firearm_aim_camera.md`.
## WEAPON EQUIP / HORSE EXIT — IN_PROGRESS
- Updated 2026-09-27 IST. E equips new/owned shelf weapons; F dismount card persists. Equip/horse tests PASS. Now capturing Metal prompt pixels in isolated renderer scene. Next: inspect captures, repair layout if needed, update `docs/world/interaction_system.md`.
## CHARPAI SIT / SLEEP TRANSITION — IN_PROGRESS
- 2026-09-27 17:47 IST. Sit/recline pose, fade-covered 8h clock jump, energy restore/control release implemented; `tools/world/validate_charpai.gd` Forward+/Metal PASS (`/tmp/tlm_charpai_rest_final.log`). Captures show a hand below the bed and raised leg: visual approval BLOCKED. Next: author/fit sit and sleep rig clips and verify player-driven entry/wake. Detail: `docs/world/charpai_rest_transition.md`.
## RUINED FORT — BLOCKOUT
- Nav route PASS; player traversal/art open: `docs/world/ruined_fort_blockout.md`.
## ARJUN PRONE / COVER — IN_PROGRESS
- H toggles nearby cover; G stows/draws. Stance PASS. Distant shelter, contact and enemy sight open: `docs/characters/arjun/stealth_stance.md`.
## ARJUN ANIMATIONTREE — IN_PROGRESS
- 2026-09-27 IST. Idle/walk/swim blend PASS. Current task: integrate existing sit clips and rest blend into tree, replace charpai procedural limbs, retest Metal pose/contact. Detail: `docs/characters/arjun/animation_tree.md`.
## WORLD INTERACTION — IN_PROGRESS
- E/Q card, glint, ammo HUD, holds; chest Metal and five store pickups/save PASS. Contact, kneel and corpse loot open: `docs/world/interaction_system.md`.
Updated: 2026-09-27 IST. Archive: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`.

## PERIOD PROP PHYSICAL / PLACEMENT AUDIT — COMPLETE
- 2026-09-27 IST. Fixed Player stepping over low props. Final real Player test 14/14 headless PASS; Metal PASS before bench move. Crate/barrel moved behind stores, bench to guard area; fresh Metal and seven ground gaps (<1 cm) PASS. Stair regression PASS. Evidence and next 8GB/crowd review: `docs/world/period_props.md`.

## INDIAN VILLAGE NPC PAIR — VISUAL_REVIEW_FAILED / MOTION_BLOCKED
- MPFB static/walk candidates load; Metal walk phases have no prior body breakthrough, but drape, foot contact, period tailoring and 8GB performance remain unapproved. Next: tailor fabric, review full motion. Detail: `docs/characters/npcs/indian_peasant_pair.md`.

## BRITISH NPC — ANIMATIONTREE_BASE_READY / REALISM_OPEN
- Sixteen independent idle/walk trees and gait samples PASS; Metal views inspected. Skirts, sole contact, stride, realism and AI open. Evidence/next: `docs/characters/british/animation_tree.md`, `docs/characters/british/model_analysis_2026-09-27.html`.

## VICEREGAL RESIDENCE — IN_PROGRESS
- House checks, Arjun16 and horse6 stair routes PASS; compound landing added, normal horse jump preserved. Raised-landing dismount/ledge checks PASS; mount hand/foot contact open: `docs/world/horse_stable.md`, `docs/world/player_stair_traversal.md`; estate/performance: `docs/world/government_house.md`.
- Landing/rail supports repaired: Metal pixels, 567 terrain samples, 20 piles and actual jetty walk PASS. Period form/joinery open; evidence/next: `docs/world/period_access.md`.

## BUILDING INTERIOR / EXTERIOR REFINEMENT — IN_PROGRESS
- 2026-09-27 IST. Government House hall runner/panels/beams and facade trim/roof coping; civic entrance trim, side visitor benches and runner added in `government_house.gd`, `civic_details.gd`, `civic_building.gd`. Residence headless PASS (65 route/46 stair/8 door); Metal exterior/hall/facade captures inspected. Civic headless/Metal PASS before latest bench/runner edit; validator knife call updated to current API. Next: re-run civic after latest edit, inspect fresh Metal pixels, document limits.

## FOREST SHRINE — VISUAL_REVIEW_FAILED
- Forest/cave/idol preview; status, captures, next: `docs/world/forest_shrine.md`.

## EXISTING WORLD / GAME — IN_PROGRESS
- Focused systems PASS; civic traversal, river contact, Arjun approval and horse/cart live-world review open. See `docs/README.md`, `docs/world/horse_stable.md`, `docs/world/horse_cart_candidates.md`.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Wall-blocked sword and full forward/reverse/steering boat cycles PASS; blade-entry ripple added, Metal capture inspected, dry interior preserved. Final body/contact and sound open: `docs/world/historical_accuracy.md`, `docs/characters/arjun/combat_motion_2026-09-24.md`.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- 2026-09-24 06:16 IST. Input/rumble/glyphs/menu and Settings implemented; headless input, map, menu, rifle, bow, river and save tests PASS. Hardware verification remains. Next: physical DualSense USB/Bluetooth route and feel/gyro tuning. Limits/evidence: `docs/world/animal_tools_and_controller.md`; full prior status in history file above.

## DAY / STAMINA / FORAGE
- Movement drain/frame clock fixed; checks PASS: `docs/world/day_survival_forage.md`.

## SAFE RESUME
- Civic weapon shelves repaired; six support/bounds/access checks PASS. Render/history limits: `docs/world/weapon_store.md`.
- Preserve concurrent edits; no broad reset/clean/stage. Ledger gate: `python3 tools/check_agent_docs.py`. Later: NPC/story and combat.
