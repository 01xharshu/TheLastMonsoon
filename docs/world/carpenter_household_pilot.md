# Carpenter household pilot — House25

Status: supplemental material-flow dressing integrated around the existing asset-first station. Player clearance and final appearance remain open. Awadh and late June 1857 are provisional assumptions.

## Integration decision

The source worktree's original House25 patch expected an earlier village version: it added a second bench and simple duplicate mallet/chisel props. Main already has `CarpenterWorkSurface` with fitted tools and collision. That station remains the sole work surface. The safe subset replaces the generic household prop and coarse timber block with raised plank stock and adds a bounded offcut bay and two plain stool outputs. No resident, crafting action, new animation, or exact regional tool/wood claim is introduced.

The plank species, joinery and stool profile remain unresolved. This makes a candidate workflow legible; it does not establish a complete or historically authenticated Awadh workshop.

## Current verification

Run:

```sh
Godot --headless --path . res://tools/world/validate_cultivating_household.tscn --quit-after 2500
```

The live-world check passed on 2026-10-11: 33 homes remain; House25 has nine stock planks, seven offcuts and two stool outputs, while exactly one existing carpenter work surface remains. The same check validates House1's cultivating pilot. It does not test ordinary-player access, contact, rendered appearance or FPS. Startup prints an unrelated bullock-cart indexing error at `vehicles/bullock_cart.gd:58`.

Runtime source: `world/suryagarh/settlements/carpenter_household.gd`; integration call: `world/suryagarh/settlements/bhairavpur_village.gd`.

## Post-merge verification — 12 October 2026 IST

The historical bullock startup exception is repaired. Fresh-source/shared save/story and actual exported-pack linkage passed. Post-fix headless four-kit/five House27-route checks passed without diagnostics; native routes completed but coachman Metal fence errors keep renderer/visual/FPS acceptance open. See [exact scope and reproducible commands](extra_profile_merge_verification.md). This does not add full routes/contact approval for the other houses.
