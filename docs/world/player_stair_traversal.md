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

These four visible staircases use collision ramps beneath their treads. The result proves the real player can traverse those ramps and landings; it does not prove boots plant on every visible tread through a full animation cycle. The current capture uses the rejected temporary Arjun export and does not approve appearance or contact. The follow-up below covers entrance and compound treads and modest angled approaches. Fort routes and every possible approach angle remain outside these checks.

## Exterior stairs and horse follow-up

The existing solid Government House entrance and compound wall-walk treads exposed failures that the indoor ramps did not:

- When blocked at a riser, the remaining acceleration-sized movement was too small to trigger step detection. Lowering that threshold permits recovery from a standstill.
- Keeping intended horizontal velocity after a successful step prevents a diagonal approach from losing forward speed and drifting sideways.
- A bounded whole-capsule downward sweep follows tread-edge contacts during descent. Clearance is handled by the collision sweep; jumps and drops beyond the step range remain ordinary physics. A short upward-step grace prevents descent correction from undoing an ascent before the body reaches the new tread.
- Ground snap is 0.45 m. Walking step height remains capped at 0.38 m.
- The compound staircase now has a 4.4 × 3 m upper landing at 4.8 m height, connected to the wall walkway. Its front edge overlaps the last tread without burying the preceding riser. This provides room for the horse to stop at the top.

Arjun exterior checks: straight/left/right entrance ascent, entrance descent, straight and angled compound ascent, compound descent and connection to the wall walkway. [Exterior measurements](exterior_stairs_validation.json). The original eight indoor up/down checks were rerun after the movement changes and passed.

The ridden horse now has the same bounded step and descent checks, using its own capsule offset. On detected stair contacts, pace is limited to 2.8 m/s. Stair-supported contact keeps its walk animation and hoof cadence instead of briefly switching to the jump clip. Normal jump input still lifts the horse, selects its jump clip and lands successfully.

Horse checks: up/down the Government House entrance, its first indoor flight, and the compound staircase: six routes passed with forward input and no jump input. [Horse measurements](horse_stairs_validation.json). Native Metal images inspected: [Arjun compound steps](captures/arjun_compound_stairs.png), [horse on the new landing](captures/horse_compound_stairs.png). Final logs: `/tmp/tlm_exterior_stairs_complete.log`, `/tmp/tlm_horse_stairs_complete.log`; indoor regression: `/tmp/tlm_internal_stairs_regression.log`.

Run the real-world scenes:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/world/validate_exterior_stairs.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/world/validate_horse_stairs.tscn
```

These passes approve movement access on the tested geometry. They do not approve Arjun's appearance, precise boot/hoof planting through the whole stair cycle, or galloping and sharp turns on every staircase. Next: refine full-motion foot/hoof contact and test further world routes as their geometry stabilizes.
