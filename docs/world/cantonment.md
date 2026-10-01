# British cantonment construction batch

Updated 2026-10-01. Integrated through `settlement_builder.gd` into the normal Suryagarh world, southeast of the Company compound. This is a fictional construction blockout, not an approved historical reconstruction.

Survey centre: **(500, 8.5, 470)**. The shared landscape plot is 140 × 120 m, with a 52 × 48 m parade yard. Four separate sepoy barracks contain 24 cot places. Separate British barracks now provide six cot places, and officers’ quarters provide two beds, desks and clothes chests. Other buildings are an eight-bay cavalry stable, eight-cot military hospital, commissariat depot, combined grain/fodder warehouse and a powder magazine. Buildings have physical walls, roofs, raised floors and open entrances. The hospital has a collectible bandage using the existing persistent medical-supply system. Supply crates and powder barrels are scenery at this stage.

The magazine has three actual rear ventilation openings with grille bars, buttresses and separate protective walls. These establish a construction direction; powder handling, blast behaviour and safe-storage rules are not implemented.

`landscape_layout.gd` remains the terrain authority. `tools/world/bake_cantonment_region.gd` updates six resident terrain/collision tiles and clears plot vegetation, retaining the rest of the current landscape and concurrent port work. Regional bake: PASS; 5,239 nature instances cleared. The approach road is registered in the shared layout and road mask; its full walking/cart route and slopes remain unverified. The field-map raster has not been regenerated.

Earlier world history: `docs/agent/history/2026-09-30-handoff-detail.md`.

Validation result: PASS on native Forward+/Metal: eleven entrance walks, four barracks, 35 resident-ground samples and three unobstructed magazine vents. Overview inspected; visible architecture remains a simple blockout. Full-world logs also exposed concurrent detention-contact parse failures and missing NPC skeleton imports, so overall-world health is not certified.

Focused validation: `tools/world/validate_cantonment.gd`; report `cantonment_validation.json`; native overview `captures/cantonment_overview.png`. Doorway tests use Arjun's collider, slide and step helpers, rather than checking line of sight alone. This is a mechanical route check, not normal-speed animation acceptance. The stable destination is its front aisle, rather than inside a stall divider. Full-world test output may contain concurrent character/import errors; a focused PASS does not certify those other systems.

Open: sepoy and horse population; military routines; hospital service; supply and magazine operations; detailed architecture, windows and material ageing; close interior lighting/contact review; approach route and map refresh; historical/owner approval; 8 GB performance. Next location batch: Collectorate, treasury and courthouse. Full scope is in [the 40-location ledger](location_integration_40.md).

Design references: [National Army Museum, East India Company armies](https://www.nam.ac.uk/explore/armies-east-india-company); [Historic England magazine example](https://historicengland.org.uk/listing/the-list/list-entry/1014553), used for ventilation and protective-wall principles, not as an exact Indian architectural model.

2026-10-01 correction: all exterior building names removed under the user's no-text-on-buildings direction. Internal scene names remain for development only.

Military facility extension (2026-10-01): BritishBarracks and OfficersQuarters added inside the existing northern plot edges. Headless and native Forward+/Metal eleven-entrance player walks PASS, with four sepoy barracks, British barracks, officers’ quarters, 35 terrain samples and three magazine vents. Fresh overview inspected: low plaster/tile blockout buildings around a clear parade square; detailed architecture remains open. Logs: `/tmp/tlm_military_sites_headless.log`, `/tmp/tlm_military_sites_metal.log`.

Service-building pass (2026-10-01): church and cemetery now integrated, stable moved two metres north, warehouse/ward/stall furnishings and rear ventilation authored. Current twelve-entrance + cemetery route and close Metal evidence: [service realism](cantonment_service_realism.md). This supersedes the eleven-building count above; period and art approval remain open.
