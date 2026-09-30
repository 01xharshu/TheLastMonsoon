# Police expansion and ammunition — 2026-09-30

## Implemented gameplay

The DistrictPolice footprint increases from 26 × 24 m to 38 × 36 m (2.19 times the ground area). Both above-ground floors retain their entrance, main stair and gallery. New west-side office bays have door openings and desks. Two ground-floor holding cells and three lower detention cells have iron bars, open gates and masonry sleeping platforms. The lower floor is four metres beneath the ground hall, connected by a separate staircase and lit locally.

The foundation and hall slabs have a real stair aperture. A localized excavation copies the affected resident terrain mesh/collision data beneath the building; saved landscape resources and other tiles are preserved. Basement retaining walls and stairwell walls screen the earth. The affected tile loses its generated LODs; this small localized operation needs an 8 GB hardware/performance review. This is a playable architectural blockout, not finished period architecture. Existing generic stone course lines, roof/joinery, cells and room dressing need further art work. All cell gates are fixed open at present; locking and prisoner gameplay are absent.

Both CompanyArmoury and DistrictPolice now have a separate ammunition counter with three visible, collectible supplies:

| Supply | Reserve awarded |
| --- | ---: |
| Enfield paper cartridges | 24 |
| Revolver lead balls/caps | 30 |
| Double-gun shot charges | 16 |

Paper tubes and folded seals, small lead spheres, paper trays and percussion-cap tins are original procedural 3D geometry in `ammunition_display.gd`. These are representative packets; the visual piece count does not represent the exact inventory count. They are not modern metallic cartridges. The meshes remain provisional for exact calibre, packing and dated local issue. They can be taken through the normal interaction route and disappear after collection.

First-time gun pickup now grants a loaded firearm plus reserve: Enfield 1 + 24, Adams 5 + 30, double gun 2 + 16. Bow pickup grants 24 arrows. Re-equipping an owned gun does not regenerate rounds or reserves. The upper sidearm supply also grants the new revolver reserve on first ownership. This is a balance choice, not historical proof of carried quantities. Existing ownership in old saves does not receive a free reserve migration; these players can use the new world supplies.

Save/load now preserves ammunition pickup identities, Enfield chamber state, and ongoing reload timers/reserved rifle/double-gun charges. This prevents collected supplies respawning, an empty Enfield becoming loaded, and a cartridge disappearing when saving mid-reload. Older saves without ammunition pickup identities leave the new supplies available.

## Weapon contact

Enfield loading grip is lower and farther forward. The left palm approaches outside the actual muzzle/fore-end and its wrist aligns with the barrel and approach side. The cartridge remains anchored between the thumb/index joints after the pose. A sampled loading-palm clearance assertion covers the fore-end defect.

The revolver's left loading hand now uses the current right-hand/weapon transform, an outside-cylinder approach, a matching wrist orientation and partial finger curl. It previously queried a deferred attachment transform and aimed the palm into the cylinder. Fresh Metal reload close-ups were inspected. Complete cartridge insertion, ramrod handling and the full normal-speed sequence remain open. This does not certify every weapon/pose as free of body intersection. All weapons still require full idle/walk/run/aim/attack/reload/transition contact review on the accepted Arjun body; the currently wired appearance remains universally rejected.

## Verification and evidence

- `tools/world/validate_police_ammunition.gd`: real-player cellar down/up, office doorway, six 3D ammo supplies and unobstructed pickup rays, exact reserve awards, duplicate collection prevention, first Enfield reserve/chamber, and collected/empty/mid-reload save restoration.
- `tools/world/validate_civic_interiors.gd`: both civic entries, upper stair up/down and upper supplies PASS.
- Firearm, double-gun and AnimationTree focused checks PASS. Firearm/world fixtures report cleanup warnings; functional assertions and rendered approval are separate.
- Metal Forward+ captures: `/tmp/tlm_police_exterior_2026-09-30.png`, `/tmp/tlm_police_lower_cells_2026-09-30.png`, `/tmp/tlm_police_stairs_2026-09-30.png`, `/tmp/tlm_police_ammunition_2026-09-30.png`.
- Reload captures: `/tmp/tlm_enfield_cartridge_diagnostic.png`, `/tmp/tlm_adams_reload_diagnostic.png` (rejected temporary body, internal diagnostics only).

## Historical limits

The [Wellcome catalogue's contemporary Bengal jail report for 1857–58](https://wellcomecollection.org/works/tkajp7b3) establishes a relevant period research source, not this layout. Its full architectural content has not yet been inspected. Underground detention attached to this fictional thana has no established period/location-specific source and must remain unapproved. Do not present this blockout as a sourced reconstruction. A historical review must settle the institution's scale, offices, ventilation/drainage, cell arrangements and below-ground confinement before final dressing.

Next: complete normal-speed weapon contact and wrist/finger finishing; connect an authored cartridge insertion/ramrod sequence; add functioning barred doors and cell interactions; replace generic cell surfaces with sourced masonry/joinery; review all room and upper-floor routes in owner play; profile the expanded building and localized terrain change on target hardware.
