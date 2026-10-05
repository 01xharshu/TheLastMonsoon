# Runtime optimisation

Updated 2026-10-05 12:47 IST; task /root; IN_PROGRESS (focused implementation complete, whole-game performance open).

Implemented 100 ms sun/moon/sky/ambient/fog cadence, no lighting writes while the clock is unchanged, and immediate refresh for clock jumps of at least 2.88 game minutes. Player interaction and overlay reject distant anchors with squared distance before availability/projection/rays; special door latch anchors remain authoritative. Production files: `world/suryagarh/systems/sun_controller.gd`, `player/player_controller.gd`, `interaction/interaction_overlay.gd`. Preserve other concurrent edits in these files.

Behaviour PASS: old/new selection parity, exact range boundaries, weapon projection, unavailable targets, far door roots with nearby latch anchors, overlay anchors, clock pause/jump/midnight/cadence. Zero distant availability calls in both selection and overlay. Reference method exists only in `tools/world/runtime_interaction_reference.gd`.

Same-run five-round CPU medians from `/tmp/tlm_runtime_validation.log`: 200 interaction searches 303023 to 263038 us (13.2% lower); 6000 lighting steps 11221 to 4348 us (61.3% lower). The shared `runtime_optimisation_validation.json` was subsequently refreshed by another run: 63031 to 47394 us selection, 6535 to 2090 us lighting, still PASS. Absolute timing varies with workload; these are subsystem measurements, not whole-game FPS gains.

Native diagnostic: `runtime_profile_lighting_after.json`, log `/tmp/tlm_runtime_lighting_after.log`; village p50/p95 87.610/113.035 ms, 3053 draws; Civil Lines 149.121/195.272 ms, 3839 draws; cantonment 128.001/168.240 ms, 3856 draws; 52184 nodes, about 706 MB tracked static memory. Concurrent batching/world changes altered node/draw counts from the baseline, invalidating causal before/after FPS comparison. Earlier baseline/after reports label the requested 1280x720 window as resolution. Fresh viewport captures reveal actual 5120x2880 backing pixels; the profiler now records actual viewport size separately. Earlier resolution claims are unverified.

Fresh native `captures/optimisation_day.png` (09:00) and `captures/optimisation_night.png` (22:00) inspected: daylight shadows and night darkening update correctly, bungalow/tree silhouettes remain present. Static views do not establish continuous lighting motion, gameplay or final art approval. Existing steep terrain cut remains an art issue.

Commands:
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_runtime_optimisation.gd > /tmp/tlm_runtime_validation.log 2>&1`
- `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/world/profile_runtime.gd -- --after > /tmp/tlm_runtime_lighting_after.log 2>&1`

`git diff --check` PASS. Native run exited 0, no script errors; existing animation graph deprecation warnings remain. Shared handoff size check exceeded 6000 characters; preserve other task entries.

Exact next action: establish a stable source snapshot and explicit render-pixel budget, run the three cameras plus a normal gameplay route without concurrent rendering, then attribute rendering/physics/animation cost. Prioritise remaining static draw submission and distant simulation according to those measurements. Do not label the game fully optimised without agreed target hardware and frame/memory budgets.
