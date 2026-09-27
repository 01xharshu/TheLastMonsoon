# Company weapon store — 2026-09-27

## Placement repair

The prior five-weapon render showed an upright bow penetrating the upper shelf, a floating pistol, and crowded long guns. The two-shelf rack now measures 4.8 × 1.0 m. Posts reach both shelves, and the rear panel closes the storage bay. Rifles occupy the lower shelf; bow, talwar, and pistol occupy the upper shelf.

Each model is laid on its side, measured in store coordinates, centered into its assigned slot, and placed 15 mm above the support surface. The allowance prevents surface flicker; it is not a claim of exact wood/weapon contact. No mesh is scaled to force a fit. Pickup collision widths use the measured weapon width and a minimum 0.4 m target; a standing player can reach both levels.

Evidence: [fresh Metal capture](captures/23_company_weapon_rack.png), inspected. `tools/world/validate_weapon_store.gd` passes on Metal and headless: unarmed start, shelf containment/support bounds, no weapon-bound overlaps, standing room-side line of sight from the gameplay ray height, acquisition of all five weapons, and partial/full loot restoration in a fresh scene. The partial save retains the four uncollected Company weapons; unrelated civic pickups remain available. It uses an isolated save directory and removes both test saves.

## Persistence

Company pickups now use stable IDs such as `company_armoury/enfield`. Room furniture changes no longer invalidate saved engine-generated node paths. Existing saves with the old path-based field fall back to inventory ownership: already owned weapons stay collected, unowned weapons remain available. This fallback cannot reconstruct an old removed pickup that was later discarded, because old saves did not record a stable identity for it.

## Historical limits

[Historical accuracy notes](historical_accuracy.md) record the period/India evidence and distinguish local availability from Company issue. The rack itself, exact weapons, private/held-arms context, and room dressing still require period art review. The rejected Arjun model remains unsuitable for final hand-contact approval. River ghats and stair rails have separate unresolved form/site questions; this placement repair does not approve them.
