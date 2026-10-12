# Extra-profile merge verification — 12 October 2026 IST

The consolidation preserved eleven `.codex-extra` worktrees on local
`codex/recovered-extra/*` branches. It did not merge all eleven candidates.
The four reviewed household pilots live in the dirty GitHub checkout at
`/Users/harshmishra/Documents/GitHub/TheLastMonsoon`, based on HEAD `8bac978a`.
Worktree290b has the same committed HEAD but does not contain those uncommitted
pilots. Their current runtime callsites were checked in `bhairavpur_village.gd`:
House1 cultivation, House25 carpentry, House27 weaving and House30 pottery.
The existing single carpenter/loom surfaces and the village's33 homes remain.
The earthenware damage component is linked through the actual water-pot script.

## Repair

Bullock road movement could occur before deferred `DraftTeam.prepare` populated
its slots. The override indexed slot0 even though the shared movement owner
already allowed the original draft animals to operate during that interval.
`vehicles/bullock_cart.gd` now checks slot existence before consulting attachment;
animal health remains authoritative while registration is pending. Existing
collision, attachment/death, movement and save rules are preserved. The fix and
`validate_draft_teams.gd` immediate-spawn regression were applied to main and290b.

## Current checks and limits

- Actual-main fresh import PASS213.0s; original all-code841 scripts/52 shaders
  PASS. After the repair and reusable fixtures, cached all-code843/52 PASS.
- Post-fix headless four household kits and five actual Player House27 routes
  PASS116.8s with no diagnostics. Routes: entry, exit, yarn preparation, loom
  approach and cloth storage. Other houses' complete walk/contact/art gates
  are not implied by this fixture.
- Enhanced draft-team immediate movement, detach/reattach, blocked hitch,
  death/replacement and numeric health-save checks PASS headless and native Metal.
- Shared boundaries19, services24, navigation7, actual-world save and rebellion
  continuation PASS in the fresh main snapshot. The earlier aggregate failed
  on the now-repaired bullock exception; those other checks had no diagnostics.
- Actual-main export PASS35.5s; packed-world smoke from an empty folder PASS89.0s,
  readiness47.469s and reload1.533 simulated seconds, with no diagnostics.
  This includes the merged pilot callsites and current bullock repair.
- Focused real Player/water-pot regression PASS: intact filling, damaged-source
  retirement, collision release, repeated damage, protected non-earthen source,
  stopped polling and twelve retained debris sets after fourteen fractures.
  Its first fixture lacked GameTimeSystem; the fixture was corrected and rerun
  cleanly. Gameplay did not need a water-source repair.
- Actual-main native household routes/kits completed, and no bullock script error
  remained, but ten Metal fence timeouts at coachman source-array readback made
  the native aggregate FAIL. No clean renderer/visual/FPS approval follows.
- Committed native city test FAIL:188/188 walkers,18/20 police,9/16 carts progressed;
  three Metal fence timeouts. Examples: a landowner-office wall, road colleagues,
  a patrol horse and pedestrians blocked carts. The native intro route completed
  but seven fence errors prevented a clean aggregate. These runs had concurrent
  headless/Blender work; timings do not establish isolated frame performance.

Traffic is still owned by its active city task (`run_city_population.py
--city-budget` observed running during this audit). Clothing and world performance
also have active owner work. Their files were preserved. Full-world acceptance
remains open; source/pack linkage success cannot supersede those failures.

## Preserved candidates

All eleven recovery refs exist. Their reviewed dispositions remain in
`/Users/harshmishra/Documents/Codex-Recovery/README.txt`. In particular2356's
weapon/chest/loot,4233's estate family,8bc1's separate Mangal flow andb311's
combat/uniform candidates remain preserved and unregistered. Older broad player,
save, terrain and builder replacements must not overwrite current contracts.
No recovery branches, profile history, editable bodies or assets were deleted.
No commit or push was made by this audit.

## Reproduce

From the GitHub checkout:

```sh
python3 tools/maintenance/check_merged_features.py
python3 tools/maintenance/check_merged_features.py --cached packed
python3 tools/maintenance/check_merged_features.py --cached --native draft_teams households
```

From another checkout, add
`--project /Users/harshmishra/Documents/GitHub/TheLastMonsoon` to target its current
files. Default checks use a fresh disposable import; `--cached` explicitly skips
fresh-import verification. Native checks create no captures. Temporary snapshots,
logs, packs and custom save data are deleted in finally cleanup. Reusable test
source remains. These are diagnostic routes, not production/art approval.

Next action: after current city/cloth owner changes are ready, rerun the actual-main
native traffic and household route checks. Resolve the reported cart obstructions
and Metal source-array stalls before declaring the complete world clean. Remaining
recovery features need individual current-contract integration, not a bulk merge.
