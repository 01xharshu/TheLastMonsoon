# Jump, catch and rooftop climbing — updated 8 October 2026

## Playable baseline

Entry requires a physical jump. A dedicated AnimationTree sequence supplies reach, hang, load, airborne leap and catch poses. It avoids interpolating through alternating pull poses during flight or running backward through unrelated poses during settling. Transfers release hands and boots during flight and restore contact at visible architectural layers. Solid collision remains enabled; a standing capsule is restored only where it fits.

Discovery uses existing masonry sills, rails, beams, cornices, coping, parapets and roof edges. Sloped roof grips use the outside edge height. Recessed grips, hidden meshes, moving bodies and shutter/hinge leaves are rejected; fixed frames remain eligible. Bhairavpur houses retain edge records before geometry merging. There is no added invisible ladder. Pull-ups clear parapets and settle onto supported roofs; walking and roof jumps use normal solid character movement.

Pull-up palm targets use the actual coping rather than the lower roof deck. The shoulders remain low while the hips rise, and tucked boot targets clear the solid parapet before crossing.

Sideways jumps follow continuous visible edges with space for both hands. They reject the end of an edge, occupied exits and exits without supported roof beneath them. The camera opens toward 2.8 m during climbing and the airborne catch window, retaining obstruction handling.

Hostile armed pursuers can shoot hanging, airborne and elevated roof targets. Actual landed damage breaks a climbing grip and produces body impact; misses and solid cover do not. The imported MPFB officer retains his AnimationTree base pose, then receives rifle hand contact. Loading raises the muzzle, brings a paper cartridge to it, returns the support hand and lowers the rifle. This uses the existing fast 1.5-second gameplay loading sequence; it is not a historically complete muzzleloader procedure or reload-speed approval.

## Current verification — 8 October

- Six-route headless regression PASS: low wall, 4.8 m wall, 12.8 m tower, 8.8 m building, production terrace house and production tile-roof house. 504 airborne samples; maximum settled player palm gap 0.0115966 m; 1843 frames. Collision, released flight contact, roof walking, lateral transfers and ballistic consequences passed. Maximum mantle palm gap 0.0212190 m; zero sampled boot penetrations during edge crossing. The dedicated leap/settle bone-pose check also passed.
- Additional lateral regression PASS: two transfers, edge-end rejection and rejection of a visible edge with an unsupported exit; mantle and roof walking passed. Maximum settled palm gap 0.0029413 m.
- Native Forward+/Metal armed fixture PASS, Apple M4: covered/missed/landed shots, hostile gating, grip release, collider restoration, grounded roof damage and impact reaction. Loading contact sampled through all 45 phases; maximum palm gap 0.0198040 m. Cartridge visibility and inability to fire during loading passed. Close Metal review caught a rifle obscured inside the torso; the loading anchor and barrel angle were corrected and fresh pixels inspected with the rifle outside the body. This does not approve every wrist phase or clothing deformation.
- Native house review PASS after the coping/shoulder/boot fixes: terrace and sloped roofs completed with the same 0.0212190 m maximum mantle palm gap and zero sampled crossing penetrations. Fresh hanging, flight and pull-up pixels were inspected; this does not approve every normal-speed wrist or clothing phase.
- Full Suryagarh native Forward+/Metal route PASS: street jump and roof access on `Settlement/BhairavpurHouse2`, then normal jump to neighbouring `BhairavpurHouse10`; supported landing, restored movement and camera separation passed. 324 frames, final position (-290.9322, 11.38091, 214.0). Normal startup also installed corrected saved-tree and shrine-forest trunk collision/support. This is representative connectivity, not every building surveyed.
- Test output is temporary and deleted on completion/failure/interruption. No screenshots, video, logs or generated reports are retained. Reusable fixtures and the runner remain.

## Repeat a check

From the repository root:

```sh
python3 tools/characters/run_climb_review.py
python3 tools/characters/run_climb_review.py --lateral-only
python3 tools/characters/run_climb_review.py --native --security-only
python3 tools/characters/run_climb_review.py --native --world
python3 tools/characters/run_climb_review.py --animation
```

The runner uses a dedicated OS temporary directory, redirects the engine log there and removes output even after interruption or timeout. Default timeout is 240 seconds; `--timeout` changes it. `--native --security-only --inspect-reload` holds the loading pose briefly for close review, then deletes output. `--native --house-only --inspect-climb` briefly holds hanging, flight and mantle checkpoints; `--inspect-mantle` isolates the pull-up view. `--route=wall` isolates an authored route. `--house-only`, `--sloped-only`, `--debug-opportunities` and `--debug-contact` remain available.

## In-game review

1. At an ordinary Bhairavpur house, approach a visible sill or coping facing the wall. Press Space to jump; the catch requires actual takeoff.
2. While hanging, press Space for the next transfer. Hold W + Space to continue successive transfers. Use A or D with Space along a continuous coping. S releases the grip.
3. Review the initial reach, settled palm orientation, body clearance, foot bracing, flight release, catch impact and parapet pull-up at normal speed.
4. Walk on the roof and jump toward a reachable neighbouring roof. Check landing and camera obstruction near the parapet.
5. During wanted pursuit near an armed patrol, compare an exposed climb with solid cover. A landed shot should release the grip; a blocked or missed shot should not. On the roof, shots should still damage Arjun and produce impact.

## Remaining acceptance

Normal-speed owner review of palm/wrist orientation, clothing and boot deformation remains open. All-building route coverage and historical architectural placement need further review. The loading gesture is a fast gameplay candidate, without the complete bite/powder/ramrod/cap procedure. Successful fixture and representative world routes do not establish AAA animation quality, historical approval or production readiness.
