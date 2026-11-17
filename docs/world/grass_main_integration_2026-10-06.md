# Authored grass integration into main — 2026-10-06

Status: INTEGRATED / FINAL ART AND WHOLE-GAME PERFORMANCE OPEN. Source comes from the terrain owner's d388 checkout. This task integrates only the grass blade mesh/shader and grass-only refresh into the current main landscape. It does not replace the landscape with the owner's older terrain snapshot or import garrison changes.

Before mutation, the exact main landscape was copied to `/tmp/tlm_grass_before_landscape.scn`. Paired native Metal comparisons use that actual Bermuda baseline, with no substituted shader. Baseline/after reports: `grass_before_profile.json`, `grass_after_profile.json`. Captures: `captures/grass_2026-10-05/{before,after}_{close,walk_height,wide}.png` (fixed SubViewport1280×720). Profiler excludes buildings, characters and active gameplay, so this is not whole-game performance acceptance. Metal's GPU timing currently returns zero and must be treated as unavailable.

Commands:
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/profile_grass.gd -- --before`
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/bake_landscape.gd -- --grass-only`
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/validate_grass_preservation.gd`
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/profile_grass.gd`

The first refresh stopped before save because main has an extra non-numbered NatureTiles child. The refresh now skips such content and processes only `Nature_<integer>_<integer>` tiles. Preservation validation compares non-grass tree/rock buffers and transforms, terrain/water geometry and ground collision height maps. Fresh validation and paired pixels subsequently passed as recorded below.

2026-10-06 11:47 IST: bake PASS631068 tufts/32.46s. Native preservation PASS:238 non-grass batches/2929 tree-rock instances and144 ground collision tiles, terrain/water geometry unchanged. `/tmp/tlm_main_grass_preservation.log`, `grass_preservation_2026-10-05.json`. After profile running after save/title runs finished; baseline close p50/p95 6.902/7.632ms, walk6.921/7.410ms.

2026-10-06 11:47 IST: paired Metal profile and pixels reviewed at1280×720 on AppleM4.

|View|Before p50/p95 ms|After p50/p95 ms|Draws before→after|
|---|---|---|---|
|close|6.902/7.632|6.901/7.496|204→228|
|walk_height|6.921/7.410|6.897/7.670|204→228|
|wide|6.904/7.254|6.884/7.547|206→233|

After: 14516 grass batches, 11789 sampled roots, maximum collision surface discrepancy 0.008176m. Blades visually replace large foliage cards; final density/organic variation remain open. Metal GPU timers return0; render-CPU close value is inconsistent with wall sampling and is not used for acceptance. Desktop presentation can limit the wall measurement; these numbers establish only the observed isolated comparison. Whole game, active traversal and target budget remain unverified.


2026-10-23 continuation: grass indexing is applied to each shared ArrayMesh in place once during the existing startup task. This replaces per-batch mesh rebinding. Native direct-scene setup measured main 942.202→13.591 ms and wilderness 1000.311→10.079 ms; these are grass-setup timings, not total load time or FPS. All 22,102 grass instance buffers, mesh identities and culling bounds passed parity; repeated setup is idempotent. Future bakes index after normal generation. Core90→42/detail270→126vertices retain triangle counts; normal encoding tolerance<0.0002 and native image channel delta≤2/255.

The blade shader skips wake calculations for inactive emitters or vertices outside their exact8m/3.5m influence, skips wind/wake calculations after full distance fade, and shares the inverse model matrix. The original18m chunks, fade thresholds, density and shadows remain. Whole-world FPS improvement is unestablished. Three larger-batch candidates were tested and removed because extra submitted geometry outweighed draw savings; production does not consolidate grass chunks.

Reusable checks (temporary logs/userdata cleaned by the runners):
- `python3 tools/world/run_grass_shader_check.py`: git-HEAD shader baseline versus current shader, native1280×720 actual-landscape A/B/A, frozen nonzero wind and active/inactive wake; exact pixel parity required. HEAD must contain the intended baseline.
- `python3 tools/world/run_grass_world_check.py`: actual populated-world startup/opening skip/grass-village-city sample using disposable user data. Post-change observations only, not A/B attribution.
- `Godot --path . --rendering-driver metal --resolution 1280x720 --disable-vsync --script res://tools/world/validate_grass_indexing.gd`: geometry/buffers/bounds/idempotence; use OS-temp `--log-file` and cleanup.
