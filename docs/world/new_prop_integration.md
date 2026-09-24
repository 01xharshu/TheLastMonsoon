# New prop integration — 2026-09-24

Three owner-added Blender assets are now used in the live world. Source files remain in `WorkingAssets/`; `tools/world/export_new_props.py` reproduces the cannon and signboard GLBs in `environment/props/new_assets/`. The supplied Enfield packet GLB is copied there unchanged.

| Prop | Live use | Evidence |
| --- | --- | --- |
| Enfield paper packet | Replaces the placeholder box on the District Police armoury supply pickup; retains `paper_cartridges` gameplay item and existing collision. | `docs/world/captures/new_ammo.png` |
| Wooden gun carriage and cannon | One static artillery display in the Company compound west court at `(316, 12.04, 313)` with blocking collision. | `docs/world/captures/new_cannon.png` |
| Suryagarh road sign | Beside the northbound road near the village at `(-184.1, 7.28, 180)`, facing the approach with blocking collision. Blender text is converted to meshes during export. | `docs/world/captures/new_signboard.png` |

Godot 4.7.2 imported all three GLBs. `tools/world/validate_new_props.gd` passed headless and Forward+/Metal, with all three world instances found and the captures above inspected. The sign initially faced away; it was rotated and recaptured. The packet is visibly pale under the current armoury lighting; it is used and legible as a prop, but material polish remains possible. Cannon is grounded in the court and sign posts meet the grassy surface in the captures. These are static props; cannon firing and broader historical approval are outside this integration.

`tools/world/validate_civic_world.gd` failed on 21 baked tree/rock road or plot intrusions from the existing landscape; its 172 route contact samples had a worst 0.091 m error. The failure was unrelated to these three prop nodes and was not changed here. The command wrote `docs/world/civic_world_validation.json`; preserve the concurrent landscape work while resolving it.
