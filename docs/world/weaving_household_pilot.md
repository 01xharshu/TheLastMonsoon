# Weaving household pilot — House27

Status: yarn preparation and finished-cloth storage integrated; the inherited loom remains an explicitly unresolved placeholder. Awadh and late June 1857 are provisional assumptions.

## Integrated scope

The kit replaces only House27's generic household prop. It adds a supported preparation board and mat, a rack with dry yarn hanks, decorative winding cores, and a raised indoor deck for folded cloth. The existing `WeaverWorkSurface`, collision envelope, courtyard, household rooms, and loom placeholder remain in place. No worker, spinning/weaving action, production simulation, or fibre-source claim is added. The House27 lamp moves to the front shelf to clear the new storage approach.

## Current verification

The combined live-world fixture is `tools/world/validate_cultivating_household.tscn`. On 2026-10-11 it passed five ordinary-input Player routes against current main: entry, exit, yarn preparation, loom approach, and cloth storage. The check also confirms the existing single loom remains, 33 homes survive, and the House1/House25/House30 pilots still build. This does not validate loom operation, hand contact, rendered quality or FPS. Startup emits an unrelated cart indexing error at `vehicles/bullock_cart.gd:58`.

Runtime source: `world/suryagarh/settlements/weaving_household.gd`; integration call: `world/suryagarh/settlements/bhairavpur_village.gd`; lamp location: `world/suryagarh/settlements/village_night_life.gd`.

## Post-merge verification — 12 October 2026 IST

The historical bullock startup exception is repaired. Fresh-source/shared save/story and actual exported-pack linkage passed. Post-fix headless four-kit/five House27-route checks passed without diagnostics; native routes completed but coachman Metal fence errors keep renderer/visual/FPS acceptance open. See [exact scope and reproducible commands](extra_profile_merge_verification.md). This does not add full routes/contact approval for the other houses.
