# Thana staff — 1857 Suryagarh

Status: **OWNER_REFERENCE_DETAIL_CANDIDATE / FULL_BODY_RETAINED / ART_AND_HISTORICAL_REVIEW_OPEN** (2026-10-05).

The DistrictPolice ground floor has a daroga, mohurrir and burkundaz. They now have independently animated bodies and clothing; the daroga and burkundaz participate in the [station arrest sequence](../arjun/police_arrest_sequence.md). The clerk stays at the record-room post. Their role metadata does not create floating labels.

## Uniform and Sikh variety

The current owner-selected outfit uses tan tunic/trousers and matching headwear, brown leather waist/diagonal belts and a small pouch, brass fastenings, four flap pockets with centre pleats, shoulder tabs and wrapped lower legs. Fittings are sampled against the garment surface and use interpolated garment weights. The Sikh guard has crossing tan turban courses and an uncut beard; the other staff retain cloth caps. All bodies remain complete MPFB meshes beneath separate opaque adult foundation garments. The three actors still share the same base adult physique; distinct identities and final tailoring remain work.

These are provisional outfits for a fictional 1857 district, not an authenticated regulation pattern. The [National Army Museum's record for Rattray's Sikhs](https://collection.nam.ac.uk/detail.php?acc=2013-10-20-37-66) dates the decision to raise Bengal military police to 1856 and records recruitment in the Punjab, including former Sikh soldiers. This supports Sikh police representation in the period. It does not establish a detachment or its exact clothing at fictional Suryagarh.

The [British Library catalogue's Central Provinces police portrait](https://searcharchives.bl.uk/catalog/040-003063129) records a dark-blue uniform and safa, but its regional and dating limits prevent treating it as the exact 1857 local pattern. The [National Army Museum's 1890 Rattray's study](https://collection.nam.ac.uk/detail.php?acc=1964-12-77-1) explicitly dates the pictured scarlet/white facings to their adoption in 1885; those later details were not used for the 1857 candidate. Plain fittings carry no later regimental number, modern rank insignia or modern police badge. The earlier drab/indigo palette has been superseded by the owner-selected tan reference; its local 1857 dress specification is still unverified.

The [BPRD police history](https://bprd.nic.in/uploads/pdf/201905071150110985311Report-1.pdf) supports a daroga and armed station men before the 1861 law. The existing three-role set remains a fictional staffing choice; military-police recruitment evidence must not be used to equate every local civilian thana with Rattray's battalion.

## Local historical evidence — 2026-10-02

The primary [North-Western Provinces administration report for 1855–56, printed page 36](https://upload.wikimedia.org/wikipedia/commons/a/a2/Report_on_the_Administration_of_Public_Affairs_in_the_North-Western_Provinces%2C_for_the_year_1855-56_to_1861_%28bounded_together%29_%28IA_dli.granth.108291%29.pdf) records a province-wide order for police, revenue and customs uniforms, citing the notification of 28 December 1854. It also records earlier variation by district and magistrate. This establishes a relevant pre-1857 uniform requirement, **not the garment pattern or colour**. The notification itself has not yet been located.

| Feature | Evidence and decision |
| --- | --- |
| Uniformed North-Western Provinces station men | Supported by the 1855–56 report; retain uniforms. |
| Sikh identity | Period military-police recruitment evidence supports representation, but does not prove this local posting. |
| Drab cotton and indigo facings | Unverified local design choice; do not describe as regulation khaki. |
| Standing collar, buttons, caps, belt and shoes | Candidate fittings; require the actual local dress order or a dated local portrait. |
| Later scarlet Rattray uniform | Excluded: museum dates the white facings to 1885. |
| Bombay, undated Central Provinces and circa-1880 portraits | Comparative references only; cannot authenticate an 1857 North-Western Provinces thana. |

Appearance pass: trouser ease now increases through the thigh/knee, turban cloth courses overlap and cross with a smaller envelope, and indigo headwear/fittings receive the existing filtered cloth shader. All human bodies remain the existing MakeHuman/MPFB source; no replacement body or placeholder was built. These are geometry/material refinements, not historical approval. Next historical action: locate the 28 December 1854 notification and establish its dress specification before replacing the provisional palette/cut.

## Sources and performance scope

`tools/characters/build_thana_motion.py` uses `WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend`. The original static thana previews remain separate. Motion exports are `characters/npcs/thana/{daroga,mohurrir,burkundaz}_motion.glb`; editable per-role sources and manifests are under `WorkingAssets/NPCs/thana_motion/`.

MPFB core body/skin provenance remains CC0 as recorded in the [village pair notes](indian_peasant_pair.md). Uniform fittings, shoes, trousers, turban folds and beard are original project geometry. Museum/catalogue pictures are references only; none are copied as game textures. Existing skin/eye textures are reused, with small plain cloth/leather materials rather than new large texture maps. Only the existing three station staff are placed. This limits added scope but does not certify 8 GB hardware performance.

## Review evidence

`tools/characters/validate_thana_staff.gd` checks all three actual-world roles, station placement, skeletons, independent AnimationTrees and animated collision bodies. The arrest route separately checks officer restraint contact and collision clearance. Metal review captures are `thana_daroga_uniform.png`, `thana_mohurrir_uniform.png`, and `thana_burkundaz_uniform.png`; `tools/world/capture_thana_uniforms.gd` chooses a camera sight line that is clear of room walls.

The export review caught and corrected masked-out trouser sections, accidental MakeHuman helper geometry and turban-fold rotation around the world origin. Fine tailoring, sleeve/neck fit, beard shape, cloth motion, distinct likenesses and exact local historical pattern still require review. The tunic is an improved role candidate built on the existing source, not a finished bespoke period uniform.

### 2026-10-02 validation

All three station actors passed the focused rig/AnimationTree/placement check. The actual-world arrest regression passed approach, restraint, escort, cell entry, waiting, stand, release and return, plus theft/abort cases; escort distance 17.01 m and restraint palm error 1.135 cm. The underlying-cloth addition after this run changes only headwear geometry; it does not alter the rig or arrest script. Fresh Forward+/Metal uniform captures replace the same three prior views. Appearance and historical approval remain open.

The general documentation gate currently fails on unrelated missing `docs/world/captures/` index targets. The police document link and scoped whitespace checks are valid; this failure is not a police gameplay failure.

### Tailoring follow-up — 2026-10-02

Removed the retained farmer head wrap from the Sikh export: it had covered the authored police turban folds. The tunic placket is now sampled against the source garment surface and carries transferred garment vertex weights; smaller plain buttons follow that same deformation. This corrects floating fittings without changing the MPFB body, animation rig, provisional palette or claimed period status.

The British Library identifies the relevant annual gazette as [Agra Gazette, 1854, IOR/V/11/1236](https://searcharchives.bl.uk/catalog/040-000125388), covering January–December and supplements. Its catalogue currently provides no digitised-content link. This is an archival lead for the 28 December notification, **not a verified reading of its dress specification**. Do not infer the notification's actual contents from the catalogue.

Tailoring regression: actual-world arrest phases and theft/abort checks PASS (17.01 m escort, 1.135 cm restraint palm error). Final face-direction/clearance correction changes only the garment strip; final Metal stills replace the earlier same-view captures. Normal-speed tailoring/contact review and historical authentication remain open.

### Cloth-edge and hair-envelope pass — 2026-10-05

The original cloth ring surfaces now have a four-row rounded-edge profile (48 samples around the circumference). Belt/collar/headwear edges gain real depth while retaining their existing rig bindings and materials. The Sikh beard hair envelope tapers at the lower edge and has small clump variation rather than a perfectly smooth oval. These edits change clothing/hair only; all bodies remain the original MPFB source. No additional bitmap textures or NPC population were added.

Historical status remains unchanged: the 1854 notification is identified but its actual dress specification has not been read. Geometry polish is not evidence for the candidate colours, garment cut or local Sikh posting. Latest same-view Metal screenshots replace prior screenshots; final art, normal-speed contact and 8 GB hardware acceptance remain open.

2026-10-05 verification: all three `THANA_STAFF_PASS` results returned; final Metal uniform capture completed and Sikh view inspected. Native full-world log also contains an unrelated seated-coachman dictionary access error (`vehicles/seated_coachman.gd:54`); do not call this a clean full-world run. The turban and beard remain too smooth at gameplay distance, and collar/tunic tailoring is still visibly provisional.

### Owner colour/contact reference — 2026-10-05

The owner supplied a full-length tan-uniform portrait and requested this colour direction plus attached-looking buttons, belt and pockets. Its date/unit/provenance are unidentified. It is an owner visual reference, not evidence that the entire pictured pattern belongs in 1857; puttees, crossbelt and later-style details are not authenticated by this change.

Applied warmer tan cotton and matching headwear/fittings, brown leather, a belt sampled against the upper/lower tunic surface, a thin fitted brass buckle frame, and four surface-fitted pocket bags/flaps. Pockets, buttons and belt transfer the tunic's deform weights. Pocket projection is measured in millimetres rather than rigid boxes attached to one torso bone. MPFB bodies and rigs are retained; no new bitmap textures. The former drab/indigo palette description above is superseded by this owner-selected candidate palette. Exact uniform history and normal-speed fit still require review.

The supplied reference is retained as `police_owner_colour_reference.png` for review only, not as a game texture or a verified licensed historical asset. After the first render revealed waist clipping, fittings switched from nearest-vertex weights to interpolated weights from the underlying garment triangles. This includes the lower tunic panel, so belt/pockets follow the correct panel rather than an unrelated upper-garment vertex. Belt clearance is 7 mm; the thin buckle is fitted 2 mm farther out. Colour/pocket contrast and contact must be judged in the fresh game views, not from these numbers alone.

Validation for the owner-reference pass: headless and Forward+/Metal actual-world arrest regressions PASS (17.01 m escort; 1.135 cm officer palm error). Native restraint still inspected, but its camera partly occludes the officer and is not sufficient for close tailoring acceptance. A final nine-row belt surface refinement follows that test; it changes geometry sampling only. Final same-view uniform captures replace the earlier clipping views. Normal-speed close fit remains open.

Final nine-row belt screenshot inspected: the previously broken/occluded waist band is continuous in the standing Sikh view. Pocket patches are attached but still need seams/cloth volume polish. This final capture completed despite newly concurrent `expanded_jobs.gd:226` type-inference and vehicle-reins errors; it is appearance evidence only, not a clean full-world run. Earlier native arrest PASS predates those errors.

### Explicit reference details and complete-body rule — 2026-10-05

Owner explicitly selected the supplied portrait's colours and uniform details. Added fitted front/back diagonal brown leather strap, plain shoulder tabs, pocket centre pleats, six brass front buttons, tan lower-leg puttee surfaces, and more thigh ease. This implements the owner-selected appearance; it does not authenticate the unidentified portrait's date/unit.

The source builder now uses the shared `whole_body_contract.retain_complete_body` before baking. The retained body is never trimmed; only separate trousers, puttees and opaque adult foundation clothing are cut from duplicate topology. All three editable assets contain 13,380 body vertices and 13,378 body faces, no remaining body masks, and the separate opaque foundation. Runtime GLB body/foundation presence is checked in `thana_body_retention.json`. Only MPFB helper geometry is excluded. Full topology is not garment-fit or contact approval.

The first complete-outfit whole-world Metal capture hit a rendering fence timeout at `capture_thana_uniforms.gd:25` and was stopped after over four minutes. Do not treat this as successful world validation. `tools/characters/review_thana_reference.gd` provides isolated Forward+/Metal front/side views of the same runtime actors and materials, with neutral lighting. Its first review caught overly broad calves; trouser ease is now limited to the thigh while the wrapped lower leg stays narrow. Latest `thana_reference_{role}_{front,side}.png` replace prior isolated views. Older station stills remain placement evidence for the preceding outfit; they do not show the complete-body/reference-detail update.

Final reference-detail refinements: widened the lower coat panel to enclose the looser trousers; reduced lower-leg clothing ease; fitted a small brown belt pouch/flap; softened crossing turban courses; added a filtered procedural puttee-band material without image maps. Isolated review checks each actual runtime actor's skeleton and AnimationTree. The full-body headless arrest regression PASS covers all custody/release phases and theft/abort cases (17.01 m escort, 1.135 cm palm error); later coat/pouch/puttee changes are geometry/material only. Final appearance and close motion must be reviewed separately.

Final side-view review caught the waist sampling hitting a sleeve at the outer ray origin. Belt rays now start 30 cm from the torso centre, inside the sleeve envelope, so the band samples the waist rather than sleeve cloth. Latest front/side review images replace prior isolated captures; the final belt correction changes fitting geometry only.

Side-view waist refinement: the source upper tunic and lower coat panel had different rear depths. The panel now tapers/centres into the waist at its top before widening toward the hem. Belt fitting samples this revised surface. Latest isolated front/side Metal views and rig checks are current; full-world Metal capture and normal-speed close garment contact remain open.
