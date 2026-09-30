# Bhairavpur village construction

Status: **COMPLETE — expanded construction pass; final art and owner play review open**.
Updated: 2026-09-30 10:49 IST. Chat: `01a0e88d-3689-7963-8dd7-09f101cc449c`.

The owner requested a mix of homes, market and farms, then corrected the first sparse pass as too small. The enlarged live settlement now has connected quarters, household props, selected walled courtyards, a market/loading area and a cultivated western edge. The owner explicitly chose **buildings now; additional residents after existing NPC clothing/gait fixes**.

| Construction | First pass | Expanded pass |
| --- | ---: | ---: |
| Surveyed plot | 90 × 64 m | 208 × 176 m |
| Homes | 8 | 33 |
| Produce stalls | 2 | 8 |
| Cultivated beds | 2 | 12 |
| Added shade trees | 0 | 6 |
| Connected village lane chains | 0 | 6, totalling 939.41 m |

## Implementation and changed assets

- `world/suryagarh/settlements/bhairavpur_village.gd` builds the original eight homes plus infill, west residential lane, north/south rows and two eastern homes. House identifiers/centres 0–7 are retained. Household props use the existing CC0 bucket, pot, basket and stool assets. Selected homes have low courtyard walls with a central entrance.
- Eight shaded market stalls face a shared lane, with actual tray rims, produce instances, counter legs and storage. A separate grain shed has three bins.
- Twelve cultivated beds contain 432 small original plant instances. Six existing mango-tree assets provide shade, with physical trunk bounds. The well has a hollow visible shaft, rope and suspended bucket, plus the existing water-bag fill behavior.
- Procedural static geometry merges by material within each building/structure; physical piece collision and openings are retained. Imported props and foliage keep their source materials. This is batching implementation, not a measured performance-speedup claim.
- `world/suryagarh/settlements/settlement_builder.gd` delegates village construction to the module. Concurrent ammunition-store edits are preserved.
- `world/suryagarh/landscape_layout.gd` surveys the enlarged village terrace at 7.2 m with a smooth 30 m transition. Six shared route chains connect quarters and skirt the well. The landscape bake regenerated `world/suryagarh/generated/landscape.scn`, terrain tile/material resources and road mask; the field-map resource and `docs/world/bake_report.json` are refreshed.
- `tools/world/validate_village_area.gd` now tests physical terrain, actual Player movement, well collision and filling. `tools/world/capture_village_area.gd` captures the live scene at 1280 × 720.

## Verification

[Headless result](village_validation_headless.json): **PASS**. All 33 homes, eight stalls, twelve beds and six trees loaded. The 700 physical terrain ray samples include structure centres, nine points under each house foundation and the village lanes. Worst survey-to-baked-collision gap: **0.0000031 m**. The actual Player walked all six complete lane chains and the farm aisle without jumping; all seven routes passed. Walking into the well registered body contact and did not cross the shaft. Calling the well's interaction filled the existing bag by 2 L.

[Metal result](village_validation_metal.json): **PASS**, Forward+ / Apple M4 / 1280 × 720. Repeated the 700 ground samples and actual Player traversals through three selected western residential, market and farm sections (159 m total), plus well collision and bag fill. This is sampled renderer confirmation; the seven complete route chains were tested headlessly. Physics stayed at 60 Hz; fixed-fps/disabled-vsync fixture settings affect only this validation run.

Fresh live Metal images inspected: [overview](captures/village_overview.png), [market lane](captures/village_market.png), [western homes](captures/village_west_lane.png), [cultivated edge](captures/village_garden.png), [well](captures/village_well.png), [Player at well](captures/village_player_well.png). They show the denser layout, visible planted geometry and a hollow shaft with suspended bucket. Final period building detail and individual-house interior/motion review are not approved by these views.

Landscape bake: **PASS**, 144 tiles, 48.305 s; field-map bake: **PASS**, 1024 × 1024. Global `audit_civic_layout.gd` still reports exactly the three fort failures present in the HEAD report: OldFort grade spread, fort-trail slope and fort-access slope. Bhairavpur grade spread is zero and all six village route grades pass. No fort repair was made in this scope.

Commands and logs:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x720 --rendering-driver metal --script res://tools/world/bake_landscape.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/bake_field_map.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_village_area.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x720 --rendering-driver metal --script res://tools/world/capture_village_area.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x720 --rendering-driver metal --fixed-fps 60 --script res://tools/world/validate_village_area.gd -- --metal-samples
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/audit_civic_layout.gd
python3 tools/check_agent_docs.py
git diff --check
```

Logs: `/tmp/tlm_village_bake_20260930.log`, `/tmp/tlm_village_map_20260930.log`, `/tmp/tlm_village_validate_20260930.log`, `/tmp/tlm_village_capture_expanded_20260930.log`, `/tmp/tlm_village_validate_metal_20260930.log`, `/tmp/tlm_village_layout_20260930.log`. The JSON and images above are durable evidence. An earlier 5120 × 2880 capture stalled after two old-layout views; that process was terminated and the fixture corrected to an explicit 720p viewport. The final captures and runs exited successfully.

## Next action and acceptance limits

Owner review the enlarged village in normal play, including door/courtyard approaches and cart connections. The subsequent [architecture/craft pass](village_detail.md) adds roof variety, closed gables and household workshops; [period social landscape/night life](village_period_life.md) records later estate/pond/light additions. Final art remains separate. Add residents after the existing NPC clothing/gait defects are resolved, as requested. The water-fill test calls the interaction directly; it does not prove the complete E/hold prompt route or an authored rope-drawing animation. No new residents or NPC production approval were added in this pass.
