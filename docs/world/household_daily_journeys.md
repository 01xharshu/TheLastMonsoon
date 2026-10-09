# Wealthy household journeys

Updated 2026-10-08. Functional routines and continuous garment adapter integrated; final historical tailoring and full-world motion approval remain open. Test output is temporary and deleted after review.

## Implemented

Four residents (landowner, merchant, British official and woman) have independent journey controllers and AnimationTrees. Nine household staff reuse two existing MPFB bases with separate opaque foundations. Editable foundation sources and skinned exports are retained; no human bodies were constructed or cut for this work.

Residents leave home, approach an opening carriage door, climb the running board, enter, turn and sit. Coaches wait for every passenger. At the office they stand, disembark, enter, sit and work at separate desks, then reverse the sequence home. Demonstration waits are 12 seconds at home and 18 at work, not an approved daily-hours schedule.

| Household | Home centre | Office centre |
| --- | --- | --- |
| Landowner | −321, 7.2, 344 | −309, 7.2, 315 |
| Merchant | −413, 7.2, 282 | −367, 7.2, 312 |
| British family | −455, 8.5, −184 | −463, 8.52, −124 |

The landowner coach requests the existing estate gate to open within 18 m, waits for its swept animation, and keeps it open while passing. An explicit player lock remains authoritative. Physical collision stays active. The British coach retains its reverse-out turning manoeuvre; reserved household seats remain separate from public carts.

## Clothing and body retention

The old vehicle-only gown swap is replaced with `characters/npcs/households/household_drape.gd`. Its continuous outer garment follows pelvis, thighs, knees and feet during walking, climbing, sitting and standing. Merchant/landowner dhotis retain their border material. The woman's fitted waistband stays visible; additional upper-thigh clearance covers the raised-leg breach seen during review. Original outer meshes remain in the assets; the runtime adapter hides only the replaced outer skirt/dhoti. Complete bodies and opaque foundations remain intact.

Sources: `WorkingAssets/NPCs/households/{merchant,landowner,staff_farmer,staff_woman}/`; British pair: `WorkingAssets/NPCs/british/official_pair/official_pair_mpfb_candidate.blend`. Rebuild foundations with `tools/characters/add_household_foundations.py -- <role>` through Blender; export the British pair using `tools/characters/export_british_roster.py -- official`. Staff copies preserve their village donor assets.

A render winding defect was fixed. The adapter uses 32 segments × 9 rings, analytic normals, and reuses the pose until leg positions change by more than 0.5 mm. It does not simulate cloth or establish historically correct folds. Broad drape shape, hand/hem and seat-surface contact still need close continuous review.

## Checks on 8 October

- Six runtime families: skinned body and separate opaque foundation structure PASS. Export vertex counts include seam splits; counts alone do not certify source topology or appearance.
- Full-world activities PASS after estate-gate integration: four residents visited every required state; three coaches completed returns; no blocked walking/coach routes; 13 independent trees; 362 office garment samples with zero pelvis-anchor error. Sampled staff palm error stayed below 2 mm. Rig-point checks do not establish fingertip or mesh contact.
- Native isolated fixture completed 720 pose updates. Close raised-leg and seated views were inspected transiently. The visible raised-leg waist/thigh breach was corrected; the latest full-world continuous sequence remains a separate review.
- Measured native median rebuild costs were approximately 0.13–0.17 ms per garment; upper-tail costs varied under concurrent work. An unchanged-pose probe averaged 1.72 μs/call and rebuilt once. These are helper costs, not whole-world FPS.
- The latest Metal close-pose run timed out; cleanup completed. Compatibility-renderer seated review succeeded. The fixture floor/seat dimensions now match the office rather than a ground-level stool.
- Two exit-object warnings occurred in the isolated cost/full-world runs; their ownership remains unresolved. No test screenshots, recordings, logs or reports are retained as approval evidence.

## Distance budget and ownership

Near controller updates follow physics cadence; beyond 180 m they run at 10 Hz. A coach or resident within 150 m wakes near updates. Pending time and journey state are preserved; stall catch-up is bounded. Residents' manual tree/contact sampling follows that cadence. Horse players, staff work trees, reins and rendering are not yet all managed by this household budget.

This task owns household residents, staff and journey clothing/contact. Thana police and military uniform families remain with their respective asset owners; full-body/foundation, adult physique variation and cited historical patterns apply there too. No period-final uniform claim follows from these household checks.

## Test in game

1. Open `world/suryagarh/suryagarh_world.tscn` in Godot. Temporarily place the Player near (−326, 7.3, 341), clear of the landowner coach, and run the scene.
2. Watch the complete departure and return: gate opens before the team reaches it; feet use the running board; every passenger sits before movement; home entrance remains accessible.
3. Repeat near the merchant and British home centres above. At each office, inspect the front and side of the seated garments, shoes, chair cushion and ledger hands.
4. Move the camera/player outside 180 m and back within 150 m. Confirm the household resumes without restarting or duplicating occupants. Lock the estate gate manually and confirm the coach waits.
5. Restore the Player's original editor transform without saving a test placement.

Reusable checks: `python3 tools/characters/audit_household_foundations.py`; Godot `--headless --path . --script tools/world/validate_wealthy_households.gd`; `python3 tools/world/run_household_review.py` for a temporary native fixture with exit cleanup. `--poses-only` reviews three key poses. Check scripts print results; they do not retain generated reports.
