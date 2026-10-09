# Tree grounding and solid trunks — 8 October 2026

## Repair

The imported broadleaf tree's lower woody trunk is offset from its asset origin. Origin-centred cylinders therefore blocked empty space and allowed walking through the visible trunk. The shrine's additional forest had no trunk collision.

`world/suryagarh/tree_trunk_collision.gd` measures three lower woody segments, excluding leaf and branch materials. It creates scaled collision at those segments for each rotated tree instance. The saved landscape replaces matching old cylinders; shrine trees receive the same geometry-based collision. The collision diagnostic colour is used only by the review fixture.

Root support is sampled beneath the actual woody base against resident `GroundCollision` terrain. Other trees, rocks, actors and buildings are excluded. Saved broadleaf roots embed 12 cm; shrine roots embed 10 cm. Visual instance transforms and collision move together. Runtime integration waits for the first physics frame. The original saved landscape, editable tree sources, horizontal placement, density and materials are retained.

## Verified scope

Native Forward+/Metal, Apple M4, 8 October: 2,050 saved broadleaf trees repaired, 1,885 roots adjusted by more than 2 cm; zero floating roots after repair. Maximum saved-root gap was -0.1199188 m. Every repaired instance had collision at its visible trunk, and a second repair made no duplicate colliders. The 520 shrine trees also passed terrain support and visible-trunk collision checks with zero failures.

Four rotated/scaled examples passed ray and player-sized swept-capsule checks. The old asset origin no longer had a displaced invisible trunk obstacle. A close native view of the retained tree mesh and temporary collision overlay was inspected. The normal full Suryagarh route also confirmed both repair hooks execute before street-to-house climbing and the roof escape.

Use native validation for instanced tree counts and transforms. This checkout's headless MultiMesh readbacks differed from native readbacks; the initial headless counts and grounding measurements are not accepted tree evidence. The runner selects native rendering for `--trees`.

Two ObjectDB exit warnings remain in the focused tree fixture. Geometry/physics passes do not establish a clean exit, final species/art approval, whole-world performance or 8 GB hardware certification. This repair covers the saved broadleaf batches and shrine forest, not every vegetation asset category.

## Repeat and play

```sh
python3 tools/characters/run_climb_review.py --trees
python3 tools/characters/run_climb_review.py --native --world
```

The fixture uses an OS temporary directory, redirects the engine log there, and removes output on success, failure, timeout and interruption. Screenshots, logs and generated reports are not retained.

In the normal game, approach broadleaf trunks in the eastern woods and the shrine forest. Walk into a visible trunk, then around it: the body and camera should be blocked by the wood, while the former origin position should be clear when no wood occupies it. Check the root meets the ground on a slope. Compare this with an ordinary Bhairavpur house jump/catch, parapet pull-up and jump to a neighbouring roof.

Climbing implementation and remaining motion/contact acceptance: [current climbing work](../characters/arjun/leap_climb_2026-10-06.md).
