# Thana staff — 1857 Suryagarh

Status: **RIGGED_UNIFORM_AND_ARREST_CANDIDATE / HISTORICAL_AND_ART_REVIEW_OPEN** (2026-10-01).

The DistrictPolice ground floor has a daroga, mohurrir and burkundaz. They now have independently animated bodies and clothing; the daroga and burkundaz participate in the [station arrest sequence](../arjun/police_arrest_sequence.md). The clerk stays at the record-room post. Their role metadata does not create floating labels.

## Uniform and Sikh variety

The farmer dhoti has been removed from the motion exports. Original fittings add full trousers, leather shoes, a leather duty belt and plain buckle, a tunic placket/buttons and indigo collar/headwear. The existing upper garment and lower tunic panel are retained and fitted to the existing skinned body. Daroga and mohurrir have cloth caps. The burkundaz is a Sikh candidate with cloth turban folds and a full uncut beard, attached to the head bone. Different headwear and facial hair provide the first variation; all three still derive from the same adult MPFB body, so distinct face/body identities remain work.

These are provisional outfits for a fictional 1857 district, not an authenticated regulation pattern. The [National Army Museum's record for Rattray's Sikhs](https://collection.nam.ac.uk/detail.php?acc=2013-10-20-37-66) dates the decision to raise Bengal military police to 1856 and records recruitment in the Punjab, including former Sikh soldiers. This supports Sikh police representation in the period. It does not establish a detachment or its exact clothing at fictional Suryagarh.

The [British Library catalogue's Central Provinces police portrait](https://searcharchives.bl.uk/catalog/040-003063129) records a dark-blue uniform and safa, but its regional and dating limits prevent treating it as the exact 1857 local pattern. The [National Army Museum's 1890 Rattray's study](https://collection.nam.ac.uk/detail.php?acc=1964-12-77-1) explicitly dates the pictured scarlet/white facings to their adoption in 1885; those later details were not used for the 1857 candidate. Plain fittings carry no later regimental number, modern rank insignia or modern police badge. The drab/indigo colour pairing is a design inference needing a dated local dress reference.

The [BPRD police history](https://bprd.nic.in/uploads/pdf/201905071150110985311Report-1.pdf) supports a daroga and armed station men before the 1861 law. The existing three-role set remains a fictional staffing choice; military-police recruitment evidence must not be used to equate every local civilian thana with Rattray's battalion.

## Sources and performance scope

`tools/characters/build_thana_motion.py` uses `WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend`. The original static thana previews remain separate. Motion exports are `characters/npcs/thana/{daroga,mohurrir,burkundaz}_motion.glb`; editable per-role sources and manifests are under `WorkingAssets/NPCs/thana_motion/`.

MPFB core body/skin provenance remains CC0 as recorded in the [village pair notes](indian_peasant_pair.md). Uniform fittings, shoes, trousers, turban folds and beard are original project geometry. Museum/catalogue pictures are references only; none are copied as game textures. Existing skin/eye textures are reused, with small plain cloth/leather materials rather than new large texture maps. Only the existing three station staff are placed. This limits added scope but does not certify 8 GB hardware performance.

## Review evidence

`tools/characters/validate_thana_staff.gd` checks all three actual-world roles, station placement, skeletons, independent AnimationTrees and animated collision bodies. The arrest route separately checks officer restraint contact and collision clearance. Metal review captures are `thana_daroga_uniform.png`, `thana_mohurrir_uniform.png`, and `thana_burkundaz_uniform.png`; `tools/world/capture_thana_uniforms.gd` chooses a camera sight line that is clear of room walls.

The export review caught and corrected masked-out trouser sections, accidental MakeHuman helper geometry and turban-fold rotation around the world origin. Fine tailoring, sleeve/neck fit, beard shape, cloth motion, distinct likenesses and exact local historical pattern still require review. The tunic is an improved role candidate built on the existing source, not a finished bespoke period uniform.
