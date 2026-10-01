# Wealthy household journeys

Updated 2026-10-01. [Rendered activity gallery](household_daily_journeys.html). Functional activity sequence; final authored motion and garment contact remain open.

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

## Evidence and limits

[World sequence checks](wealthy_households_validation.json): PASS on 2026-10-01. All four residents visited all 16 states; landlord completed two full cycles, merchant and British household one each, with a further British departure/backing manoeuvre and office arrival. No blocked coach or pedestrian frames; 13 independent trees and both new home entrances passed. Desk palm targets in the Metal capture run were within 0.3 mm. These are sampled rig points, not fingertip-contact approval. Passing these checks does not approve appearance, foot contact, finger grip or continuous motion. The Metal stills in [the capture manifest](household_journeys_2026-10-01/manifest.json) are reviewed separately. Standing garments still need dedicated seated/climbing deformation, especially the British woman's gown and Indian dhotis; camera framing and continuous motion review remain open. Home/work entrances are open passages in this scope; only carriage door leaves are animated.

## Files

- [Resident transitions](../../world/suryagarh/settlements/household_resident_journey.gd)
- [Timetable and coach coordination](../../world/suryagarh/settlements/household_coach_travel.gd)
- [Workplace layout and home paths](../../world/suryagarh/settlements/wealthy_households.gd)
- [Sequence check](../../tools/world/validate_wealthy_households.gd)
- [Metal captures](../../tools/world/capture_household_journeys.gd)
