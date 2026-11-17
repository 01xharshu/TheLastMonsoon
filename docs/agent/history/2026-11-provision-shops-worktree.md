# Provision shops: retired worktree notes

Preserved from the source worktree before its removal. Historical test claims describe their original scope; current integration evidence is in the worktree integration ledger.

## Village and city provision shops — chat 01a1b051-db4b-7400-8f40-68228e0eccd8
Updated: 2026-11-06 20:30 IST. **COMPLETE** for playable shops in worktree b4b6.
- Bhairavpur market lane and western Suryagarh city market each have a walk-in plaster/tile shop, roofed side veranda with two shelter points, hinged hand-contact gate and reused adult MPFB keeper. Arjun walks through after the inward swing. The keeper presents a fixed overhead ledger that purchases roti, mangoes, bandages and water bags through saved inventory.
- Files: `world/suryagarh/settlements/provision_shops.gd`, `provision_counter.gd`, `ui/provision_ledger.gd`, world registration, scoped player door/menu integration and shared map/minimap. Added shop/workshop SVGs, `tools/world/validate_provision_shops.gd` and [controls and commands](docs/world/provision_shops.md).
- Verification: clean Godot import and populated-world headless/native Metal PASS. Both collision-supported road approaches, roof cover, hand-driven entry, village exit, keeper contact, keyboard buying and rejection, Escape, both map pins and fresh Continue passed. Metal release gaps 0.2/22.3 mm and keeper gaps 10.5/11.7 mm. Continue retained 88 rupees, two bought bandages and the open city gate. Legacy courtyard gate assertions passed, and a temporary longer startup settle also cleared its lifecycle diagnostics.
- Native veranda, counter, ledger and map captures reviewed. Temporary captures, logs and test saves removed. Existing Arjun trousers show a small thigh clipping spot in the counter capture. Rain behavior is future scope. Next action for owner review: open the field map, select either provision shop and use E at the gate and counter. See the focused doc for the isolated regression command.

## Provision shop ledger pages and interior dressing
Updated: 2026-11-11 21:48 IST. **COMPLETE** for the requested playable baseline.
- Added animated forward and reverse ledger sheet turns, two illustrated spreads and four additional inventory-backed products. Added six-drawer cabinets, collidable tied sacks and stacked crates in both shops. Updated `docs/world/provision_shops.md` and `tools/world/validate_provision_shops.gd`.
- Final headless populated-world regression exited 0 after the taller cabinet change, covering both approaches, page turns, purchases, cancellation and Continue. Earlier native Metal run passed before that final cabinet-height adjustment. The final cabinet was visually inspected in Metal, along with the moving sheet and stock icons; the final native process outcome was unavailable after interruption. Existing Arjun trouser clipping remains. Drawers are decorative.
- Temporary test output removed. Next action: play either shop in-game, turn pages with left/right, and inspect the counter and storage dressing.

- 2026-11-11 21:52 IST resumed at user request. Running the final native Metal populated-world regression with temporary saves and captures.
- 2026-11-11 21:53 IST final native Metal populated-world regression PASS with the taller cabinet, both approaches, page turns, purchases, Escape and Continue. No warnings or errors in filtered output. Temporary saves and captures deleted. Existing trouser clipping remains for character review.

## Provision shop realism refinement
Updated: 2026-11-11 22:11 IST. **COMPLETE** for this focused refinement in worktree b4b6.
- Updated `world/suryagarh/settlements/provision_shops.gd` with earthen-toned floors and wall footings, timber gate framing, counter boards and apron, varied parcels and a supported basket parcel. Existing shop locations, interaction/save ownership and earlier dirty work preserved.
- Native Metal populated-world run passed both shops, page purchases and Continue before a final minor finish and parcel-height correction. A native counter capture was reviewed and the high-contrast footing finish was softened afterward. Final corrected geometry passed `tools/world/validate_provision_shops.gd` headless with no warnings or errors. Both test runs used disposable OS temporary output, which was removed.
- The room remains simply dressed. Final in-game visual, construction and historical review are open, as is the previously observed Arjun trouser clipping. Next action for owner review: visit either marked shop, enter through its veranda and inspect the counter and shelf arrangement at normal gameplay scale.

## Provision shop realism continuation
Updated: 2026-11-11 22:18 IST. **COMPLETE** for this focused continuation in worktree b4b6.
- Added supported end-wall shelves with varied brass, clay and parcel stock and closed the previously observed roof-peak gaps with two-sided triangular gables in `world/suryagarh/settlements/provision_shops.gd`.
- Per user correction both shop gates are always open and have no interaction prompt. `world/suryagarh/settlements/public_shop_gate.gd` forces old closed/locked save states open while retaining existing gate paths. Removed the now-unused automatic latch traversal from the shared controller. `docs/world/provision_shops.md` and the populated-world fixture reflect public entry.
- Headless and native Metal populated-world checks PASS both approaches, direct walking through the door, actual SaveManager restoration of an old closed/locked state, page turns, buying, Escape and Continue. Native storefront and shelf pixels inspected. Temporary test output deleted. The repaired roof peak has structural coverage, with full exterior and manual motion/art review still open. Existing Arjun trouser clipping remains.
- Next action for owner review: walk through either open shop from its market veranda and approach the counter. Inspect the stocked wall and roof from normal gameplay positions.

## Provision shop roof and exterior review
Updated: 2026-11-12 10:10 IST. **COMPLETE** for the focused gable repair in worktree b4b6.
- Native exterior and interior roof inspection found the previous triangular gable still showed a strip of sky. Replaced it in `world/suryagarh/settlements/provision_shops.gd` with overlapping masonry courses matching the pitched roof. Both village and city storefronts and interior roof joins were visually inspected in native Metal after the fix, and the previously visible gap was closed in the reviewed views.
- `tools/world/validate_provision_shops.gd` headless populated-world regression PASS on final geometry, including both open public approaches, legacy closed-gate migration, book purchasing and Continue. Native roof-review script completed without errors. Disposable screenshots and logs removed. No full manual art or historical approval claimed; existing Arjun trouser clipping remains.
- Next action: owner review at normal gameplay scale, including the outer building finish and character clothing. Earlier uncommitted work remains preserved.
