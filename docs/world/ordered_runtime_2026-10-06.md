# Current native world diagnostic — 2026-10-06

Verified1280×720 SubViewport renders the normal root world on Metal/AppleM4. All3 pixels inspected, no script errors, source/scenes/resources stable against `ordered_runtime_source_snapshot.json`. The diagnostic disables stationary player physics/body/camera-clearance only; residents and world simulation remain active. No normal-controller/gameplay FPS or target-hardware approval.

|Area|p50 ms|p95 ms|Median draws|
|---|---|---|---|
|cantonment|6.212|38.225|3717|
|civil_lines|7.145|9.064|3708|
|village|26.283|33.200|2272|

65,792 nodes, about1.0GB tracked static memory. Sampling is short and frame timings are uneven; cantonment p95 exceeds33.3ms. This remains a diagnostic, not a stable whole-game performance pass. CPU-process fields are single monitor snapshots rather than percentiles and must not be compared directly with frame p50/p95. No causal comparison to older profiles with different viewport/source snapshots.

Command: `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/profile_ordered_runtime.gd > /tmp/tlm_order_runtime.log 2>&1`. Report `runtime_profile_ordered_2026-10-06.json`; clear screenshots `captures/ordered_village.png`, `captures/ordered_civil_lines.png`, `captures/ordered_cantonment.png`. Initial invalid root-placement/player-occlusion runs were rejected, with diagnostics in ordered-completion ledger.
