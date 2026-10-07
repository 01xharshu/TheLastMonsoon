# Civil Lines and cantonment service bazaar

Updated 2026-10-05 IST. Task /root. Status IN_PROGRESS: construction and collider access verified; final realism/art remains open.

Scope: the four requested functions are integrated into the normal Suryagarh world: separated Civil Lines, Collector/officer bungalows, existing Government House retained as regional residence, and a cantonment service bazaar. Follow-up scope includes floating-tree repair, more trees, and interior/exterior realism. Existing British household, Government House and other tasks' assets are preserved. No new humans were created.

Civil Lines is centred at (680,245), grade 10, with a 190 × 130 m surveyed terrace. Collector bungalow at (640,235) is now 24 × 16 m; officer bungalow at (720,235) is 20 × 14 m. Their spacious garden compounds and separate service quarters remain. The avenue joins the administrative district. Bazaar at (640,470), grade 8.5, has six service stalls, trade props, canvas awnings and a cart/tether standing area. Its eastern spur goes around the stall row.

Runtime construction: `world/suryagarh/settlements/civil_lines.gd`, integrated by `settlement_builder.gd`; plots/roads/map markers in `landscape_layout.gd`. October 5 changes tighten house proportions and add office/reception/bedroom bearing walls, framed room openings, reception seating, bookcases and bed headboards. Timber ceilings, floors, joinery, sleeping and writing furniture remain. Local shutter casing/leaf offsets correct leaves embedded in the side masonry by the shared window helper. Other homes' helper and door scripts were preserved.

Earlier terrain integration: `tools/world/bake_civil_lines_region.gd` updates nine tiles (tx 9–11, tz 7–9), resident landscape, road mask and terrain material. Initial bake cleared 8,208 obstructing vegetation instances. Tree repair through `tools/world/ground_and_plant_trees.gd` checked 1,823 existing trees, corrected 634 transforms (worst initial floating gap 1.358 m), and added 227 trees: 27 district shade trees and 200 grove trees. Trunk colliders were adjusted/added. Saved asset: `world/suryagarh/generated/landscape.scn`. Initial baker parse errors were repaired before successful runs; bake exit reported one ObjectDB leak warning.

Latest native Forward+/Metal regression PASS, 2026-10-05: **16 player collider walks**, including both office/reception/bedroom circuits; **208 resident terrain samples**; **2,048 saved-world tree roots**; zero failures. Maximum measured tree foot gap is -0.11997 m (approximately 12 cm embedded). The live count is two below the initial 2,050 total; the cause of that count difference was not separately audited. These mechanical walks use repeated controller steps per physics frame and do not certify normal-speed animation or manual gameplay.

Run from repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/validate_civil_lines.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/validate_civil_lines.gd -- --capture-only
```

Reports: current route/terrain/tree checks (test output deleted), initial tree repair (test output deleted). Logs: `/tmp/civil_lines_2026_10_05_final.log`, `/tmp/civil_lines_2026_10_05_close_views.log`.

Latest screenshots replace earlier versions of the same view. Inspected fresh native images confirm enclosed ceilings, room framing, complete shutter faces/casing, furnishings, grounded district trees and open approaches. Evidence: district (test output deleted), bungalow exterior (test output deleted), veranda (test output deleted), office (test output deleted), bedroom (test output deleted), Collector room connection (test output deleted), officer room connection (test output deleted), bazaar (test output deleted), bazaar at player height (test output deleted).

`git diff --check` PASS. Latest `python3 tools/check_agent_docs.py` FAIL: shared handoff exceeds 60 lines/6000 characters; all current index links resolve. Other active task entries were preserved. Diagnostic log `/tmp/civil_lines_docs_gate_2026_10_05.log`. Missing unrelated screenshots reported at first resume were restored by concurrent work, so that earlier index failure no longer remains.

Remaining: the ridge cut still looks too steep; grounds, roof/plaster detail and furnishing shapes still need an art pass. Staffing, trade transactions, resident routines, historical and owner art approval, normal-speed player review and performance are open.

Exact next action: refine the Civil Lines ridge/terrace transition and planting detail while preserving avenue/drive grades; if terrain changes, run regional bake first, then tree grounding/planting after the final terrain save, and rerun `validate_civil_lines.gd`. Inspect regenerated exterior and interior evidence before granting any additional gate. Human staffing must reuse MakeHuman/MPFB characters.
