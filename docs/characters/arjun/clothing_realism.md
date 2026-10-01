# Arjun clothing and carrying construction — 2026-09-30

Runtime implementation: `player/arjun_clothing.gd`, `characters/arjun/cloth_detail.gdshader`, and the clothing setup in `player/arjun_visual.gd`. Source GLB and Blender assets preserved. This is a surface/construction pass on the owner-rejected temporary body, not replacement-character approval.

Cotton surfaces retain their source atlas, modeled seams, cuffs and folds. The shader adds filtered warp/weft detail, restrained dye variation, high fabric roughness, wet darkening and gradual drying. It does not simulate loose cloth or change garment geometry.

A separate 3 mm leather carrying belt has raised edges, brass buckle/tongue and hip keepers. Named hip_left, hip_right and back_upper mounts follow pelvis/upper spine respectively. `mount_item(item, point, local_fit)` attaches future item art; the back mount enables a 2.5 mm shoulder strap skinned between pelvis and spine. The strap remains hidden in ordinary gameplay until a back load uses that API. Existing weapon visibility and pouch placement remain governed by their own systems; this pass does not claim to refit all future equipment automatically.

Evidence: `clothing_2026-09-30/strap.png`, `wet.png`, `run.png`; isolated Metal fixture `tools/characters/capture_arjun_clothing.gd` (dry/wet/strap/run arguments). Front strap and wet fabric inspected; these are sampled rig diagnostics. Focused `validate_arjun_clothing.gd` PASS: cotton materials, wet/dry response, mounting API, mount movement with pose and belt dimensions. `validate_arjun_visual_tree.gd` PASS.

Open: final cloth silhouette and drape need mesh tailoring; loaded strap-to-shoulder pressure, seams/stitches, all-pose clipping, real item fasteners and continuous world motion require further art work. Future items must supply their own local fit and modeled loops/holsters; they are not considered realistic merely because they inherit a bone. Runtime appearance rejection remains in force.

2026-10-01 reference direction: the owner explicitly requires body, face and clothes to match both multi-view boards. Separate measured MPFB candidates and all-view renders are tracked in [reference fit status](reference_fit_status.md). Source cloth now has a fuller trouser drape and hidden-layer clearance beneath shirt/boots; runtime spring response/stitching does not establish exact likeness. Existing generic belt/strap remains a technical prototype and must be fitted to the equipped board before final approval.
