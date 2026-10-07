# Jump, catch and rooftop climbing — 6 October 2026

## Implemented

Climbing uses the AnimationTree load, airborne reach, catch and hanging poses. Each transfer releases hand and boot contact during flight, then restores contact at the selected visible architectural layer. Entry requires a physical jump. Solid collision remains enabled; the standing capsule is restored only where it fits.

Architectural discovery includes masonry sills, window rails, beams, cornices, coping, parapets and roof edges. Roof catch height comes from the outside edge of a sloped roof, rather than its ridge. Closed shutter side faces are not used as the wall direction: the solid wall below the window supplies it. Grips recessed behind the facade are rejected. The body moves outside an overhang when its height reaches that overhang.

Ordinary Bhairavpur houses retain their source edge records before static geometry merging. These records refer to existing visible construction; they add no invisible ladder. Roof landings require physical support and standing room. A pull-up clears the parapet, crosses above it and settles onto the supported roof. Roof walking uses the normal solid character collider.

Firearm damage releases the grip. Covered and missed shots do not. The existing armed pursuer uses finite cartridges and the shared Enfield reload timing, which is currently 1.5 seconds; this does not establish historical reload-speed approval.

## Evidence

- Fixture: `tools/characters/validate_arjun_leap_climb.tscn`. Six routes: 0.75 m wall, 4.8 m wall, 12.8 m tower, 8.8 m building, production terrace house and production tile-roof house. The production houses use the actual builders and geometry merger.
- Run with `--house-only --capture` for native house/roof review; `--sloped-only` isolates the tile roof. `--debug-opportunities` prints survey/rejection data; `--debug-contact` prints failed palm distances.
- Forward+/Metal, Apple M4, 960 × 540 capture, 30 Hz choreography. House rooftop video (test output deleted).
- Native house result: `HOUSE CLIMB PASS routes=2 frames=268 palm=0.01159667316824`. Terrace and tile roof catch, parapet clearance, landing, solid walking and settled palm contact passed.
- Final six-route regression: `LEAP CLIMB PASS routes=6 flight_frames=468 settled_palm=0.01159662008286 frames=1706`. Grounded entry rejection, released flight contacts, solid-body overlap checks, covered/missed/landed shots, hostile NPC fire and collider restoration passed.
- The six-route headless run reports four ObjectDB instances and one resource still in use at exit. Cleanup remains open; it is not a clean-exit pass.
- Latest images: terrace roof (test output deleted), tile roof (test output deleted).

## Remaining acceptance

These are controlled fixtures containing production house geometry, not a full settlement escape playthrough. Full-world camera, route connectivity around every building, lateral traversal, roof-to-roof jumps, historical placement acceptance, clothing/boot deformation and owner approval remain open. A successful collision or palm check does not establish AAA animation quality. NPC reload acting remains separate from its ammunition/timing behavior.

The design follows Ubisoft's description of physically available grips and parkour transitions: [Assassin's Creed Shadows parkour overview](https://www.ubisoft.com/en-us/game/assassins-creed/news/4TA6gKaTvtOC1mOjZIxCZd/assassins-creed-shadows-parkour-system-overview). No claim is made that Rockstar animation footage was inspected frame by frame or that either game's animation assets were reused.
