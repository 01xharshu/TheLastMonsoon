# Leela — character reference

Status: **BODY AND FACE REALISM IN PROGRESS; LIKENESS OPEN** (2026-09-30).

Leela is Arjun's love interest and appears later in the game. Her introduction point, role in the plot, personality, background, and relationship arc have not yet been specified.

The [first four-view reference sheet](../../../WorkingAssets/NPCs/leela/references/leela_multiview.png) shows front, side, back, and three-quarter views. It establishes dark wavy hair worn partly up with a long back section; a dark green embroidered tunic, rust-red drape and waist wrap, light gathered trousers, brown leather boots, wrist wraps, small earrings, and a pendant.

The [second multiview and face sheet](../../../WorkingAssets/NPCs/leela/references/leela_multiview_face_detail.png) adds full-body angles and close facial views. It shows a small bindi, loose face-framing curls, dark eyes, a high bun tied with red fabric, earrings, and a pendant. Its costume differs: a cream cropped blouse, layered red and olive drapes, gathered cropped trousers, and open sandals. Treat these as two visual directions for the same character; do not merge the incompatible garment and footwear details by assumption. The closer portraits provide useful facial reference, but neither sheet is a modeled, rigged, period-verified, or approved in-game asset.

Do not place Leela in the current early game world or imply a first encounter until her later story entry is designed. No age, occupation, hometown, or specific 1857 costume provenance is established by this sheet.

Source image SHA-256: first sheet `7eac284e7a5740ad593f766bf4aab1c5fbc35e773b45861af10639ff0f47b068`; second sheet `721d3d6319b59da03a369ec5923d97b10d1a547194071908f98116871a18c8e9`.

## Body first — current work

Owner direction initially: refine the body before clothes. On 2026-09-30 the owner authorized clothes alongside the remaining face/body work. The current [editable body source](../../../WorkingAssets/NPCs/leela/body_study/leela_body_study.blend) is built by [the body-study builder](../../../tools/characters/build_leela_body_study.py); its [manifest](../../../WorkingAssets/NPCs/leela/body_study/manifest.json) records the 53-bone rig, editable facial targets, and source hash. The anatomy review uses uniform clay shading. The source includes packed skin, eye, brow, lash, and temporary ponytail textures and the review cameras/lights.

2026-09-30 refinement: smoothed the anatomy surface, adjusted cheek/chin/lip shapes, reduced the open-mouth gap, added fitted brows and lashes, replaced the low-poly eyes, and introduced restrained skin relief/subsurface shading. Restored hair-card texture and alpha rather than covering the cards with an opaque material. The earlier floating brows/curls/bun were removed; the bindi now fits the evaluated forehead surface. Previous jagged body shader coverage was removed from the anatomy renders.

After owner feedback that the cup size did not match, increased bust fullness/projection and firmness while retaining the same shoulder, waist, and hip parameters. MPFB controls are `cupsize=0.66`, `firmness=0.68`; these are modeling settings, not a bra-size designation. The clothed references provide a silhouette estimate, and the body is still a candidate for owner review.

Latest landmark refinement (2026-09-30): broadened the eye openings, strengthened the cheek contour, softened/narrowed the chin, refined the nose bridge/tip, widened the mouth slightly, and raised the lip corners. Fitted fuller brows with a gentler angle. Darkened saturated iris pixels while retaining the sclera; switched skin relief to isotropic object coordinates after the profile render exposed stretched grain. The previous face/front-body renders are preserved in [the before-review folder](../../../WorkingAssets/NPCs/leela/body_study/reviews/2026-09-30-before-landmark-refinement/). Bust settings remain at the corrected values above.

Reference-calibrated face pass (2026-09-30): added the reversible `Leela_reference_face_fit` shape key using the second sheet’s frontal portrait. The fit narrows the cheek/jaw silhouette, shortens the lower face, and adjusts nose and mouth placement without changing the torso or corrected bust. Calibration and measurement scripts are `tools/characters/fit_leela_face.py` and `tools/characters/measure_leela_face.py`; local measurement requires MediaPipe 0.10.21 and its official face-landmarker model. The first fit reduced frontal landmark RMS from 0.0896 to 0.0429 iris-distance units (52%); this measures proportions, not identity or visual approval. A further outer-eye correction addresses the narrowed eye openings; the final frontal RMS is 0.0394 (56% below baseline). All eight views were regenerated from that same source. Baseline source and portraits are preserved in `body_study/reviews/2026-09-30-before-reference-fit/`. Automated profile detection failed on the rendered profile; profile depth remains a manual review task. Hair, brow shape and lip form still differ from the reference.

Review evidence: body front (test output deleted), side (test output deleted), back (test output deleted), three-quarter (test output deleted), relaxed arms (test output deleted), face front (test output deleted), face three-quarter (test output deleted), and face profile (test output deleted). Blender 5.2 Cycles renders were inspected. The relaxed-arm image is a static rig pose for proportion review; it is not an animation/contact test. Leela's likeness remains unapproved: eye/cheek balance, skin detail, and the temporary straight ponytail still differ from the reference portraits. No movement/contact or Godot appearance approval is implied by these static renders.

Next: continue matching the body silhouette and facial landmarks; author the wavy updo after the facial form settles. Continue garments alongside face/body refinement under the latest owner instruction. No world placement or gameplay actor has been added.

## Earlier clothed blockout — superseded

The reproducible [Blender builder](../../../tools/characters/build_leela_candidate.py) created an independent MPFB body with a 53-bone game-engine rig, an editable [Blend source](../../../WorkingAssets/NPCs/leela/candidate/leela_mpfb_study.blend), and an isolated [static GLB preview](../../../WorkingAssets/NPCs/leela/candidate/leela_static_study.glb). The [manifest](../../../WorkingAssets/NPCs/leela/candidate/manifest.json) records hashes and scope. It follows the first sheet's covered green-tunic, red-drape, light-trouser, brown-boot direction provisionally; the second sheet informs later face work. No gameplay actor, animation, or world placement was added.

Blender 5.2 generated front (test output deleted), side (test output deleted), back (test output deleted), and three-quarter (test output deleted) renders. They were inspected. **Visual review failed:** the generic face and low-detail ponytail do not capture either reference; the scarf is a rigid strip with poor shoulder fit; tunic, trousers, and boots have crude cylindrical shapes; skin, fabric, and embroidery lack the source's detail. This is an editable anatomy and palette blockout only, not a likeness or costume candidate for approval. Godot 4.7.2 headless project import completed, which checks file import rather than rendered appearance or movement.

The two reference sheets differ on outfit and footwear; the final costume choice remains open. This earlier clothing blockout is superseded by the costume study below.

## Clothes alongside likeness — current costume study

Owner authorized clothing work alongside the other refinements. The first sheet’s green tunic, rust-red shoulder drape, cream gathered trousers and brown footwear are the provisional direction. The second sheet continues to guide facial likeness.

Builder: `tools/characters/build_leela_costume.py`. Editable source: `WorkingAssets/NPCs/leela/costume_study/leela_costume_study.blend`. This opens the current body/face source, retaining the corrected bust and reversible face fit. The costume contains a fitted native bodice, separate split tunic panels, copper hem trim and embroidered sprigs, pleated front/back scarf, waist wrap/straps/buckle/pouch, gathered trousers, fitted footwear and boot shafts. Packed source and four rendered views are recorded by its manifest.

The first rendered draft exposed neckline/arm visibility gaps, an elevated scarf and trousers breaking through the skirt. Neck/arm coverage, scarf height and upper-trouser volume were revised after that inspection. This remains a **static costume fitting draft**, not an approved reference match: short sleeves need the reference’s longer rolled treatment; scarf edges/fringe, tailored neckline, boot fit, weave/embroidery scale and cloth folds need refinement. The generated skirt, scarf and trouser meshes are not weighted for movement. Facial lips/brows/profile and temporary ponytail remain open. No game actor or early-world placement was added.

Evidence: front (test output deleted), three-quarter (test output deleted), side (test output deleted), back (test output deleted). Next: tailored sleeves/neckline and scarf surface clearance, then cloth weights and movement review; continue facial/hair likeness alongside them.

### Sleeve and scarf refinement

Added forearm sleeve extensions and rolled cuffs, copper cuff stitching and front placket trim. Sleeve centers are sampled from the shaped body’s skin vertices, avoiding the earlier manually positioned tubes that floated or exposed the arm through their side. Added borders to both scarf edges and fine fringe to the hanging tail. Before-pass source and renders are preserved in `costume_study/reviews/before-sleeve-scarf-refinement/`. Refreshed four Cycles views after revisions. This remains a static fitting candidate: sleeve/bodice joins require tailoring, the neckline trim does not yet create the reference’s actual opening, and cloth motion/face/hair remain open.

Side-view inspection exposed excessive air between scarf and bodice. Added front/back ray fitting against the evaluated blouse so overlapping scarf vertices follow its actual surface with a small cloth clearance. Free hanging sections remain procedural. Neckline trim still floats at some angles and needs a surface-fitted sewn opening.

### Fabric realism pass

Added finer object-coordinate fabric relief, subdued broad colour variation and cotton sheen. Replaced the trousers’ regular vertical ribs with denser, less uniform angular/diagonal folds that fade at the endpoints; tapered sleeve cuffs and introduced small sleeve wrinkles. Scarf paths now interpolate smoothly between their anchors, and scarf/front-placket fitting evaluates the actual blouse surface. Fixed a builder variable collision that prevented the previously attempted scarf-ray fit from completing; the earlier source was still the pre-fit save. The new build completes the fit and refreshes the source/manifest/views. Increased boot-top coverage after the front render exposed trousers breaking through the old shaft rim.

Before-pass evidence: `costume_study/reviews/before-fabric-realism/`. Static realism still open: gathered cloth has an overly regular pattern, sleeve joins are separate pieces, scarf shoulder has an excessive rolled edge, and boot shafts need tailored calf shape. Face and hairstyle are still below reference likeness; no motion/cloth simulation approval is implied.

Final front inspection: trouser fabric is narrowed and folds fade inside boot shafts, eliminating the visible cream breakthroughs at the rims in this static view. Shoulder ray fitting reduces floating fabric but leaves a pinched fold that needs hand tailoring. These are visible fitting results, not motion/contact approval.
