# CC0 period props — 2026-09-27

Two Poly Haven 1K models now appear in the live Suryagarh world:

| Prop | Source | Placement | Evidence |
| --- | --- | --- | --- |
| Wooden Crate 02 | https://polyhaven.com/a/wooden_crate_02 | Company compound stores court at `(365, 12.08, 319)` | `captures/period_crate.png` |
| Wooden Bucket 02 | https://polyhaven.com/a/wooden_bucket_02 | Against a Bhairavpur house wall at `(-346, 7.2, 219)` | `captures/period_bucket.png` |

Both source pages state **CC0**. Provider license: https://polyhaven.com/license. Exact downloaded glTF, binary, and texture URLs and SHA-256 checksums are recorded in `period_prop_manifest.json`. `python3 tools/world/fetch_period_props.py` downloads each source file and verifies it against Poly Haven's API MD5. Source packages remain unchanged under `assets/props/polyhaven/`.

`settlement_builder.gd` instantiates the imported models with simple static collision. Godot 4.7.2 imported both packages. `tools/world/validate_period_props.gd` passed headless and Forward+/Metal structural checks, and produced the two captures above. Both objects appear textured and seated on their visible surfaces. The bucket is against the house wall and the crate is in the open court. These are static environmental objects; interaction, player traversal around the collision, broad scene composition, historical provenance, and performance on an 8GB machine have not been verified.
