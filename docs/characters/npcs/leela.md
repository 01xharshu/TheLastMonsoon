# Leela — character reference

Status: **EDITABLE MODEL STUDY BUILT; VISUAL REVIEW FAILED** (2026-09-28).

Leela is Arjun's love interest and appears later in the game. Her introduction point, role in the plot, personality, background, and relationship arc have not yet been specified.

The [first four-view reference sheet](../../../WorkingAssets/NPCs/leela/references/leela_multiview.png) shows front, side, back, and three-quarter views. It establishes dark wavy hair worn partly up with a long back section; a dark green embroidered tunic, rust-red drape and waist wrap, light gathered trousers, brown leather boots, wrist wraps, small earrings, and a pendant.

The [second multiview and face sheet](../../../WorkingAssets/NPCs/leela/references/leela_multiview_face_detail.png) adds full-body angles and close facial views. It shows a small bindi, loose face-framing curls, dark eyes, a high bun tied with red fabric, earrings, and a pendant. Its costume differs: a cream cropped blouse, layered red and olive drapes, gathered cropped trousers, and open sandals. Treat these as two visual directions for the same character; do not merge the incompatible garment and footwear details by assumption. The closer portraits provide useful facial reference, but neither sheet is a modeled, rigged, period-verified, or approved in-game asset.

Do not place Leela in the current early game world or imply a first encounter until her later story entry is designed. No age, occupation, hometown, or specific 1857 costume provenance is established by this sheet.

Source image SHA-256: first sheet `7eac284e7a5740ad593f766bf4aab1c5fbc35e773b45861af10639ff0f47b068`; second sheet `721d3d6319b59da03a369ec5923d97b10d1a547194071908f98116871a18c8e9`.

## First model study

The reproducible [Blender builder](../../../tools/characters/build_leela_candidate.py) created an independent MPFB body with a 53-bone game-engine rig, an editable [Blend source](../../../WorkingAssets/NPCs/leela/candidate/leela_mpfb_study.blend), and an isolated [static GLB preview](../../../WorkingAssets/NPCs/leela/candidate/leela_static_study.glb). The [manifest](../../../WorkingAssets/NPCs/leela/candidate/manifest.json) records hashes and scope. It follows the first sheet's covered green-tunic, red-drape, light-trouser, brown-boot direction provisionally; the second sheet informs later face work. No gameplay actor, animation, or world placement was added.

Blender 5.2 generated [front](../../../WorkingAssets/NPCs/leela/candidate/front.png), [side](../../../WorkingAssets/NPCs/leela/candidate/side.png), [back](../../../WorkingAssets/NPCs/leela/candidate/back.png), and [three-quarter](../../../WorkingAssets/NPCs/leela/candidate/three_quarter.png) renders. They were inspected. **Visual review failed:** the generic face and low-detail ponytail do not capture either reference; the scarf is a rigid strip with poor shoulder fit; tunic, trousers, and boots have crude cylindrical shapes; skin, fabric, and embroidery lack the source's detail. This is an editable anatomy and palette blockout only, not a likeness or costume candidate for approval. Godot 4.7.2 headless project import completed, which checks file import rather than rendered appearance or movement.

Next: sculpt the face and hair against the close portraits, tailor actual garment meshes from the selected costume direction, and fit/weight the drape and lower clothing. Then review neutral-pose renders before authoring motion or considering in-world use. The two reference sheets differ on outfit and footwear; the final costume choice remains open.
