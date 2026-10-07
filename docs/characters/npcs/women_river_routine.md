# Women’s morning river routine

Updated 2026-10-07 20:49 IST, /root. IN_PROGRESS: integrated playable baseline; final close motion/contact and whole-game approval remain open.

Three clearly adult women reuse the original MakeHuman/MPFB village-woman body and rig. They depart together, fill earthen pots, rub/rinse/wring laundry, sit and converse, pick up the filled pots, walk home, and deliver them. No human primitives or substitute physique are used.

## In-game access

Start a new Suryagarh game. From the Bhairavpur approach, walk west into the old village frontage. The group starts outside the easternmost house of that frontage, near world (-277, 7.2, 208.5), during the 06:00–09:00 departure window. Follow the eastern village approach and the existing bank footpath eastward. The washing landing is at (80.11087, 0.03, 166), roughly 69 metres south of the boat landing. It has physical collision and a terrain-clearing access ramp.

Travel uses the real 0.4 m/s gait; the full journey is long. The accelerated game clock can advance beyond the morning during an observed trip. The morning window gates departure, rather than forcing a teleport to finish within that window. A group already travelling completes its trip; the next departure requires a later day.

For a quick motion review, open `characters/npcs/indian/river_routine_review.tscn` in Godot and press F6. Its shortened four-metre route shows the entire 72-second sequence. Watch shoulder/blouse fit, waist and seat, knee folds, ankles, pot palms and finger contact, laundry grip, seated entry/exit, and pickup before the return turn. This review scene does not replace main-world testing.

Save during travel or the visit, reload that slot, and check the same group position/action resumes. Check that delivery completes and no second departure occurs that same day. Older saves without river state leave the default routine intact.

## Implementation and editable inputs

- `characters/npcs/indian/river_woman_study.gd`: independent idle/walk AnimationTree, bounded stage evaluation, unstretched analytic limb solving, planted ankles, ground-normal foot orientation, pot/laundry action targets and interpolated clothing corrections. Morph updates touch only active/previous keys.
- `world/suryagarh/settlements/village_river_routine.gd`: terrain/physical-surface route, collision sweep, river ramp/landing, 06:00–09:00 daily departure, group visit and home delivery. The actor stays at the physical journey position through walk-loop boundaries; arrival tests use horizontal distance after ground sampling.
- `village_street_life.gd` adds the runtime group. `river_routine_save.gd` supplies the two save-manager hooks. Shared files retain concurrent changes.
- `WorkingAssets/NPCs/river_woman/river_woman_motion.blend` is the editable source. `poses.json` is a required sampled runtime-pose rebuild input, not a test report. `manifest.json` records source/export identity.
- Runtime: `characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb`. Complete native body retained (14517 exported body vertices), only non-human helpers excluded. Separate opaque fitted bra/thong foundation exported and retained in source; current foundation has 606 source faces. Clothing-driven body masks are disabled.
- `build_river_woman_candidate.py` transfers native body weights and creates 97 outer-garment correction samples. `river_cloth_correctives.py` fits to the unchanged full posed body, keeps lower fabric outside a continuous bent-leg envelope, and clears the foot/floor plane. It is a fitted corrective system, not a cloth simulation.

## Rebuild and checks

Run from the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/characters/export_river_poses.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/characters/build_river_woman_candidate.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 tools/characters/check_women_river.py
```

`check_women_river.py --render` additionally checks focused native Metal rendering. Its temporary images are discarded in a finally cleanup. Capture tools require an OS temporary `TLM_RIVER_TEST_OUTPUT` whose caller cleans in finally. Reusable test code remains; generated screenshots, videos, reports and logs are disposable under the 2026-10-07 policy.

The focused route test uses the actual baked landscape and the same Bhairavpur house/door builder, without unrelated city populations. It tests all stages, collision clearance, actual water access, helper save round trips, older-save compatibility and next-morning restart. The flat check runs a 75-second 30Hz three-rig sweep. Solved wrist/ankle errors are bone-target measurements; they do not certify palms, soles, cloth surfaces or final appearance.

Latest milestones: full physical round trip, save helpers and daily scheduling passed with zero blocked movements. A stricter live reach check then found 45mm ankle error at the ramp transition and 19mm filling-wrist error. Walking/filling pelvis positions were adjusted and all cloth samples rebuilt to match; final rerun is pending. Main-world native capture failed to finish initialization within 171 seconds and was stopped. This is an unresolved whole-world startup/render limitation; focused rendering cannot certify the whole game. Earlier captures and reports were removed and do not provide current evidence.

Next: finish the adjusted live/flat checks and focused Metal moving-fit review; retain any unresolved garment/hand/sole defects in text. Final art, owner and whole-world performance approval remain separate.
