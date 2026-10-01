# Administrative buildings — exterior and interior refinement

2026-10-01. Existing Collectorate, District Treasury and British Courthouse, in their main-world footprints. No new sites or terrain bake. Existing district geometry, open approach, office layout and central hearing aisle retained. No visible names, room labels or posted text.

Original procedural refinement in `settlements/administrative_finish.gd`:

- Shared lime-finish material with restrained damp band replaces the coarse square wall pattern. Stone paving uses small joints and slab variation. Timber and roof tiles receive separate finishes. Imported props retain their own materials.
- Tile skins no longer double as the interior ceiling: timber boards, paired rafters, tie beams, wall plates and king posts provide visible roof construction. Veranda soffits, fascia, beams and knee braces connect to the existing columns.
- Door jambs, heads, thresholds and two fixed-open boarded leaves with cross rails, iron straps and hinge pins. The subsequent [operations pass](administrative_operations_2026-10-01.md) replaces these leaves with working physical doors.
- Window sills, jambs and heads surround the actual rear openings. Paired shutters hinge outward and have board seams, cross rails and iron hinges. Twelve actual front windows replace the solid veranda-side walls, adding daylight without shrinking the central entrances.
- Seven supported office chairs; desk aprons, stretchers, drawers, ink pots, reed pens and existing folio assets. Record shelves have uprights, shelves and document bundles in each Collectorate office. Treasury counting trays carry small decorative metal discs; these are scenery, not inventory pickups. Waiting benches receive stretchers. Judge dais has rails beside the clear central opening.
- Six oil lamp cages, reservoirs, hoods and flames with restrained local warm light; hangers terminate beneath the roof boarding.

Existing household folio assets reused. Other detailing is original geometry and code; no new downloaded assets. This pass is a visual construction candidate, not an exact historical reconstruction or final art approval.

Verification: `tools/world/validate_administrative_district.gd`; report `administrative_district_validation.json`. Native Forward+/Metal captures: overview, three close exteriors, three interiors, a workstation close view and a 22:00 workstation view. Entrance walks and terrain/no-text checks are rerun. Chair bases are checked against floor/dais collision. Latest checks PASS: three entry walks, 35 terrain samples, seven chair supports, twelve open front apertures and zero building text. Day and 22:00 views inspected; the workstation capture position was corrected to stay inside the side wall. Mechanical checks do not certify player animation, chair sitting, office operations or target-hardware performance.

Open: owner acceptance, continuous camera/contact review, staff acting and period costume approval, approach route, landscape terrace edges, broader night behaviour and 8 GB hardware. Other building refinements remain documented in `building_realism_2026-10-01.md`, `cantonment_service_realism.md`, `civil_lines.md` and `hooghly_port.md`.
