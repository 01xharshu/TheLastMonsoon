# Current handoff
Updated: 2026-09-24 00:30 IST. Detail before this task: `docs/agent/history/2026-09-24-0023-pre-viceregal.md`. Read only relevant `docs/README.md` rows.

## INDIAN VILLAGE NPC PAIR — IN_WORLD_PREVIEW / VISUAL_REVIEW_FAILED
- Male/female adult MPFB sources, SHA manifests and 2.8 MB combined static Godot exports in `WorkingAssets/NPCs/village_{farmer,woman}/` and `characters/npcs/`; staged at Bhairavpur. No rejected Arjun source used. Period references, license and limits: `docs/characters/npcs/indian_peasant_pair.md`.
- Fresh Godot 4.7.2 Metal capture: `docs/characters/npcs/indian_peasant_pair_world.png`. Import/load passed; cloth and headwear visibly fail. No animation/interaction or 8GB-device proof. Next: fit draped clothes, texture skin, rig idle/walk and recheck in Metal before multiplying residents.

## BRITISH NPC MAKEHUMAN CANDIDATES — IN_PROGRESS
- Eight multiview rank/companion references are complete as concepts, pending owner review; see `docs/characters/british/README.md`.
- Updated: 2026-09-24 02:02 IST. Objective: improve realism of editable MPFB/MakeHuman British NPC candidates, beginning with the private and adult woman.
- Done: `tools/characters/build_british_private_pair.py` now uses fitted MPFB garment meshes in place of rigid sleeve/trouser tubes, assigns tunic/trouser colors by connected garment piece, adds restrained fabric grain, revises the curved skirt and headwear, and keeps two 53-bone bodies in one Blender source. Source and SHA manifest: `WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend`, `docs/characters/british/candidates/private_pair_manifest.json`. Front/side/back renders in the candidates folder were regenerated and inspected.
- Evidence/limits: silhouette/fit improved, but source garment seams and collar are modern, crossbelts and headwear still look simplified, skirt lacks true pleats and cloth simulation. Not approved visual assets or runtime NPCs. No other ranks modeled. See `docs/characters/british/README.md`.
- Next: hand-tailor historically correct garments/accessories on this pair, fix visible strap/headwear silhouette, test deformation in poses, then apply the validated costume method to the other seven pairs. Confirm unit-specific details and identities for final historical finishing.

## VICEREGAL RESIDENCE — IN_PROGRESS
- Objective: historically plausible, detailed multi-floor central Government House in fixed walled grounds with garden, rooms, windows, and road access. 1857 fictional Suryagarh; Calcutta Government House (1803) is period precedent, not 1929 New Delhi Viceroy House. Evidence: `https://rajbhavankolkata.gov.in/html/background.html`, `https://www.rashtrapatibhavan.gov.in/making-rashtrapati-bhavan`.
- Done: `GovernmentHouse` plot (-390,-110), 192x184 m grade 8.5 and connected road/avenue in `landscape_layout.gd`; layout audit PASS after road grading. New `settlements/government_house.gd` builds walled grounds, three-storey house, two wings, windows, rooms, stairs; instantiated from `settlement_builder.gd`. World scene UID-only diff untouched.
- Done: full scene loads with residence script; save-flow regression PASS, no script/runtime errors. Next: rebake terrain/nature/road/map, validate fixed plot and approach, inspect Metal captures. Historical/visual approval open.

## EXISTING WORLD / GAME — IN_PROGRESS
- Shared plot/route and civic audits previously passed; actual hall/police/compound traversal remains. World audits `tools/world/{audit_civic_layout,validate_civic_world,validate_field_map}.gd` and renders indexed in `docs/README.md`.
- Title/save/load/settings and river drink/pouch function; `tools/world/{validate_save_flow,validate_menu_navigation,validate_river_water}.gd` passed. River pose hand contact remains open.
- Arjun runtime appearance rejected by owner (`docs/characters/arjun/rejection_2026-09-23.md`); do not infer likeness approval. Weapon fit/contact remains open. Horse status: `docs/world/horse_stable.md`; anatomy/gait remain open. Next: rig, contact, then period carts. Boat/climb status in focused docs.

## CIVIC DETAIL / SIDEARMS — IN_PROGRESS
- Town hall and police interiors now have material texture maps, stair/entry collision, shutters, doors, records, lamps, armoury display and two original period sidearm props. `tools/world/validate_civic_interiors.gd` PASS on Forward+/Metal including upper-floor item collection and knife strike; four inspected `docs/world/captures/realism_*` views. Source/licence/historical limits: `docs/world/historical_accuracy.md`, `docs/world/civic_materials.json`.
- Rifle and Adams percussion revolver have ammo, shot audio and impact marks. `tools/weapons/validate_rifle.gd` PASS in headless and Forward+/Metal; inspected `docs/world/captures/realism_rifle_impact.png`. `player/knife_strike.gd` adds a short-range utility blade. Rendered weapon pose and sound balance remain unapproved. Current Arjun export remains owner-rejected; request the latest source file and do not approve fit from the rejected appearance.
- Next: await owner path for the latest Arjun body, then import and visually review it before any equipment fit acceptance. Police NPC candidates remain at unapproved blockout stage.

## ANIMAL TOOLS / DUALSENSE — IN_PROGRESS
- Installed Rigify includes Horse metarig; Animal Animator candidate is uninstalled. Core DualSense actions, sticks, horse gallop and pause mapped; action/menu/ride checks PASS without hardware. Full controls/device approval open. See `docs/world/animal_tools_and_controller.md`.

## SAFE RESUME
- Inspect exact diffs before edits; no broad reset/clean/stage. Keep this ledger under 60 lines/6000 chars (`python3 tools/check_agent_docs.py`). Preserve historical detail in focused docs. Later: NPC/story and combat.
