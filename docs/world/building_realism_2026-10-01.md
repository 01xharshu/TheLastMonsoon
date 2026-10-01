# Civic and residence realism — 2026-10-01

Scope: the existing Town Hall, District Police, and Government House interiors and exteriors. Existing plot positions, entrance ramps, stair layouts and pickup IDs are retained.

## Changes

- `building_finish.gdshader` / `building_realism.gd`: lime finish with smooth tonal variation, fine surface grain, high roughness and a restrained damp band at ground level. Civic plaster previously used the dark clay diffuse; the new finish reads as maintained lime rather than a uniform brown wall. Government House uses the same finish family with a cooler, paler tint.
- Government House central stone inset: small paving joints and individual slab variation, with a rough finish replacing the polished blank surface.
- Civic table aprons, connecting stretchers and trestle feet. Town Hall's empty lamp cages are replaced by reservoir, hood, cage and flame fixtures with local warm light, using the existing station lamp builder. Police retains its existing lamps.
- Government House chair legs and stretchers; ground-floor chairs lifted to the actual raised floor surface. Desk aprons, ledgers, paper and ink pots. Drawing sofas now have a seat frame, feet, separate cushions, arms and a back. Bedroom headboards, pillows and a folded cover make the bed arrangement legible.
- `validate_building_sites.gd`: extended full-world Metal capture to the Town Hall and Police interiors and Government House hall, study, drawing room and bedroom.

The finishes and furnishing are original procedural detail. This pass is visual design work and does not establish exact period provenance or final art approval.

## Verification

Government House focused validation exited 0, with 65 gate-to-hall, 46 stair and eight doorway samples clear and 74 windows retained (`/tmp/tlm_realism_house.log`). Godot reported one resource still in use during shutdown after the PASS marker. Civic interiors validation exited 0 and printed PASS (`/tmp/tlm_realism_civic.log`), including pickup and knife checks. New decorative joinery is non-colliding; the existing sofa seat collider is reduced to its new seat frame.

Metal capture command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --rendering-driver metal --path . res://tools/world/validate_building_sites.tscn
```

Log: `/tmp/tlm_building_realism_metal.log`. Visual inspection pending capture completion. No hardware performance or continuous player camera/contact approval is implied by the clearance fixtures.

## Civic construction continuation

Town Hall and District Police retain their existing main-world footprints. Added timber boarding and rafters beneath the roof tiles, wall plates, jointed stone parapet coping, bench stretchers and record-shelf uprights/backs. Ground-floor ceiling beams now stop at the stairwell opening instead of visually passing through the ascent. Rear rain pipes have outlets and splash stones surveyed against the local terrain, with pipe extensions down to grade. Added geometry is merged with the existing static material batches and does not introduce new lights or downloaded assets.

`validate_civic_interiors.gd` now captures each upper hall as well as its exterior and ground floor at 1280 × 720. Initial focused headless run: `CIVIC INTERIORS PASS`, including entrance, stairs, supply acquisition and knife interaction. First native run also reached PASS but reported a Metal GPU fence timeout; that run does not establish clean rendered verification. Final capture/check status follows below. Continuous player camera/contact, exact historical reconstruction, owner art acceptance and 8 GB hardware remain open.
