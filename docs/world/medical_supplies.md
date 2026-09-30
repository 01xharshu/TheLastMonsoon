# Bandage supplies — 2026-09-30

Functional prototype. Original cloth roll mesh with winding seams and loose strip; one collectible bandage on a small shelf in Company Armoury and District Police. Held E uses the existing supply interaction and shared medicine icon, granting `medkit` ×1 once. British/sepoy/police corpse looting remains unimplemented: the current NPC roster has no defeated-body inventory pipeline.

Satchel has a Bandage count and Use bandage button. One bandage restores up to 25 health (prototype tuning), caps at 100, and is not consumed at full health, with no supply, or when incapacitated. Legacy `bandage` item ID is also usable. Healing currently applies immediately; wrapping animation and real hand/contact timing are deferred by the asset-first production direction. The feedback says Bandaged wound with the amount healed; it is distinct from Bandage +1 collection.

Health now saves/loads with backward compatibility (older saves default to full health). Medical pickup IDs save independently of ammunition; collected supplies are removed on restore. Inventory retains bandage counts via the established inventory save dictionary.

Validation: `tools/world/validate_medical_supplies.gd`, native Metal PASS (`/tmp/tlm_medical_validation.log`): two placement IDs, duplicate-pickup protection, reward name/icon, damage/heal/cap/full/dead/empty guards, actual inventory button, saved health/item counts and removed collected pickup. Test performs direct collection calls; held-E approach, normal-speed dressing and owner art/contact approval remain open. Existing 16-item collection/burst regression also PASS (`/tmp/tlm_medical_parse.log`). Native shelf/rolled-cloth close capture: `captures/bandage_supply.png`. First camera position looked through the police office doorway pier; moved the capture camera inside the office, without changing world geometry.

Sources: `world/suryagarh/settlements/medical_supply.gd`, `player/consumable_component.gd`, `player/inventory_ui.gd`, `systems/save_manager.gd`; placement additions in civic building and settlement builder. No downloaded assets.

Next: owner review of shelf prop, approach/held-E pickup in both buildings, final-pass satchel retrieval/cloth wrapping/stowing; implement defeated-NPC loot before adding corpse rewards.

2026-09-30 follow-up: bandaging now triggers a cloth-roll/forearm motion prototype and blocks overlapping item uses. Healing still applies at start; cosmetic interruption does not refund it. Updated checks PASS after explicitly completing each cosmetic sequence between independent healing test cases. See [collection totals and item use](collection_merge_and_item_use.md) for rendered evidence and remaining contact/transfer timing.
