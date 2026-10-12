# Pottery household pilot — House30

Status: integrated as a cold, decorative production layout; player-route and final art review remain open. The working setting is Awadh, late June 1857. Oudh pottery references from 1895 are later regional evidence, not a direct 1857 observation.

## Integrated scope

House30 keeps its domestic plan, courtyard, cooking vent and three breakable drying pots. The basic two-disc wheel is replaced with a single clay wheel, axis and ground bearing. A preparation board, working water jar, raised finished-ware deck, feet under the drying pots and a separate cold firing-cover candidate complete the displayed production sequence. The lamp moves to the front shelf to clear access.

The yard at (-356,153) is an above-ground visual cover candidate; the terrain is not excavated. It has no fire or firing action. Pit depth, internal stacking and fuel/air paths remain unresolved. Pottery pieces are breakable props and do not imply a throwing or firing simulation. No resident, seasonal system or save state is added.

## Current verification

Run the combined live-world check:

```sh
Godot --headless --path . res://tools/world/validate_cultivating_household.tscn --quit-after 2500
```

The check passed on 2026-10-11: 33 homes remain; House30 has one replacement wheel, three tagged drying vessels, three finished vessels, and a firing yard explicitly marked cold. The House1 and House25 pilots are checked in the same run. This structural check does not establish ordinary-player routes, contact, rendered quality or FPS. The source worktree's earlier House30 fixture reported six player routes passing on its then-current candidate; current-main route review is still open. Startup emits an unrelated cart indexing error at `vehicles/bullock_cart.gd:58`.

Runtime source: `world/suryagarh/settlements/pottery_household.gd`; integration call: `world/suryagarh/settlements/bhairavpur_village.gd`; lamp location: `world/suryagarh/settlements/village_night_life.gd`.

## Post-merge verification — 12 October 2026 IST

The historical bullock startup exception is repaired. Fresh-source/shared save/story and actual exported-pack linkage passed. Post-fix headless four-kit/five House27-route checks passed without diagnostics; native routes completed but coachman Metal fence errors keep renderer/visual/FPS acceptance open. See [exact scope and reproducible commands](extra_profile_merge_verification.md). This does not add full routes/contact approval for the other houses.
