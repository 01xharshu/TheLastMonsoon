# Activity sets, part B — 2026-10-01 IST

Three reusable assembly candidates in `objects/household/sets/`. No existing world placement is replaced.

Rest, market and armoury arrangements (test output deleted)

| Set | Included assets and current behavior | Final animation/contact checklist |
| --- | --- | --- |
| `rest_corner.tscn` | Existing scripted charpai, woven floor mat, shared stool and visual lamp. Charpai retains its sleep behavior; lamp has no light-switch component. | Approach, stow weapons, sit/lie/wake/stand with palm/sole/bed contact, clear exit; lamp action if enabled. Existing sleep prototype still needs normal-speed review at final placement. Mat requires no action unless sitting/resting on it is added. |
| `market_supply.tscn` | New timber counter, shared basket, parcel and stock sack. No vendor, trade prompt or inventory reward. | Customer/vendor approach; grasp/lift/store goods, exchange payment if trading is implemented; exact reward timing and cancellation. Parcel untying needs deformable wrapper/twine. Basket/sack decorative unless handling is enabled. |
| `armoury_supply.tscn` | New two-level supply shelf, shared bandage roll, sealed generic parcel and stock note. No new ammunition type, weapon rack, healing or pickup reward. | Shelf-height reach and bandage/parcel grip, lift/store, read note if enabled; satchel retrieval and wound wrapping remain separate actions. Existing medical pickup can use the shared visual when integrated. |

Approach references are named `Approach`; rest also has `ClearExit`, market `VendorPosition`/`ExchangeTarget`, armoury `CollectionTarget`. Nested prop grip markers remain intact. Lamp support uses the shared stool's `Seat` reference (0.44 m). Counter top is 0.76 m, shelf top 0.97 m; props sit at these support heights. Table/shelf members and existing charpai/storage have collisions; loose visual props require appropriate pickup bodies at integration.

Builder: `tools/assets/build_activity_sets_b.gd`. Review: `tools/assets/review_activity_sets_b.gd`. Headless and native Metal PASS for scene loading, visible mesh bounds/floor baseline, approach references, retained charpai script and support collider rays on bed/counter/shelf. Reports: `activity_sets_b_validation_headless.json`, `activity_sets_b_validation_metal.json`; native captures: `activity_sets_b_overview.png` and `activity_sets_b_{rest_corner,market_supply,armoury_supply}.png`. Overview inspected. These checks do not validate player routes, sleep timing, vendor behavior, final hand contact or owner art approval. New timber furniture is a basic geometry/material candidate; ageing/joinery refinement remains open.

The market set is a supply display, not a complete craft station. Craft-specific tool/material assets and an equipped armoury rack remain open within batch 3. Next easiest asset batch: reusable fences, barricades, cover and gate components. Character animations remain in the final pass.
