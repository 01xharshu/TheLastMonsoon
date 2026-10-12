# Cultivating household pilot — House1

Status: integrated in the main Suryagarh world; regional appearance and ordinary-player review remain open. Awadh and late June 1857 are working assumptions, not a final story-calendar lock.

## Integrated scope

The pilot uses the existing `BhairavpurHouse1` site at (-321,214), keeps its footprint and doorway, and adds one `CultivatingKit`. It replaces only this dwelling's generic household prop and roof treatment. The kit adds covered domestic-water vessels, raised grain and seed storage, a supported thatch threshold shade, a preparation mat, decorative sickles, a small work court and a linked worked-earth plot at (-321,198). The House1 lamp is moved clear of the vessel approach. No new human, harvest action, water source, crop species, seasonal progression, or save state is added.

The field is a small visual sample, not a claim that it feeds the household. Its water basis, crop species and exact period forms remain unresolved. The regional gazetteer basis is later evidence and does not establish an exact 1857 village reconstruction. Keep this treatment limited to House1 until the regional plan and art are reviewed.

## Current verification

Run the reusable live-world check with:

```sh
Godot --headless --path . res://tools/world/validate_cultivating_household.tscn --quit-after 2500
```

The check passed on 2026-10-11: actual Suryagarh startup completed; the village retained 33 homes; House1 had the kit, two covered vessels with collision components, two stored-grain sacks, the moved lamp and linked plot. The check does not establish player route/contact, rendered quality, motion or FPS. Startup also emitted an unrelated bullock-cart error at `vehicles/bullock_cart.gd:58` while this household check passed.

The candidate worktree reported seven player routes passing headless and Metal on 2026-10-05. Its reports and captures were disposable output and are not retained here; those older results do not replace a fresh route or visual review against the current main world.

Runtime source: `world/suryagarh/settlements/cultivating_household.gd`; callsite: `world/suryagarh/settlements/bhairavpur_village.gd`; lamp position: `world/suryagarh/settlements/village_night_life.gd`.

## Post-merge verification — 12 October 2026 IST

The historical bullock startup exception is repaired. Fresh-source/shared save/story and actual exported-pack linkage passed. Post-fix headless four-kit/five House27-route checks passed without diagnostics; native routes completed but coachman Metal fence errors keep renderer/visual/FPS acceptance open. See [exact scope and reproducible commands](extra_profile_merge_verification.md). This does not add full routes/contact approval for the other houses.
