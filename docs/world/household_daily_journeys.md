# Wealthy household journeys

Updated 2026-10-05. [Rendered activity gallery](household_daily_journeys.html). Functional activity sequence; final authored motion and garment contact remain open.

The Indian landowner, wealthy merchant, British official and British woman each have a separate resident journey controller and personal AnimationTree. Their coaches wait until everyone has boarded and sat down. Residents walk through their home entrance, approach a carriage door, climb the running board, enter the cabin, turn and sit. At work they stand, climb down, walk through the office entrance, sit at a desk and use a ledger-work pose. They then stand, leave the office, board again, return, get out and walk back inside the home.

## Workplaces

| Household | Workplace | Centre x, y, z |
| --- | --- | --- |
| Landowner | Estate rent office | −309, 7.2, 315 |
| Merchant | Counting house | −367, 7.2, 312 |
| British couple | Estate office, separate desks/chairs | −463, 8.52, −124 |

These are small furnished office annexes near the existing household demonstration routes, not historically approved landmark buildings. The merchant's route goes south to a turning bay at z=330 to clear the public notice board, road traveller and market work area. The British couple use the accessible east carriage door with staggered entry/exit, while retaining separate passenger seats and office chairs. After returning to the narrow home frontage, their coach backs to the clear bay at z=−159 before turning for another trip. Coach corners turn gradually rather than snapping direction.

## Transition implementation

- Walking uses each resident's own walk animation, speed and facing. Capsule sweeps stop blocked movement; floor rays and a 0.31 m step allowance handle veranda/threshold levels.
- Climbing uses a lead foot, a following foot, and a delayed pelvis rise with leg solves. Cabin entry includes a forward duck. This is a procedural transition candidate, not a finished authored animation clip.
- Carriage doors open for entry/exit and close after sitting. Cabin sitting blends leg angles and root position over 1.4 seconds. The vehicle waits for the residents' seated states before departure.
- Office chairs have separate sit and stand transitions. The pelvis position derives from the resident's own rig and chair height. A right-hand solve follows a small ledger-work target; this is not a finished writing performance.
- Return walking uses the home entrance path and original interior location. Body collision is enabled for walking and disabled for vehicle/seat transitions.
- The demonstration waits 12 seconds at home and 18 seconds at work. It is not yet a clock-based 09:00–17:00 daily timetable or a citywide traffic/navigation system.

## Seated garment correction — 5 October

The British woman's existing seated gown candidate now belongs to her actor and follows her own pelvis and facing. It is reused at the office chair as well as the carriage seat. The standing skirt and waist transition are hidden while she works, and restored when she leaves the desk. This corrects the vehicle-only attachment; it does not provide simulated folds or blended sitting/climbing cloth. No human bodies were created or replaced. The current merchant/landowner GLBs each contain 14,517 body vertices; this count alone does not certify complete topology. Their exports have no clearly named separate foundation garment, so the shared [complete-body audit](../characters/npcs/whole_body_standard.md) remains open.

The focused `--work-only` capture mode refreshes the four desk-work views without replacing the distinct entrance/climbing evidence. The 5 October full-world regression passed: 362 office garment samples, zero pelvis-anchor error, all four residents visiting all 16 states, 13 independent trees, zero blocked walking/coach frames, and completed cycles 2/2/1 for landowner/merchant/British. Log: `/tmp/household_oct05_verified.log`. The initial first-work-frame visibility failure was fixed before this run. The earlier 1 October views for other stages retain their original dates.

## Evidence and limits

[World sequence checks](wealthy_households_validation.json): PASS on 2026-10-01. All four residents visited all 16 states; landlord completed two full cycles, merchant and British household one each, with a further British departure/backing manoeuvre and office arrival. No blocked coach or pedestrian frames; 13 independent trees and both new home entrances passed. Desk palm targets in the Metal capture run were within 0.3 mm. These are sampled rig points, not fingertip-contact approval. Passing these checks does not approve appearance, foot contact, finger grip or continuous motion. The Metal stills in [the capture manifest](household_journeys_2026-10-01/manifest.json) are reviewed separately. Standing garments still need dedicated seated/climbing deformation, especially the British woman's gown and Indian dhotis; camera framing and continuous motion review remain open. Home/work entrances are open passages in this scope; only carriage door leaves are animated.

## Files

- [Resident transitions](../../world/suryagarh/settlements/household_resident_journey.gd)
- [Timetable and coach coordination](../../world/suryagarh/settlements/household_coach_travel.gd)
- [Workplace layout and home paths](../../world/suryagarh/settlements/wealthy_households.gd)
- [Sequence check](../../tools/world/validate_wealthy_households.gd)
- [Metal captures](../../tools/world/capture_household_journeys.gd)

## Ownership, historical evidence and runtime budget — 5 October

This task owns the wealthy household residents, servants, their journey controllers and office/carriage clothing contact. Civilian thana police and military sepoy/roster bodies remain with their respective asset tasks: [thana staff](../characters/npcs/thana_staff.md), [British uniform candidate](../characters/british/sergeant_uniform_realism.md), and the shared [body audit](../characters/npcs/whole_body_standard.md). Those families require adult height/build variation through MPFB, complete underlying bodies and separate opaque foundations. Do not substitute identical scaled copies or claim period-approved uniforms from these household results.

Household dress, carriage and office details remain candidates pending cited historical evidence and visual approval. Reuse shared imported MPFB bodies, clothing materials and coach assets; retain source identities and foundations. Distance culling/LOD and bounded active simulation are required follow-up work: measure near/far controller, AnimationTree, CCD and rendering costs; preserve collision, combat, reserved seats and timetable state while reducing distant work. The present full-world cycles establish functionality, not that runtime budget.

[Garment lookup measurement](household_cloth_profile.json): five trials of 2,000 calls using the actual imported official woman. Median cached call 1.87 μs versus 9.0025 μs when rebuilding the garment lookup each call (about 79% lower). Both original garment parts restore on standing. This preserves the concurrent cache implementation and measures only this helper on the current host; it is not an FPS claim. Script: `tools/world/profile_household_cloth.gd`.

## Distance simulation — 5 October

Household travel now keeps near updates at the physics cadence and runs far controller updates at 10 Hz. A household becomes distant beyond 180 m from the current camera and returns to near updates within 150 m of its coach or any resident. This includes a resident already inside the office. The gap prevents repeated switching at the boundary. Elapsed time accumulates between far updates; journey phase, path, seats and completed trips remain intact. A stall contributes at most 0.1 s per callback and never triggers an unbounded catch-up loop. With no camera, the existing update path remains available. Explicit `step()` calls in route validation and captures remain unchanged.

The residents' personal trees are sampled manually, so the reduced controller cadence also reduces their bone/contact sampling. This does not yet cull household staff, horse AnimationPlayers, vehicle reins, collision or rendering. Near/far mesh LOD and whole-world CPU/GPU measurements remain open; no body geometry is removed.

[Scheduler regression](household_budget_validation.json): PASS. Over six seconds, 360 near updates versus 60 far updates preserve equal simulated time. Hysteresis, waking near an office resident, bounded stall debt and retention of journey state passed. This uses the production scheduler with an instrumented step; it does not constitute rendered motion/contact or whole-world performance approval. Prior full-world route checks used the same 0.1 s far step. Script: `tools/world/validate_household_budget.gd`.
