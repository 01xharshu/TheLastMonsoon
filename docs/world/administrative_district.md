# Collectorate, District Treasury and British Courthouse

Construction batch, 2026-10-01. Three separate buildings integrated into the normal Suryagarh world through `settlements/administrative_district.gd`, east of the existing thana. Fictional architectural candidates; historical and final art approval remain open.

The shared plot is centred at (520, 120), grade 10 m, with a 150 × 120 m footprint. Collectorate centre (520, 95); Treasury (477, 132); Courthouse (559, 130). Access joins the existing cantonment road at (425, 150), then follows a southern approach to the district forecourt.

- Collectorate: shaded veranda and waiting benches; three office areas for revenue, Collector and Magistrate, with writing desks and ledger props.
- Treasury: counting desks and a separate rear strongroom area with stored crates. Access is currently open; guards, secure doors and treasury transactions are pending.
- Courthouse: central hearing aisle, six audience benches, clerk desk and raised judge's bench. Hearings and court staff are pending.

All three buildings have physical walls/floors, supported verandas and genuine rear window openings, without building names, room labels or posted notices. They are constructed from existing project materials and original procedural geometry; no new third-party assets were added.

The regional baker updates six resident terrain/collision tiles and removes vegetation from the new plot and road, preserving the rest of the current world. Native bake PASS: 4,344 nature instances cleared. Road registration and mask updated; field-map raster and full approach traversal remain open.

Focused native Forward+/Metal validation PASS: all three entrance walks, 35 resident terrain samples and zero text/notice nodes in the new districts. Four native views inspected. Initial captures exposed open roof gables; the roofs were raised above the masonry and both end gables closed before recapture. User direction: no text on any building. Exterior names, interior room labels and the three newly added posted notices were removed; labels on older settlement buildings and their posted notices were also removed.

Validation tool: `tools/world/validate_administrative_district.gd`. Evidence: `administrative_district_validation.json`, `captures/administrative_district_overview.png`, `captures/collectorate_interior.png`, `captures/treasury_interior.png`, `captures/courthouse_interior.png`. Mechanical entry checks use Arjun's collider and step helper. They do not certify normal-speed animation, NPC contact, office gameplay, historical appearance or target-hardware performance.

Outstanding: close visual refinement, period window/door detail, guards and staff, office/revenue and hearing interactions, secure Treasury access, approach route/map, normal-speed player review and performance. See [all 40 locations](location_integration_40.md). Next construction candidates: telegraph office and post/dak station.
