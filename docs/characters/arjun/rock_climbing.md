# Sloped rocks and broken edges — 2026-10-01

Ordinary static ledges now survey both hand positions and five points across a possible landing footprint. Separate collision bodies can provide support, so the two hands can grip different heights on a broken rim. The selected landing raises body clearance for uphill traversal. World collision and the existing path sweeps stay enabled.

`player/climb_surface.gd` rejects missing hand support, top normals with a vertical component below 0.65, left/right lip differences above 0.55 m, and landing footprint height spreads above 0.48 m. It searches three landing depths (0.65, 0.9 and 1.2 m), then checks standing capsule clearance. The usual 0.55–2.15 m ledge height range remains. These are conservative local samples, not a guarantee for every concave collision mesh or hole between samples.

During the mantle, each palm follows its own sampled height and surface normal. Palm orientation relaxes when a fully flat hand would put the wrist beyond the two-bone arm reach. Forearm rotation shares the palm turn with the wrist. Boot targets clear the sampled top and their soles follow its angle. The animation remains procedural; finger pressure, cloth collision and natural weight transfer still need refinement.

## Evidence

The Forward+/Metal fixture covers a rock tilted approximately 10.3 degrees and a broken rim with 1.20 m and 1.45 m front stones plus a separate 1.40 m rear platform. Fresh reach, transfer and recovery captures were inspected. Both routes complete with collision restored; the sampled palm targets at frames 18 and 36 are within 1 mm. This is bone-target evidence, not mesh-level contact approval.

- [Sloped rock motion](rock_climb_2026-10-01/sloped_rock.mp4), [reach](rock_climb_2026-10-01/sloped_rock_18.png), [transfer](rock_climb_2026-10-01/sloped_rock_36.png).
- [Broken edge motion](rock_climb_2026-10-01/broken_edge.mp4), [unequal rim grip](rock_climb_2026-10-01/broken_edge_18.png), [transfer](rock_climb_2026-10-01/broken_edge_36.png), [recovery](rock_climb_2026-10-01/broken_edge_50.png).

The videos preserve route timing (approximately 2.13 s and 2.27 s) from 61 deterministic samples. They are fixture playback, not live-world input footage. The crouched transfer still looks compact and stiff; the waist pouch also needs its separate attachment refinement.

`tools/characters/validate_arjun_rock_climb.tscn` reports **ROCK CLIMB: PASS** for the two routes, sampled palm contact, rotated entry, and rejection of a narrow lip, a landing hole and a steep support. Ordinary low/high ledges, window traversal in both directions, and the authored tall-wall step fixture also PASS after these changes.

Next: normal-speed player-camera review on actual world rocks and broken masonry, additional concave/diagonal edge cases, finger/boot mesh contact and cloth pressure. Moving objects and ladders remain outside this route. Structural checks and fixture captures do not close owner visual or production approval.
