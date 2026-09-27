# Company weapon store — 2026-09-27

## Placement repair

The prior five-weapon render showed an upright bow penetrating the upper shelf, a floating pistol, and crowded long guns. The two-shelf rack now measures 4.8 × 1.0 m. Posts reach both shelves, and the rear panel closes the storage bay. Rifles occupy the lower shelf; bow, talwar, and pistol occupy the upper shelf.

Each model is laid on its side, measured in store coordinates, centered into its assigned slot, and placed 15 mm above the support surface. The allowance prevents surface flicker; it is not a claim of exact wood/weapon contact. Display scales follow the equipped weapon scales; shelf placement is measured after scaling. Pickup collision widths use the measured weapon width and a minimum 0.4 m target; a standing player can reach both levels.

Evidence: [fresh Metal capture](captures/23_company_weapon_rack.png), inspected. `tools/world/validate_weapon_store.gd` passes on Metal and headless: unarmed start, shelf containment/support bounds, no weapon-bound overlaps, standing room-side line of sight from the gameplay ray height, acquisition of all five weapons, and partial/full loot restoration in a fresh scene. The partial save retains the four uncollected Company weapons; unrelated civic pickups remain available. It uses an isolated save directory and removes both test saves.

## Persistence

Company pickups now use stable IDs such as `company_armoury/enfield`. Room furniture changes no longer invalidate saved engine-generated node paths. Existing saves with the old path-based field fall back to inventory ownership: already owned weapons stay collected, unowned weapons remain available. This fallback cannot reconstruct an old removed pickup that was later discarded, because old saves did not record a stable identity for it.

## Historical limits

[Historical accuracy notes](historical_accuracy.md) record the period/India evidence and distinguish local availability from Company issue. The rack itself, exact weapons, private/held-arms context, and room dressing still require period art review. The rejected Arjun model remains unsuitable for final hand-contact approval. River ghats and stair rails have separate unresolved form/site questions; this placement repair does not approve them.

## Civic shelves — 2026-09-27

Town Hall and District Police now store their three weapons flat on a 2.4 × 5 m timber shelf, supported by four posts. Model bounds determine placement, with the same 15 mm support allowance used in Company stores. Original civic persistence identities are retained so existing saves still recognize collected weapons.

`tools/world/validate_civic_weapon_shelves.gd` passes headless and Metal: all six weapon bounds fit the shelves, are separated, meet the support height and can be targeted from the room side. Render evidence: [Town Hall](captures/civic_weapon_TownHall.png), [Police](captures/civic_weapon_DistrictPolice.png). This verifies placement and pickup access; exact shelf construction and the appropriateness of each weapon in each civic store remain historically provisional.

## Player-driven civic access

`tools/world/validate_civic_weapon_walk.gd` drives the actual player through each civic armoury doorway, turns into the shelf aisle and walks to all three weapon positions: ten segments across Town Hall and District Police. No jumps are injected. It collects the first rifle and talwar, checks duplicate shelf weapons remain available, then saves to an isolated test slot and restores a fresh world. Expected restoration is one spare Town Hall rifle and all three Police weapons, with Arjun retaining his rifle and talwar. Evidence: [route results](civic_weapon_walk_validation.json). This checks the ground-floor room approach; exterior entry, hand-contact motion and historical approval remain separate.

## Display/equipment size consistency — 2026-09-27

Stored Enfields, double guns and pistols use the same scale constants as their equipped counterparts (the initial alignment used 0.82, 0.72 and 0.78 respectively). This includes the Company rack, both civic shelves and the upper-floor civic pistol display. Shelf bounds are recomputed after applying the display scale, retaining the 15 mm support allowance. Changing the equipped size now changes future store instances too, avoiding a weapon visibly shrinking at pickup.

These constants reflect the current character-fit choices, not approved museum dimensions. The source Adams measures about 336 × 181 × 60 mm; at the current 0.78 scale it measures about 262 × 141 × 46 mm. The initial 0.82 Enfield scale yielded about 1.16 m; the correction below supersedes that choice.

Fresh Metal Company pickup/save and civic support/access checks PASS after scale alignment; rack and civic captures inspected. A concurrent interaction-pose type-inference compile failure was repaired with explicit Transform3D/Vector3 declarations, followed by a clean civic rerun (`/tmp/tlm_civic_scale_clean.log`).

## Enfield reference-length correction — 2026-09-27

Enfield scale is now `1.39065 / 1.41`, matching the Smithsonian specimen's recorded overall length (54¾ inches / 139.065 cm) against the audited 1.41 m source. See [Smithsonian collection measurement](https://collections.si.edu/search/results.htm?q=%22London+Armoury+Company%22). This replaces the 0.82 runtime scale. Stored and held instances share the constant. Existing sockets and palm targets incorporate the scale automatically.

Fresh Metal [side view](../characters/arjun/longgun_enfield_side.png) inspected; both palm targets reach the weapon (~0.17 mm right, ~0.15 mm left). Finger wrap, shoulder seating, exact model profile and final character approval remain open. `tools/weapons/validate_rifle.gd` and the Metal Company weapon-store pickup/support/save check PASS. The length audit now checks runtime length as well as source bounds.

## Upstairs sidearm table support — 2026-09-27

Pistol, knife and ammunition packets in both civic buildings now sit 15 mm above the actual meeting-table top (upper floor + 0.91 m). Each rotated/scaled model is centered at its pickup location and fitted by visible mesh bounds, replacing a fixed origin offset. The table and source models are preserved. Pickup targets remain above the tabletop rather than embedded in it.

`tools/world/validate_sidearm_display.gd` checks all six displays: model support height, containment, non-overlap, a downward physics ray onto the supporting table, and a room-side ray onto the pickup. Render evidence: [Town Hall table](captures/sidearm_table_TownHall.png), [Police table](captures/sidearm_table_DistrictPolice.png). This repairs physical placement, with historical form and hand-contact approval still open.

All six support/containment/non-overlap/table-hit/pickup-ray checks PASS headless (`/tmp/tlm_sidearm_table_headless.log`). Town Hall and separate Police Metal views inspected; Police Metal checks PASS (`/tmp/tlm_sidearm_police.log`). Use `-- --police` to capture the Police table in a separate renderer run.
