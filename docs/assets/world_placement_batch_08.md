# Asset-first world placement — 2026-10-01 IST

Earlier absent candidates are now instantiated by `world/suryagarh/settlements/asset_first_placement.gd`, called once from the main world's `_ready()` before pending saves are applied. Existing buildings and surveyed terrain are retained.

| Location | Integrated props / behavior |
| --- | --- |
| Arjun and Dev's home | Rest-set mat, stool and switchable lamp around the existing world-root Charpai. The prefab's second bed is removed, preserving one bed and its sleep/save references. Indoor pot fills owned pouches. Spare collectible pouch sits on the storage chest. |
| Bhairavpur House 1 courtyard | Cooking set, sack and basket; visual pot replaced by an actual water-source wrapper. One roti pickup on the griddle. Cooking itself remains unsupported. |
| Town Hall ground floor | Records desk, folio, letter, stool and switchable lamp. Documents are decorative generic content; no invented quest or read/collect prompt. |
| Bhairavpur grain store | Market supply counter with basket, parcel and sack. Two fence panels and a manually open hinged gate outside the rear storage area. No trade or gate-operating prompt. |
| Company Armoury | Supply shelf with sealed parcel/note. Existing persistent bandage pickup moved to the shelf and uses the shared roll visual; its existing ID and reward are retained. Old small shelf remains as empty furniture, since its visual has already been merged into the building. Existing ammunition and weapon racks remain. |
| Company stores yard | Freestanding barricade and low masonry cover beside the stores, outside the main court road. No new cover registration or enemy sight behavior is claimed. |

Roti and spare pouch have stable IDs in `household_pickups`. SaveManager serializes remaining IDs, removes collected objects on restore, and accepts older saves without the field. Both pickup scripts reject another call once queued for deletion, preventing duplicate same-frame rewards. All tested rewards still occur immediately; final visible transfer timing and hero animation remain open. An additional pouch increases capacity through existing inventory rules (two bags = 4 L); this pass does not change those rules.

Rest dressing in Arjun's home (test output deleted)
Cooking corner in the courtyard (test output deleted)

Validation: `tools/world/validate_asset_first_placement.gd`; `placement_validation_headless.json` and `placement_validation_metal.json`. PASS for placement support gaps within 7 cm, empty capsule overlap at approach markers and sampled final 0.8 m approach strips, once-only roti/pouch grants, indoor pot filling, actual JSON save serialization before/after collection, restoration removal and legacy-save compatibility. The short approach checks are not full player routes or step-up approval at the grain-store platform. First fence/gate references overlapped storage bins; moved boundary outside the bins and approach references to the outside face.

Native Metal captures `placed_*.png` cover rest/cooking/records/market/shelf/gate/yard plus indoor pot, pouch and roti. First five location images inspected; assembly appearance is a candidate, not owner art/contact approval. The market and yard views are also reviewed separately. Lamps in rest and records were replaced with unlit switchable wrappers instead of permanently glowing visual flames.

Existing save regression: `tools/world/validate_save_flow.gd` uses isolated validation saves; PASS. A concurrent resident-journey `paper` declaration prevented type inference; added explicit Vector3 type so the world can compile. Early full-world runs reported 2 ObjectDB/1 resource shutdown leaks alongside that compile failure; final placement and audit reruns completed without those messages. This does not establish whole-game approval.

Fresh instance inventory: `main_world_item_audit_2026-10-01.json`: all 21 household scene entries have at least one instance, plus 1 roti wrapper, 1 loose pouch wrapper, 2 pot wrappers and 36 lamp wrappers. The earlier missing-instance table in the audit document is historical; this pass resolves those placements while retaining unresolved art/interaction work. Remaining: full controller walking/held-E approach review, authored document content where required, craft tools/weapon-rack refinements, ledges/rubble, gate interaction if enabled, final animation/contact and performance.
