# British garden route and visible ground contact — 1 October 2026

Updated: 2026-10-01 05:42 IST. Route/floor repair and source clothing review COMPLETE; skirt/sole motion remains under review. Task: British NPC continuation in the existing chat.

The earlier female contact capture hid the Player's lower legs. The Player capsule and foot bones were correctly placed on the EstateGround physics floor, but the NPC and approach stood inside a render-only parterre bed. At the sampled point the physics floor was 8.54 m, while visible bed/planting triangles reached 8.75 and 8.85 m. The terrain itself was 8.50 m. This was a placement defect, not an incorrect Player body offset.

`world/suryagarh/british_npc_roster.gd` now places the seven active women on the west/east GardenWalks at x=-442/-338 and y=8.63 m. Their 0.9 m patrols follow the paths in Z. The official's role/household placement is retained. After repair, the sampled rendered walk triangle and physics floor both measure 8.63 m. The body/model offsets remain unchanged.

Evidence: [before geometry](candidates/garden_ground_before_diagnostic.json), [after geometry](candidates/garden_ground_after_diagnostic.json), 105 support rays across seven routes (test output deleted). Each route samples its start/end and intermediate positions, with a 1.2 m wide footprint; all support gaps are zero at the sampled precision.

Before (saved from the prior committed capture):

Before: rendered planting covers Player legs (test output deleted)

Fresh Forward+/Metal after repair:

After: visible boots on paved garden walk (test output deleted)

The live PrivateWoman front/return/side/turn check passes after the route change, with 0 m stationary Player drift and about 0.225 m resume travel. All-sixteen personal trees and full-patrol foot-target regression pass. Full moving contact (test output deleted) passes 56 cases; stationary contact (test output deleted) passes all sixteen current placements.

The read-only Blender [skirt audit](candidates/private_skirt_weight_audit.json) identifies the rigidity: all 4,752 skirt vertices are weighted 100% to the pelvis, with no shape keys or cloth modifier. The 864-vertex waist bridge blends pelvis/spine weights but has no garment correctives. No Blender source or exported body was changed in this repair. Next: author a Private-woman skirt deformation candidate around the retained base body, then review walk/run/turn and seated entry/idle/exit before propagating it to other ranks.

Changed files/assets: `world/suryagarh/british_npc_roster.gd`, diagnostic/support/skirt-audit tools under `tools/characters/`, this document, `animation_tree.md`, handoff and the linked JSON/images. No script/physics errors remain in the final runs; existing full-world resource cleanup warnings remain in the logs. Ground repair is scoped to the seven garden routes and representative fresh Metal contact view.

Commands:

- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/characters/diagnose_british_ground.gd`
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tools/characters/validate_british_garden_ground.gd`
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --fixed-fps 60 --script res://tools/characters/validate_british_moving_contact.gd -- --actor=PrivateWoman --live`
- `/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/audit_british_skirt_weights.py`

Cloth drape, skirt deformation, heel/toe motion and every outfit's motion/contact acceptance remain open. The rigid skirt is visible in the fresh frame; restoring visible feet does not approve garment behavior.
