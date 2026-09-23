# Task handoff

## World structure and progression audit — 2026-09-23
- Updated: 2026-09-23 13:59 IST. Task: current Codex task.
- Objective: audit and establish fixed British/civic plots, clearance and connected roads first; then improve map, save/load/settings and river water pouch interaction without crowding the HUD. Record Blake combat/climbing and British/Indian NPC story work as later priorities.
- Status: IN_PROGRESS.
- Completed: inspected live scene, layout, terrain bake, settlement builder, map and inventory. Audit found disconnected east police/compound and west town hall, narrow hard-coded tree exclusion, and divergent road rendering between shader/map/layout. Current startup opens directly into world; map has fixed scale and no input zoom; no save system.
- Files/assets changed: this ledger entry only so far. Preserve concurrent Arjun, boat, vegetation and weapon edits.
- Tests/evidence: read-only inspection of `world/suryagarh/landscape_layout.gd`, `tools/world/bake_landscape.gd`, `world/suryagarh/settlements/settlement_builder.gd`, `player/world_map.gd`, `project.godot`, and current `git status --short`.
- Blockers/failures: none for audit. Existing generated landscape was baked from older rules and must be regenerated for any terrain/vegetation layout change.
- Exact next action: centralize plot and road registry in layout; use it for terrain/vegetation, settlement placement and map; add geometric validation, rebake and inspect live collision/visuals.
- 2026-09-23 14:00 IST milestone: `landscape_layout.gd` now owns surveyed plot centres/footprints/grades and route segments; settlement construction reads these plots. `bake_landscape.gd` clears all plots and routes of vegetation and bakes a route mask; terrain shader samples that mask. This fixes code-source drift, but generated terrain/trees are still old until bake. Godot import/parse running as session 92458. Next inspect that result, add validator, then rebake and verify actual contacts/routes.
- 2026-09-23 14:03 IST milestone: Godot editor import exited 0. New `tools/world/audit_civic_layout.gd` checked surveyed plot grades and route continuity/slope; initial FAIL exposed the town hall spur (28.96% local grade) and overly broad village plot sample. Corrected village footprint to actual houses and graded the narrow hall spur; audit now PASS with route maximum slopes 0%, 4.46%, 15.08% and 18.31%. Audit output `docs/world/civic_layout_audit.json`. Next: launch landscape bake and then verify actual tree instances, building foundations and route pixels/physics in the fresh world.
- 2026-09-23 14:07 IST milestone: `bake_landscape.gd` required removal of a malformed concurrent `continue` inside terrain vertex generation; then `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/bake_landscape.gd` passed in 59.535 s, 144 terrain tiles, 2132 trees, 743 rocks, 470805 grass clumps. Generated terrain/road mask and report updated. Replaced map script with zoom/pan/waypoint behavior; editor import session 90623 still running. Next verify import and test live plot/tree/contact; create high-resolution precomputed map terrain texture.

## Charpai placement and Arjun reference check — 2026-09-22
- Updated: 2026-09-22 20:33 IST. Task: current Codex task.
- Objective: add the existing charpai to the latest Suryagarh world; locate Arjun multi-view for a subsequent MakeHuman/MPFB character pass.
- Status: COMPLETE (charpai placement and reference availability check).
- Findings: startup scene is world/suryagarh/suryagarh_world.tscn. Existing objects/charpai.tscn uses environment/furniture/charpai/charpai_01.glb and sleep interaction. No standalone multi-view found among project images; embedded Blender images still to inspect. MPFB data/logs exist in Blender 5.2 user configuration.
- Existing unrelated files: untracked WorkingAssets/Arjun/weapon_enfield_p53.blend and .blend1; preserve.
- Files changed: this ledger; world/suryagarh/suryagarh_world.tscn now instances the original charpai at (-264, 7.2, 210), within the flat village reserve.
- Milestone: existing asset integrated without modifying the mesh or interaction. Render/contact/interaction verification next.
- Verification: inspected project configuration, world runtime/layout, charpai scene/script, project image inventory. No project AGENTS.md or prior handoff found.
- Next: inspect embedded image inventory, instance charpai on flat Bhairavpur ground, run rendered placement and interaction checks.
- Arjun creation awaits reference confirmation; no character edits authorized in this immediate placement step.

- Initial runtime check found the inserted node missing due to an invalid scene-format comment; removed the comment and rerunning validation.

- User supplied two Arjun reference boards; preserve in WorkingAssets/Arjun/references before proceeding to character work. Image 1 is core appearance; image 2 is equipped appearance.

- Final verification: `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/validate_charpai.gd` exited 0 using Forward+/Metal on Apple M4. Four leg ground gaps = 0 m; ray hit charpai collider; interaction advanced 480 minutes and restored energy to 100. Results: docs/world/charpai_validation.json; inspected screenshot: docs/world/captures/06_charpai.png. `git diff --check` passed.
- Validation harness fix: imported leg meshes are nested, so contact inspection traverses recursively.
- Reference check: no standalone project multi-view or embedded multi-view in the three current Arjun .blend files. User subsequently supplied both boards; now saved with README in WorkingAssets/Arjun/references/. Existing character textures reference Blender 5.2 MPFB assets.
- Final changed files: world/suryagarh/suryagarh_world.tscn; tools/world/validate_charpai.gd; docs/world/charpai_validation.json; docs/world/captures/06_charpai.png; WorkingAssets/Arjun/references/{README.md,arjun_core_multiview.png,arjun_equipped_multiview.png}; CODEX_HANDOFF.md.
- Blockers: none for requested immediate charpai placement/reference check. Character creation not started.
- Exact next action: for the Arjun creation phase, inspect MPFB and existing body/rig, create a separate candidate against saved boards, and preserve the existing assets. No need to request the references again.

## Arjun MPFB reference candidate — 2026-09-22
- Updated: 2026-09-23 01:31 IST. Task: current Codex task, user requested continue working on Arjun.
- Objective: create Arjun using Blender MakeHuman/MPFB and saved owner multi-view boards; preserve existing assets and develop separate candidate with recoverable body/foundation, fitted core outfit and later equipment.
- Status: IN_PROGRESS.
- Completed: reconciled current handoff/status; references present; existing MPFB asset paths located.
- Files changed: ledger only for this phase.
- Verification/evidence: current git status retains prior charpai changes and unrelated Enfield files.
- Blockers: none yet; no new likeness/motion/runtime approval.
- Exact next action: run read-only Blender inventory of existing body/rig/MPFB properties, inspect reference and baseline renders; author candidate via installed MPFB.

- Arjun milestone: MPFB 2.0.17 enabled in Blender 5.2. Read-only inventory confirms no rig in v2; editable Human contains original face/body targets. Baseline render `/tmp/arjun_baseline.png` inspected: closed-neck shirt, skirt-like lower garment, mismatched hair/skin, bare feet. Existing source remains untouched.
- Next: author reproducible separate candidate using MPFB rig/asset fitting, replace deficient garments, add opaque fitted foundation, render multi-view and portrait checks.

- User explicitly requires walking, sitting and prone body animations. Include actual keyed clips, entry/exit transitions and clothing/contact review, not only named actions.
- Resume reconciliation: b01e765 independently integrated original v2 body, procedural locomotion/swimming, sword and bridge/map. Preserve those changes and unrelated untracked British_flag_01 files. New reference candidate remains isolated until visual checks.
- Build failure diagnosed: MPFB asset loading purges unreferenced materials; keep candidate materials with fake users during fitting. No candidate .blend was saved by the failed build.
- Next: fix material lifecycle, finish candidate render, then author walk/sit/prone clips against its rig and inspect contact/deformation.

- Candidate build now succeeds and saved WorkingAssets/Arjun/candidate/arjun_reference_candidate.blend; 53 MPFB bones. Inspected docs/characters/arjun/candidate_front.png: failed static review (hand masking, trousers intersect shirt at hips, cuffs detached, hair too glossy). Correct these before promotion. Current candidate is not runtime-approved.

- Latest user scope: add swimming; use existing Enfield gun and talwar with held and reference-based stowed idle states (gun/back, sword/waist); horse riding explicitly deferred. Both runtime GLBs now exist under environment/weapons/. Preserve their source meshes.
- Static correction milestone: restored forearm/hands, adjusted trouser/shirt clearance and sleeve-boundary cuffs; merged small detail meshes by material to 27 meshes. Candidate front rerender inspected; face/hair still below reference likeness.
- Animation authoring in progress: tools/characters/animate_arjun_candidate.py creates 53-bone keyed clips with two-bone limb solving; walk/sit/prone and entry/exit transitions. Next inspect rendered contact then extend swimming/equipment.

- Equipment control requirement: H toggles stow/draw during normal gameplay; entering swimming forces both weapons stowed and leaves them stowed on exit until H. Implement against current playable rig while candidate animation/likeness review continues.
- Initial animation renders saved and inspected. Walk ankle targets solve within 0.000001 m, but cloth deformations show failures: sash tail sticks outward sitting, hem/ankle pleats intersect, seated/prone finger support needs correction. Do not confuse IK numerical pass with motion approval.

- Runtime equipment implementation: player/arjun_equipment.gd instances existing gun and talwar in held/stowed sockets; H toggle, swimming forces stow, gun hands solve to stock support targets. Added hold-backtick/~ radial weapon wheel with pointer/arrow selection, release commit, Escape cancel and focus-loss cancel. Inventory/map/camera input guarded while wheel open. HUD updated. Runtime import/checks next; no verification claims yet.
- User requested circular weapon switching with ~; keyboard/mouse behavior recorded above.
- WorkingAssets/Arjun/candidate/.gdignore prevents automatic import of authoring studies; only a deliberate runtime GLB export should enter Godot.

- User spotted white Enfield. Confirmed GLB materials have metallic/roughness but no baseColorFactor or textures; Blender source uses procedural ColorRamp chains feeding Base Color. Fix by baking source colors into an embedded export texture, preserving original .blend.
- Equipment tests pass after reachable grip adjustment (both wrists <0.000001 m). Render review revealed imported Arjun faces +Z, requiring socket front/back correction; corrected and rerendering. Numeric grip pass is not finger/grasp approval.

- Owner explicitly selected the improved candidate screenshot as the playable base and requested continued refinement there. Promote that candidate after color-preserving export; this is direction/integration authorization, not final likeness or motion acceptance.
- Added scope: place owner's existing assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb along roads as British-colony markers, grounded and off the carriageway.
- Current source reconciliation: user committed work through 6011151; untracked Sang/river boat and related assets belong to other work, preserve.
- Gun correction complete in source-preserving export (tools/weapons/export_enfield_materials.py): embedded 2048 atlas, original metal/roughness; source SHA256 73b0afc99719af4cdd139919a7d7861779255fdb3ccca65d9a78b52f511fb283 unchanged. Runtime render shows wood and metal restored. User rejected sword grip; fixing palm/hilt/finger alignment next.

## Playable Arjun, timber crossing and field map — 2026-09-23
- Integrated the existing clothed `WorkingAssets/Arjun/arjun_character_v2.blend` as `characters/arjun/arjun.glb`; source unchanged. Reproducible exporter adds the MPFB game rig, transfers garment weights and embeds local textures. Runtime uses lightweight procedural locomotion, not final authored animation.
- Replaced the placeholder visual in the shared player scene. Existing movement, equipment, survival and interactions remain connected.
- Added a fictional period-style timber pile bridge at river z=165, with continuous deck collision, bank ramps, handrails and diagonal braces. Runtime clears vegetation/colliders only in the crossing corridor without rewriting baked landscape assets.
- Added M/Esc field map with terrain, roads, labelled future reserves, crossing, scale and live Arjun position. Map blocks gameplay/inventory conflicts and restores previous mouse mode.
- Validation: `tools/world/validate_actor_crossing.gd` headless physics run passes both crossing directions and continuous above-water surface samples; rig/map assertions pass. Rendered captures in `docs/world/captures/07_arjun_bridge.png`, `08_map.png`, `09_bridge.png`; `-- --capture-only` skips traversal for visual review.
- Other concurrent world/player edits may exist; preserve them. No source character assets overwritten.
