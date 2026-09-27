# CC0 period props — 2026-09-27

Seven Poly Haven 1K models now appear in the live Suryagarh world:

| Prop | Source | Placement | Evidence |
| --- | --- | --- | --- |
| Wooden Crate 02 | https://polyhaven.com/a/wooden_crate_02 | Behind Company stores at `(365, 12.08, 316.5)` | `captures/period_crate.png` |
| Wooden Bucket 02 | https://polyhaven.com/a/wooden_bucket_02 | Against a Bhairavpur house wall at `(-346, 7.2, 219)` | `captures/period_bucket.png` |
| Brass Pot 01 | https://polyhaven.com/a/brass_pot_01 | Beside the bucket at a Bhairavpur house | `captures/period_brass_pot.png` |
| Wicker Basket 01 | https://polyhaven.com/a/wicker_basket_01 | Beside a second Bhairavpur house | `captures/period_wicker_basket.png` |
| Wooden Stool 01 | https://polyhaven.com/a/wooden_stool_01 | Beside a third Bhairavpur house at `(-302, 7.2, 219)` | `captures/period_stool.png` |
| Painted Wooden Bench | https://polyhaven.com/a/painted_wooden_bench | Company compound guard rest area at `(330, 12.08, 256.5)`, clear of the central gate route | `captures/period_bench.png` |
| Wine Barrel 01 | https://polyhaven.com/a/wine_barrel_01 | Behind Company stores beside the crate at `(367.2, 12.08, 316.5)` | `captures/period_barrel.png` |

All seven source pages state **CC0**. Provider license: https://polyhaven.com/license. Exact downloaded glTF, binary, and texture URLs and SHA-256 checksums are recorded in `period_prop_manifest.json`. `python3 tools/world/fetch_period_props.py` downloads each source file and verifies it against Poly Haven's API MD5. Source packages remain unchanged under `assets/props/polyhaven/`.

`settlement_builder.gd` instantiates the imported models with mesh-sized static collision. Godot 4.7.2 imported all seven packages. The bench now serves as Company compound guard furniture; the barrel and crate sit behind the stores building. Village household objects remain beside rear house walls, away from the house doorways. The central compound gate route and village aisle remain clear in the inspected Metal views.

## Physical and visual check — 2026-09-27

The first actual Player approach test found that walk-step assist climbed over the low bucket, pot and basket despite their collision shapes. `player_controller.gd` now skips step assist after an actual slide contact with a body in the `solid_period_prop` group. It does not add an invisible barrier. `tools/world/validate_period_prop_collision.gd` drove the live Player straight at every object from two exposed directions without jumping. All 14 approaches stopped on the matching body in headless and Metal runs before the final bench relocation; the final headless rerun also passed all 14. Result: `period_prop_collision_validation.json`.

`tools/world/validate_period_props.gd` now compares each imported model's lowest world-space mesh point with the supporting floor ray. All seven gaps were between -0.010 m and +0.001 m in the final Metal run. The fresh crate, barrel and relocated bench captures above were inspected; each sits on its support. The existing eight-route real Player stair regression still passed after the step change (`/tmp/tlm_prop_stair_regression.log`). The headless collision test printed a Godot resource-in-use diagnostic only during shutdown after its PASS marker.

The stool and bench remain visual furniture without a seating action. Jumping, repeated crowd contact, exact 1857 object provenance, and 8GB-device performance have not been approved by these checks.
