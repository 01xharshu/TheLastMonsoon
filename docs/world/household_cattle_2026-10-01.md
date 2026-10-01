# North-lane household cattle
Updated: 2026-10-01. Status: FUNCTIONAL PROTOTYPE / ART AND ANIMAL MOTION OPEN.

## Ownership and usable care
`household_cattle.gd` is created by the village street-life module. The cow belongs to actual `BhairavpurHouse27` (north-lane home centred at -321,299). Its shelter stands behind that home at -321,289, clear of the doorway and street. Both home and cow retain an explicit ownership link. This is a fictional household assignment, not a historical named owner.

The shelter has four grounded posts, cross beams, a simple pitched roof, open rear access, low side rails, manger, water trough and household fodder basket. The cow has a physical body collider, looping idle head/ear/tail movement and household metadata. Roof/thatch, joinery, trough shape and cow appearance remain visibly simple candidates.

Two contextual care actions use the existing interaction system and low-reach pose. Hold the interaction control at the manger to transfer a portion from household stock; hold at the trough to pour up to two litres from Arjun's real water pouch. Empty pouch, full manger/trough and distant actions consume nothing. Filling the manger is a supply action; mouth-to-fodder contact and actual feeding/grazing behavior are not implemented.

Feed portions, household fodder stock and trough water are included in save data. Older saves retain the initial supplies. The cow has no autonomous daily nutrition/drinking simulation yet, so supplies do not silently regenerate or disappear.

## Source and native appearance
Original Blender source and builder remain in `WorkingAssets/Animals/household_cow/` and `tools/animals/build_household_cow.py`. Authored body cross-sections distinguish ribcage/pelvis, straighter back, narrower female neck, longer face, reduced hump and folded dewlap. Current export: 27,024 vertices, 13 bones, idle/head_lower clips; manifest records SHA and provenance. No third-party geometry or imagery included.

Native review revealed that Godot retained COLOR_0 but left vertex-color albedo disabled, and the Blender vertex-node material exported a white base. `animals/cow_visual.gd` enables the original coat colors on body surfaces and supplies the intended grey on appendages without colors. Both review tool and live cow use that same treatment. First pale world capture rejected; corrected fresh yard pixels inspected. Geometry remains a candidate; detailed shoulder/hock/hoof/face/coat sculpt and natural balance are open.

[FAO morphology reference](https://www.fao.org/4/t1265e/t1270e03.htm) informs broad zebu anatomy only; it does not authenticate this animal as an exact 1857 regional breed.

## Verification
`tools/world/validate_household_cattle.gd`:
- Forward+/Metal `/tmp/tlm_cattle_yard_final.log`: ownership, actual terrain support (<0.001 mm numerical offset), body clearance against existing structures (zero overlaps), household stock transfer, full-manger rejection, empty-pouch rejection, pouch-to-trough conservation and distant-use rejection PASS.
- Headless `/tmp/tlm_cattle_save_disk.log`: actual isolated save-file write/read and care-state restoration PASS; missing-state older-save fallback PASS. Player save files untouched. Fixture shutdown reports a retained ObjectDB/resource warning; assertions pass. No owner play or production result inferred.
- `household_cattle_validation.json`; fresh `captures/household_cattle_yard.png` inspected in the world. First fixture expected an automatic collider node name and failed; explicit BodyShape name corrected, final native fixture exits cleanly.

Next: sculpt the animal's joints/face/coat, add a visibly distinct household caretaker with carrying/feeding contact, then cow walking, grazing/drinking, calf and a daily care schedule. Verify the complete player approach and actual hand/pouch/manger contacts at normal speed. Full-world performance on 8 GB hardware and owner art acceptance remain open.
