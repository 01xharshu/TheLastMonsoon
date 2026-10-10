# Village household construction, cooking and carried lights

Owner request: varied modest wooden homes/fences, cooking smoke with a real exit, night fires and carried flame lights. Chat `01a120df-b177-7202-8669-0dc76fd8ee61`, 2026-10-09 IST. Status: integrated baseline; verification and final appearance approval remain distinct.

## Implemented scope

- `village_household_variety.gd` applies after the existing roof/opening/interior construction and before static batching. Six existing homes (9, 13, 15, 17, 21, 23) have fitted timber boards and corner posts, retaining the existing room and door/window collision voids. Their platforms have an earth finish. No home identifier or centre changed; Arjun/Dev's house is preserved.
- Four existing yards (9, 15, 21, 24) use low timber stake/rail fences. These replace their masonry yard boundary/gate and leave a three-metre walk-through entrance. Each fence section has a continuous physical envelope; adjacent lanes remain outside the yard.
- Eight existing cooking hearths (1, 5, 9, 13, 17, 21, 26, 30) have fuel/flame/warm light. Staggered cooking windows run approximately 06:00–08:32 and 17:00–19:32. At midday and late night they stop emitting; existing particles dissipate. This is household schedule ambience, not a new cooking NPC or food simulation.
- Six hearths sit beneath permanently open rear windows. Two terrace homes (26, 30) have a hollow masonry hood/flue and a real opening in both roof geometry and collision. No smoke is emitted through intact thatch. Rear shutter/grille removal is limited to those designated vents; side windows and doors retain their existing behavior.
- `village_combustion.gd` supplies bounded soft particles, flame and light. Smoke drifts with the shared `WindSystem`; gathering fires emit only during their existing night state. The maximum cooking particle capacity is 208 across eight hearths.
- The night gathering now uses four existing male MPFB residents, with two hanging oil lanterns and two empty-handed participants. `village_fire_gathering.gd` reuses their AnimationTrees and pauses their work only while attending. Lantern grip applies after locomotion, followed by cloth update; dawn extinguishes the lanterns and restores daily work. The earlier wooden torch fixture remains available for isolated prop review, but the gathering uses lanterns. No new people, body changes or runtime exports are introduced. Current gathering verification is recorded in `village_period_life.md`.

## Historical limits

These are original fictional household variants directed by the owner. Wood does not uniquely determine wealth, and the exact local construction/chimney forms are provisional. A British Library catalogue entry documents a drawing of a [temple and thatched hut](https://searcharchives.bl.uk/catalog/040-003955250); this supports a reference category, not authentication of these buildings. Do not label them an exact 1857 regional reconstruction or approve existing NPC clothing/body candidates from this pass.

## Reusable verification and review

Run `python3 tools/world/run_village_household_checks.py --headless` for the construction/clock/MPFB contact fixture; omit `--headless` for Forward+/Metal. Add `--world` for the integrated Suryagarh settlement. The runner creates all logs/captures in an OS temporary directory and removes them in final cleanup, including failure/interruption. Optional `--review-seconds 45` keeps images available briefly before deletion. No generated report or capture belongs in the checkout.

Checks cover retained home count, real fence entrance clearance, physical smoke passages, cooking activation at 07/12/18/22, and walking-palm attachment/incapacitation. The world route additionally checks both carried lights belong to existing residents. Static/native frames do not establish whole-game FPS, final historical appearance, finger wrapping or normal-speed long-route approval.

In-game: walk the old-village infill and western lane to compare timber and earth-plaster homes. Inspect the low fenced yards and walk their central gaps. At morning/evening cooking times, inspect rear smoke outlets and the two masonry flues. After 18:00, approach the eastern gathering fire and follow the existing men, two carrying lanterns. Check flame/clothing clearance through turns and near obstacles; return after dawn to check extinguishing.

## Verification status

Historical wood/hearth/torch checks (before the male-only lantern revision): focused headless construction/schedule/contact assertions PASS. Integrated Forward+/Metal world checks PASS: retained homes, fence entrance and smoke passage collision, cooking states, two existing resident torches and five seconds of actual normal-speed journey progress. World timber/window/flue/torch pixels were inspected. After the final shoulder-relative pose revision, native male and female walk/idle fixtures PASS; maximum requested reach error was 1.01 mm male and 11.30 mm female, with the prop anchored to the solved palm. Final night pixels inspected; shared fire-audio registration and incapacitation emission checks PASS. The final native runs exited without script/resource errors.

Earlier headless runs reported two to seven shutdown objects, and the first integrated headless run also retained two resources. This pass does not certify a clean headless whole-world exit. Native reviews overlapped other owners' renderer jobs after dispatch, so no FPS/performance conclusion is made. Existing unapproved clothing/body candidates retain their prior status. Long routes/turning contact, finger wrap from close views, final historical/art approval and listening remain open. Temporary logs/images were removed; no reusable source or test code was deleted.
