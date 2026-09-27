# New prop integration — 2026-09-24

Three owner-added Blender assets are now used in the live world. Source files remain in `WorkingAssets/`; `tools/world/export_new_props.py` reproduces the cannon and signboard GLBs in `environment/props/new_assets/`. The supplied Enfield packet GLB is copied there unchanged.

| Prop | Live use | Evidence |
| --- | --- | --- |
| Enfield paper packet | Replaces the placeholder box on the District Police armoury supply pickup; retains `paper_cartridges` gameplay item and existing collision. | `docs/world/captures/new_ammo.png` |
| Wooden gun carriage and cannon | One static artillery display in the Company compound west court at `(316, 12.04, 313)` with blocking collision. | `docs/world/captures/new_cannon.png` |
| Suryagarh road sign | Beside the northbound road near the village at `(-184.1, 7.28, 180)`, facing the approach with blocking collision. Blender text is converted to meshes during export. | `docs/world/captures/new_signboard.png` |

Godot 4.7.2 imported all three GLBs. `tools/world/validate_new_props.gd` passed headless and Forward+/Metal, with all three world instances found and the captures above inspected. The sign initially faced away; it was rotated and recaptured. The packet is visibly pale under the current armoury lighting; it is used and legible as a prop, but material polish remains possible. Cannon is grounded in the court and sign posts meet the grassy surface in the captures. These are static props; cannon firing and broader historical approval are outside this integration.

Follow-up on 2026-09-27: the reported nature intrusions were a headless MultiMesh readback artifact. A fresh Forward+/Metal civic run found **zero** nature intrusions across 2,120 trees and 720 rocks. `tools/world/validate_civic_world.gd` now marks nature as unchecked in headless mode instead of reporting false positions at tile origins. The current civic run still fails on a 1.87 m District Police foundation grade mismatch and two `fort_access` road/collision gaps of 0.128 m and 0.163 m after concurrent fort-trail edits. These are separate terrain/route issues, not prop failures. The new prop structural check passed again headless on 2026-09-27; live visuals remain the Metal captures above.
