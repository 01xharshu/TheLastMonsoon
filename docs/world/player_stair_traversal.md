# Player traversal on existing world stairs

Checked 2026-09-27 against the live Suryagarh scene. This uses the actual player controller and holds `move_forward`; it does not call `move_and_slide()` from the test or press jump. Each run starts at a stair landing with a fixed camera heading. Mouse camera input is disabled during the test so external cursor movement cannot steer the player off the staircase.

| Existing staircase | Up | Down | Landing heights above building origin |
| --- | --- | --- | --- |
| Town Hall | PASS | PASS | 0.90 → 6.30 m |
| District Police | PASS | PASS | 0.90 → 6.30 m |
| Government House, first flight | PASS | PASS | 1.24 → 5.50 m |
| Government House, second flight | PASS | PASS | 5.50 → 10.10 m |

All eight routes reached the expected landing without jump input. Descents showed no large falling velocity. Headless and native Forward+/Metal runs completed; final native run exited successfully. Durable measurements: [validation JSON](player_world_stairs_validation.json). Inspected native mid-ascent view: [Government House stairs](captures/29_player_world_stairs.png). Final run log: `/tmp/tlm_world_stairs_final_20260927.log`.

## Failure found and correction

The second Government House flight originally stopped the player at its lower lip. The step probe ended above the small rise. Its downward reach in `player/player_controller.gd` now accounts for capsule half-height, maximum step height and a small margin. Rechecking the live flight reaches the second floor.

The test was also corrected to identify jump input directly. Upward velocity while walking a slope is not itself a jump. A native Town Hall run with uncontrolled mouse input drifted sideways; fixing the test heading eliminates that artifact.

## Repeat

Launch as a normal scene so the project's autoload services are registered:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/world/validate_player_world_stairs.tscn
```

Add `--headless` for the movement checks without the capture. Source: [test controller](../../tools/world/validate_player_world_stairs.gd).

## Limits and next action

These four visible staircases use collision ramps beneath their treads. The result proves the real player can traverse those ramps and landings; it does not prove boots plant on every visible tread through a full animation cycle. The current capture uses the rejected temporary Arjun export and does not approve appearance or contact. Entrance steps, compound steps, fort routes, and sideways/diagonal approaches are outside this test's scope. Next: review stair foot planting through motion on an accepted Arjun model, then check those additional approaches when their geometry is stable.
