# Civic and residence realism — 2026-10-01

Scope: the existing Town Hall, District Police, and Government House interiors and exteriors. Existing plot positions, entrance ramps, stair layouts and pickup IDs are retained.

## Changes

- `building_finish.gdshader` / `building_realism.gd`: lime finish with smooth tonal variation, fine surface grain, high roughness and a restrained damp band at ground level. Civic plaster previously used the dark clay diffuse; the new finish reads as maintained lime rather than a uniform brown wall. Government House uses the same finish family with a cooler, paler tint.
- Government House central stone inset: small paving joints and individual slab variation, with a rough finish replacing the polished blank surface.
- Civic table aprons, connecting stretchers and trestle feet. Town Hall's empty lamp cages are replaced by reservoir, hood, cage and flame fixtures with local warm light, using the existing station lamp builder. Police retains its existing lamps.
- Government House chair legs and stretchers; ground-floor chairs lifted to the actual raised floor surface. Desk aprons, ledgers, paper and ink pots. Drawing sofas now have a seat frame, feet, separate cushions, arms and a back. Bedroom headboards, pillows and a folded cover make the bed arrangement legible.
- `validate_building_sites.gd`: extended full-world Metal capture to the Town Hall and Police interiors and Government House hall, study, drawing room and bedroom.

The finishes and furnishing are original procedural detail. This pass is visual design work and does not establish exact period provenance or final art approval.

## Verification

Government House focused validation exited 0, with 65 gate-to-hall, 46 stair and eight doorway samples clear and 74 windows retained (`/tmp/tlm_realism_house.log`). Godot reported one resource still in use during shutdown after the PASS marker. Civic interiors validation exited 0 and printed PASS (`/tmp/tlm_realism_civic.log`), including pickup and knife checks. New decorative joinery is non-colliding; the existing sofa seat collider is reduced to its new seat frame.

Metal capture command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --rendering-driver metal --path . res://tools/world/validate_building_sites.tscn
```

The latest full-world Forward+/Metal run on 2026-10-05 exited 0, passed site positions and saved all nine views with no error lines (`/tmp/tlm_building_realism_20261005.log`). The 1280 × 720 captures use fixed filenames, replacing previous images of the same views. Exterior lime finishes, civic lamps/joinery, stone hall paving, study chair support and bedding were inspected. The drawing-room view was moved in front of the sofa to expose its cushions and arms. No hardware performance or continuous player camera/contact approval is implied by these fixtures.

Current evidence: [Town Hall exterior](captures/building_site_town_hall.png), [Police exterior](captures/building_site_district_police.png), [House exterior](captures/building_site_government_house.png), [Town Hall interior](captures/building_site_realism_town_hall.png), [Police interior](captures/building_site_realism_police.png), [House hall](captures/building_site_realism_house_hall.png), [study](captures/building_site_realism_house_study.png), [drawing room](captures/building_site_realism_house_drawing.png), [bedroom](captures/building_site_realism_house_bedroom.png).

Final 2026-10-05 checks: civic interiors and Government House validators both exited 0; no parse or runtime errors remain. Government House retains its resource-in-use shutdown diagnostic after PASS. Logs: `/tmp/tlm_civic_realism_final_20261005.log`, `/tmp/tlm_house_realism_final_20261005.log`. A concurrent military helper had transient type-inference errors during the first checks; those declarations were corrected in the concurrent work before these reruns. The front-facing drawing-room recapture exited 0 and was inspected (`/tmp/tlm_building_drawing_20261005.log`). Capture/source hashes: [evidence inventory](building_realism_evidence.json).

The documentation index's 34 missing older screenshot links were marked retired. Its remaining file links resolve, but the shared handoff is still above its size budget; other task entries were preserved. Final whitespace check passes.

Remaining realism limits: repeated large window/column forms, broad sparsely furnished spaces, sharp procedural furniture edges, strong repeated wood texture and simple garden plants remain visible. This pass improves finishes, furniture construction and room function; it does not establish final architectural or character art approval. Source/evidence retention audit: `docs/assets/source_retention_2026-10-05.md`.

## Civic construction continuation

Town Hall and District Police retain their existing main-world footprints. Added timber boarding and rafters beneath the roof tiles, wall plates, jointed stone parapet coping, bench stretchers and record-shelf uprights/backs. Ground-floor ceiling beams now stop at the stairwell opening instead of visually passing through the ascent. Rear rain pipes have outlets and splash stones surveyed against the local terrain, with pipe extensions down to grade. Added geometry is merged with the existing static material batches and does not introduce new lights or downloaded assets.

`validate_civic_interiors.gd` now captures each upper hall as well as its exterior and ground floor at 1280 × 720. Initial focused headless run: `CIVIC INTERIORS PASS`, including entrance, stairs, supply acquisition and knife interaction. First native run also reached PASS but reported a Metal GPU fence timeout; that run does not establish clean rendered verification. Final capture/check status follows below. Continuous player camera/contact, exact historical reconstruction, owner art acceptance and 8 GB hardware remain open.

## Furniture and room bays — 2026-10-05

Scoped to Town Hall, DistrictPolice and GovernmentHouse. Furniture box visuals now use small rounded edges (18 mm maximum, reduced for thin members); existing collision boxes remain conservative. Timber visuals use physical metre UVs along member length with restrained procedural grain instead of the repeated dark-wood image. Structural timber receives a smaller 4 mm edge treatment. The shader deliberately keeps contrast low; this is a procedural finish, not scanned timber.

GovernmentHouse now has wall-side drawer sideboards and brass vessels, rugs around the writing/visitor bays, paired visitor seating on the first two levels and bedside chests upstairs. The drawing room has rounded upholstered seat cushions and low tables. Town Hall has east-wall records preparation cabinets and stacked folios. Existing police operational furniture is preserved. New large pieces have collision; rugs, handles and small decorative details do not. Door mouths, east stairwell and central hall remain outside the new furniture footprints.

Implementation: `building_realism.gd`, `building_wood.gdshader`, and the wood assignments in `civic_building.gd`/`government_house.gd`. Latest fixed-name captures overwrite prior evidence in `docs/world/captures/`. Verification logs: `/tmp/tlm_furniture_house_final.log`, `/tmp/tlm_furniture_civic_final.log`, `/tmp/tlm_furniture_metal_final.log`. Initial runs encountered an unrelated concurrent combat parser error; do not treat their PASS lines as a clean full-world result.

Visual limits: broad civic/residential proportions remain; this pass gives side bays a use rather than changing the surveyed building shell. Joinery and cushion profiles are still stylised, and final art/normal-speed player review remains open.

Verification update: `/tmp/tlm_furniture_civic_clean.log` completed **CIVIC INTERIORS PASS** with no script errors (stairs, entrance, pickups and equipment); GovernmentHouse reported 65 clear approach, 46 stair and eight door samples, though concurrent UI parser errors prevent calling that full run clean. `git diff --check` passed; agent docs checker passed after concurrent handoff compaction (36 lines/4802 characters). The first final Metal run suffered fence timeouts, so a replacement static evidence run freezes unrelated gameplay after scene construction (`tools/world/validate_building_sites.gd`); this verifies rendered building geometry and placement only. Fine-grain shader derivatives now suppress distant aliasing. Sofa cushions use closed rounded cuboids, independent of military furnishings.

Final evidence result: all nine replacement captures completed and latest study/drawing/bedroom/Town Hall pixels inspected. The static run also logged Metal fence timeouts and roadside-flag support warnings; these are explicitly recorded in the evidence manifest and do not establish a clean integrated renderer or performance pass. The temporary world-freeze fixture change was removed because it interfered with deferred terrain support. Latest evidence is retained for furniture/material review, replacing the same views. Next verification: rerun the unchanged full-world capture after concurrent world/UI work settles, then continuous player contact. Implementation and clean civic regression are complete; integrated renderer acceptance remains open.

## Integrated verification continuation — 2026-10-05

The unchanged full-world building capture completed all nine replacement views, exited 0 and contained no errors, warnings or Metal fence timeouts (`/tmp/tlm_building_resume_20261005.log`). All nine latest images were inspected. This supersedes the frozen-world captures for those same views; source/capture hashes are refreshed in `building_realism_evidence.json`. No gameplay freezing or terrain-support workaround was used.

Expanded `validate_world_camera_clearance.gd` to five Government House areas: ground hall, upper room, study, drawing room and bedroom. It checks the final pivot-to-camera segment, a camera-near-radius sphere against geometry and hidden player body during extreme wall retraction. The earlier minimum-distance assertion incorrectly classified the intended close-wall fallback as failure; geometric checks now verify that fallback directly. Latest result: `WORLD CAMERA CLEARANCE: PASS failures=0`, exit 0 (`/tmp/tlm_building_camera_final_20261005.log`). Shutdown still reports two leaked objects and one resource in use; this is not a clean lifecycle result. These stationary checks do not certify normal-speed camera transitions or sitting/bed contact.

Visible limits persist: simple repeated facade modules, sparse broad halls, stylised joinery and garden vegetation. Next: normal-speed route/contact review through the furnished bays and exterior approach, then targeted architectural/vegetation refinement.

## Continuous Government House route — 2026-10-05

The default-speed Player controller now has a reproducible continuous route from the portico through the study, first staircase, drawing room, second staircase and bedroom (`tools/world/review_government_house_route.gd`). Only the initial spawn is repositioned. Camera yaw turns gradually; no jumping or inter-room teleporting is used.

The route exposed an actual fall-through: both upper floorplates had a 16 m-wide cut across the twin stair bay. On the top floor the unused opening above the first flight remained, letting a diagonal walk from the second landing fall to the ground floor. `government_house.gd` now fills the unused strips on each level, retaining a 4 m opening around the arriving flight. First attempt also crossed the council table; route waypoints were corrected to use its side aisle without changing furniture.

Final full-world Forward+/Metal run: **GOVERNMENT HOUSE ROUTE PASS**, all 18 stages reached and zero blocked camera-segment frames. No script errors or GPU fence timeouts in `/tmp/tlm_house_route_fixed_metal.log`. Building regression: 65 approach, 46 stair and eight door samples PASS (`/tmp/tlm_house_floor_regression.log`); its existing two-object/one-resource shutdown diagnostic persists.

Latest evidence: `captures/government_house_route.mp4` (10 samples/s during ordinary runtime; no accelerated playback), `government_house_route_validation.json`, and five fixed endpoint images `captures/house_route_{entrance,study_bay,drawing_bay,second_landing,bedroom_bay}.png`. Sampled rendered frames around the stair exit and room paths were inspected. Redundant intermediate endpoint screenshots were removed; the video retains the continuous route. Footage is not a hardware performance benchmark or full human animation/contact approval. Sitting, lying on bedding, stair descent, owner art approval and broader Town Hall/Police routes remain open.

## Government House return route — 2026-10-05

Extended the actual-controller route to return from the bedroom, through the top room door/landing aisle, down both flights and out to the portico. `--return-only` performs this 12-stage review with one initial bedroom spawn and no later repositioning. The combined route also remains available. Hall waypoints now avoid the column, and the top landing approach follows the doorway rather than the solid room partition. No furniture or architectural collider was removed to obtain the pass.

Final full-world Forward+/Metal return run: **GOVERNMENT HOUSE ROUTE PASS**, 12/12 targets, zero blocked camera-segment frames and no recorded downward velocity beyond the -3 m/s fall threshold. No script errors, warnings or GPU fence timeouts in `/tmp/tlm_house_return_metal.log`. Prior combined attempts were rejected: a readback fence timeout and transient concurrently edited door/coachman errors; those source errors were already corrected in the shared workspace before the final fresh load. The rendered review supersedes those failed return attempts.

Evidence: [return report](government_house_return_validation.json), [return footage](captures/government_house_return.mp4), [second descent](captures/house_return_second_descent.png), [first descent](captures/house_return_first_descent.png), [exit](captures/house_return_exit.png). The approximately 41-second video preserves frame-file timing, with repeated frames in a 30 fps container; it is not accelerated and not a hardware benchmark. Stair-motion samples and endpoint pixels inspected. Earlier outward-route footage remains distinct evidence; the latest combined route has not yet completed in a single clean run. Sitting, bed contact, cloth/foot motion acceptance, final architectural art and Town Hall/Police round trips remain open.

Visual issue retained: nearby floor edges occupy a large portion of some descending camera angles (`captures/house_return_stair_overhead.jpg`). The camera-segment test passes, but this is not unobstructed framing approval. Next inspect stair headroom/framing before furniture contact.
