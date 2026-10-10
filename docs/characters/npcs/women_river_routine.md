# Women’s morning river routine

Updated 2026-10-10 IST, /root. Pace/companion route/shore correction integrated; final close motion/contact and whole-game approval remain open.

Three clearly adult women reuse the original MakeHuman/MPFB village-woman body and rig. They depart together, fill earthen pots, rub/rinse/wring laundry, sit and converse, pick up the filled pots, walk home, and deliver them. No human primitives or substitute physique are used.

## In-game access

Start a new Suryagarh game. From the Bhairavpur approach, walk west into the old village frontage. The group starts outside the easternmost house of that frontage, near world (-277, 7.2, 208.5), during the 06:00–09:00 departure window. Follow the eastern village approach and the existing bank footpath eastward. The collection point is on the existing shore at (63.96777, 0.03, 185), roughly 50 metres south of the boat landing. The rectangular washing/seating deck is removed. A continuous collidable earth access surface joins the surveyed bank, with shoulders returning to terrain. The women face the river when dipping their pots.

Travel now averages 1.15 m/s, with small individual speed changes, separate lanes along the approach and bank path, staggered departures, independent foot phases and eased turns. Foot phase follows actual distance travelled continuously across the routine sample loop. The 0.6m stance sweep is timed to match body travel, giving a 0.87-second full stride cycle at 1.15m/s instead of the previous fast, sliding foot cycle. Slope-dependent pelvis lowering probes higher and lower ground around the feet to maintain ankle reach over slopes and small crests. A small body rise and lateral weight shift follows the foot cycle; the carried pot responds with reduced motion. The water-filling stance uses wider feet and a reduced torso bend, with the dip closer to the body. Seated hands remain within the unchanged arm reach. The full journey is long. The accelerated game clock can advance beyond the morning during an observed trip. The morning window gates departure, rather than forcing a teleport to finish within that window. A group already travelling completes its trip; the next departure requires a later day.

For a quick motion review, open `characters/npcs/indian/river_routine_review.tscn` in Godot and press F6. Its shortened four-metre route shows the entire 72-second sequence. Watch shoulder/blouse fit, waist and seat, knee folds, ankles, pot palms and finger contact, laundry grip, seated entry/exit, and pickup before the return turn. This review scene does not replace main-world testing.

Save during travel or the visit, reload that slot, and check the same group position/action resumes. Check that delivery completes and no second departure occurs that same day. Older saves without river state leave the default routine intact.

## Implementation and editable inputs

- `characters/npcs/indian/river_woman_study.gd`: independent idle/walk AnimationTree, bounded stage evaluation, unstretched analytic limb solving, planted ankles, ground-normal foot orientation, pot/laundry action targets and interpolated clothing corrections. Morph updates touch only active/previous keys and resolve shape names separately for each garment. Idle and walk animation time is synchronized to the routine pose and travelled distance.
- `world/suryagarh/settlements/village_river_routine.gd`: terrain/physical-surface route, collision sweep, shore earth access, 06:00–09:00 daily departure, group visit and home delivery. The actor stays at the physical journey position through walk-loop boundaries; arrival tests use horizontal distance after ground sampling.
- `village_street_life.gd` adds the runtime group. `river_routine_save.gd` supplies the two save-manager hooks. Shared files retain concurrent changes.
- `WorkingAssets/NPCs/river_woman/river_woman_motion.blend` is the editable source. `poses.json` is a required sampled runtime-pose rebuild input, not a test report. `manifest.json` records source/export identity.
- Runtime: `characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb`. Complete native body retained (14517 exported body vertices), only non-human helpers excluded. Separate opaque fitted bra/thong foundation exported and retained in source; foundation uses 880 selected donor faces, triangulated to 1760 faces in the fitted export. Clothing-driven body masks are disabled.
- `build_river_woman_candidate.py` transfers native body weights and creates 674 upper-garment correction samples with dense action contact phases and walking phases across five slopes. `river_surface_binding.py` attaches upper garments and foundations to stable triangles of the original body; the lower sari uses a continuous ring direction around both legs with the hem raised above the bank. `river_cloth_correctives.py` reproduces explicit parent pose matrices and repairs remaining contacts against the unchanged complete body volume. Runtime checks use exact solid-angle confirmation and include blends between sampled bank slopes. It is a fitted corrective system, not a cloth simulation. The fitter evaluates the donor’s active MakeHuman physique before transferring clothing weights or constructing foundation garments. Upper-garment masks and runtime triangle diagonals are applied before fitting; the complete human body stays unchanged.

## Rebuild and checks

Run from the repository root:

```sh
python3 tools/characters/rebuild_river_woman.py
python3 tools/characters/check_women_river.py
python3 tools/characters/check_river_cloth.py
```

`check_women_river.py --render` additionally checks focused native Metal rendering. Its temporary images are discarded in a finally cleanup. Capture tools require an OS temporary `TLM_RIVER_TEST_OUTPUT` whose caller cleans in finally. Reusable test code remains; generated screenshots, videos, reports and logs are disposable under the 2026-10-07 policy.

The focused route test uses the actual baked landscape and the same Bhairavpur house/door builder, without unrelated city populations. It tests all stages, collision clearance, actual water access, helper save round trips, older-save compatibility and next-morning restart. The flat check runs a 75-second 30Hz three-rig sweep. Solved wrist/ankle errors are bone-target measurements; they do not certify palms, soles, cloth surfaces or final appearance.

Latest completed route checks on 2026-10-10: flat routine and actual baked-landscape round trip PASS, including lane separation, ordinary speed, boat-route clearance, all stages, save helpers and daily scheduling; zero blocked movements. Maximum solved ankle error 0.061mm and wrist error 13.340mm. These are bone-target checks, not palm/finger or garment approval.

The 2026-10-10 focused Forward+/Metal shore review completed all five action captures and 185 physics frames over 3.012 seconds of ordinary-speed walking, with zero blocked movements. The three women now have separate cotton palettes, skin tints and whole-character heights. This candidate failed visual review: the upper garment still had gaps and the seated lower sari remained box-like. A native audit sampled 2,500,560 garment vertex/face points across 207 intermediate poses; five pallu face centers penetrated the unchanged body, up to 7.505 mm. The other four garment surfaces and seated rear-hip contact passed that audit. These results do not approve the candidate.

The next rebuild removes the blouse's spine-only skin selection, which excluded breast/shoulder groups, trims continuous garment boundaries and smooths the seated lap profile. It is rebuilding and requires fresh contact and pixel review. Complete MakeHuman anatomy and opaque adult foundations remain retained. Temporary review media and logs were removed.

Next: finish the corrected rebuild, repair any remaining native pallu contact failures, and inspect fresh walking/filling/washing/seated/pickup renders. Final art, owner and whole-game performance approval remain separate.
