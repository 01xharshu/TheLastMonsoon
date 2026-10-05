# Current handoff — Updated: 2026-10-05
Details preserved: `docs/agent/history/2026-10-05-handoff-before-asset-09-compaction.md`. Preserve concurrent edits.
- **BRITISH MILITARY SITES — ART_OPEN**. Services: 12 walks/cemetery/terrain PASS; final Metal fence errors under review. `docs/world/cantonment_service_realism.md`; fort: `docs/world/military_site_contact.md`. Next: cloth/joinery/vegetation.
- **CIVIL LINES — IN_PROGRESS**. Next: ridge refinement. `docs/world/civil_lines.md`
- **WEALTHY HOUSEHOLDS — ART_OPEN**. 10-05: seated gown follows wearer at coach/office; refreshed checks in progress. Next: blended cloth/continuous contact. `docs/world/household_daily_journeys.md`
- **HOUSE ACCESS — CLOTH/LATCH PASS / ART_OPEN**. Next: integrated close check, player-camera pacing. `docs/world/staff_clothing_and_latch_motion.md`
- **BUILDING REALISM — ART_OPEN**. 10-05: nine full-world Metal views clean/inspected; five camera areas PASS, shutdown leaks remain. Next: normal-speed route/contact. `docs/world/building_realism_2026-10-01.md`.
- **ARJUN / DEV HOUSE — IN_PROGRESS**. Next: ageing/sweep. `docs/world/arjun_dev_home.md` `docs/world/opening_sequence.md`
- **ASSET-FIRST HOUSEHOLD BATCH — IN_PROGRESS**. Ledges/rubble support + Metal PASS; placement/art open. Next: craft tools; animations last. `docs/assets/ledge_rubble_batch_09.md`
- **MOUNTED RIDER REALISM — IN_PROGRESS**. Paid/disk + coachman foot/response Metal PASS. Next: lap cloth/sole/continuous road motion, remaining stops/cold load. `docs/world/paid_coach_travel_2026-10-02.md`
- **TITLE MENU — ROUTE_BLOCKED**. Next: rerun after arjun_visual.gd parse error. `docs/world/title_menu_design.md`
- **BHAIRAVPUR — IN_PROGRESS**. Next: tack/gait. `docs/world/village_period_life.md`
- **HOOGHLY PORT REALISM — COMPLETE / ART OPEN**. Next: owner/geometry polish. `docs/world/hooghly_port.md`
- **THANA POLICE NPCS — OWNER TAN CANDIDATE**. 10-05: tan reference/fitted pockets + belt, interpolated cloth weights; arrest headless/Metal PASS. Historical/close motion open. `docs/characters/npcs/thana_staff.md`
- **DEV — CANDIDATE**. Next: collar/drape/feet. `docs/characters/npcs/arjun_brother.md`
- **ARJUN TALL CLIMB — IN_PROGRESS**. Next: camera/weight review. `docs/characters/arjun/jump_grab_2026-10-01.md`
- **LONG-WEAPON SIZE — IN_PROGRESS**. Next: side/aim/cheek/grip. `docs/characters/arjun/animation_tree.md`
- **AIM HAND — IN_PROGRESS**. Next: body fit. `docs/characters/arjun/reload_cartridge_contact_2026-09-30.md` `docs/characters/arjun/firearm_aim_camera.md`
- **CHARPAI SIT — IN_PROGRESS**. Next: see focused detail/archive. `docs/world/charpai_rest_transition.md`
- **ARJUN PRONE — IN_PROGRESS**. Next: see focused detail/archive. `docs/characters/arjun/stealth_stance.md`
- **ARJUN ANIMATIONTREE — IN_PROGRESS**. Next: see focused detail/archive. `docs/characters/arjun/animation_tree.md`
- **ARJUN MULTI-VIEW — NOT_EXACT**. Next: hair/cloth. `docs/characters/arjun/reference_fit_status.md`
- Errand saves PASS; motion next: `docs/world/errands_and_paid_work.md`
- **PURPOSE NPC BATCH — IN_PROGRESS**. Next: re-export/test gait, inspect silhouette/portraits. `docs/characters/npcs/purpose_npcs.md`
- **INDIAN NPCS — VISUAL_REVIEW_FAILED**. Next: cloth. `docs/characters/npcs/other_indian_npcs.md` `docs/characters/npcs/indian_peasant_pair.md`
- **BRITISH NPC — IN_PROGRESS**. Next: collar/folds/contact:. `docs/characters/british/sergeant_uniform_realism.md`
- **VICEREGAL RESIDENCE — IN_PROGRESS**. Next: see focused detail/archive. `docs/world/horse_stable.md` `docs/world/period_access.md`
- **40-LOCATION WORLD — PROTOTYPE**. Next: post/telegraph. `docs/world/administrative_realism_2026-10-01.md` `docs/world/administrative_district.md`
- **CIVIC DETAIL — IN_PROGRESS**. Next: skin/cloth, sound/player feel. `docs/characters/arjun/combat_motion_2026-09-24.md`
- **ANIMAL TOOLS — IN_PROGRESS**. Next: see focused detail/archive. `docs/world/animal_tools_and_controller.md`
- **CATTLE — ART OPEN**. Next sculpt/cloth: `docs/world/cow_and_resident_motion_2026-10-05.md`.
- **RESUME — IN_PROGRESS**. Next: art/save/global wanted. `docs/characters/arjun/police_arrest_sequence.md` `docs/world/police_refinement_2026-09-30.md`
- **ARJUN COMBAT — IN_PROGRESS**, updated 2026-10-05 IST/root. Tree melee/protection/MPFB rescue/road patrol/capture paths authored; locomotion/combat/station arrest PASS. Next: finish rescue fixture and full-world/Metal contact checks. Files, evidence, failures: `docs/characters/arjun/combat_rescue_2026-10-05.md`; realism/performance/owner open.
- **WOMEN MORNING RIVER ROUTINE — IN_PROGRESS**. Next: implement two-bone contact solver; review every stage at normal speed; prior Metal contact FAILED. `docs/characters/npcs/women_river_routine.md`
- **RUNTIME OPTIMISATION — IN_PROGRESS**. Next: behaviour/CPU benchmark + native after profile. `docs/world/runtime_optimisation.md`
- **ESCAPE MAP / SETTINGS / WAYPOINT — IN_PROGRESS**. Next: resolve `/tmp/tlm_escape_validation.log`, then Metal/settings/input checks. `docs/world/escape_map.md`

- **WORKSPACE / HOURS / CART PARKING — FOUNDATION PASS / WORLD REVIEW OPEN**. 10-05: five duplicate screenshots removed (2.8 MB); solid map/menu icons; fixed cart standing map anchors, household reservation guards, configurable overnight door hours. Hours/boarding/office/runtime checks PASS; bay geometry/occupancy and full-world smoothness open. Details: `docs/world/workspace_optimisation.md`. Next: native bay clearance + target hardware profile.

## ESCAPE MAP / SETTINGS / WAYPOINT — IN_PROGRESS
- Updated 2026-10-05 IST/root: three Escape/Options tabs, live quality, persistent keyboard controls, site icons/cluster zoom and depth-tested destination stake/arrival fade implemented. Files/evidence/commands: `docs/world/escape_map.md`.
- Headless first full-world PASS with stale settings callback errors; teardown fixed. Latest marker placement failed after only 3 process frames; physics synchronization added. Native UI layouts captured; full-world Metal fence timeouts are invalid performance evidence.
- Next: run final focused regression and inspect refreshed native UI/marker evidence. Preserve concurrent map/save edits.
- **HORSE SPEED / MAP — IN_PROGRESS**. Next: household regression; other checks PASS. `docs/world/horse_vehicle_speed_and_map.md`
