# Military interior, exterior and contact refinement

Updated **2026-10-05 01:05 IST**; root chat. **IN_PROGRESS / FINAL ART OPEN**. Scope: British cantonment rooms and occupied Government House fort; preserve service-building work and concurrent character/vehicle edits. Earlier detail: [history](../agent/history/2026-10-05-military-site-contact-detail.md).

## Integrated changes

- Forty cantonment cots now have rounded linen mattresses/pillows and folded wool geometry using `military_room_finish.gd` and `military_linen.gdshader`. Barracks and officer rooms use rough slab floors; roof ties run across the span with principal rafters/king posts. Peg rails and small room props retain the central aisle.
- Fort armoury has six supported side shelves, supply parcels/baskets, a stool and lamp. The record folio was corrected from below the ammunition counter to its top. Rifle stock chocks and keeper blocks supplement the existing six separate upright Enfields.
- Both cannon emplacements have stacked round shot, a water bucket and sponge staff outside the bypass routes. Existing MPFB guards and all character/body sources remain unchanged.
- Source files changed: `world/suryagarh/settlements/cantonment.gd`, `military_detail.gd`, `occupied_fort.gd`; new `military_room_finish.gd`, `military_linen.gdshader`. Validator updated: `tools/world/validate_military_contact.gd`.

## Fresh verification

`/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/world/validate_military_contact.gd > /tmp/tlm_military_finish_final_2026-10-05.log 2>&1`: **36 checks PASS**, native Forward+/Metal, no SCRIPT ERROR/ERROR lines. Includes gate/guard aisle, cannon bypass and armoury step entry/exit using Arjun’s collider; 40 linen-bed constructions; six shelves; both cannons; six rifle support heights/orientation and pairwise separation. Report (test output deleted).

`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/world/validate_cantonment.gd > /tmp/tlm_cantonment_finish_regression_2026-10-05.log 2>&1`: **twelve room entrance walks, cemetery gate, 35 terrain samples and magazine vents PASS**. Report (test output deleted). Exit-only warning: two ObjectDB instances leaked and one resource remained in use. Shutdown cleanup remains unverified; route success does not certify full-world health.

Fresh native same-view captures replaced in place and inspected: barracks (test output deleted), officers (test output deleted), cot linen (test output deleted), armoury (test output deleted), cannon (test output deleted), guards (test output deleted), cantonment exterior (test output deleted). Geometry/support improvements are visible; no final realism approval inferred.

First attempt failed bedding type inference; corrected explicit floats. A subsequent shelf check falsely failed due to Godot-generated duplicate names; corrected to count retained part labels. Only the final run above is current acceptance evidence.

`git diff --check`: PASS. Shared documentation gate: FAIL (handoff size and unrelated missing screenshot links in `docs/README.md`). Other task entries/index edits preserved.

## Exact next action

Improve cloth folds/seams and cot joinery from the inspected linen view, then wall relief and the estate’s primitive garden vegetation; retain approaches and rerun the two validators above. Normal-speed motion/contact, night lighting, guard response, cannon operation, historical/owner art approval and whole-game performance remain open. Service-building scope/evidence remains in [cantonment service realism](cantonment_service_realism.md).
