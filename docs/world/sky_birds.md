# Sky birds — 2026-10-07

Integrated twelve flocks of five birds in Suryagarh, with continuous circling, banking, independently phased wingbeats and glides. Shared original silhouettes, no physics or shadows, 650 m visibility cutoff.

Focused validation: SKY BIRDS PASS for count, movement, wing nodes and terrain clearance. Native Metal/Forward+ on Apple M4: airborne silhouettes reviewed. Temporary outputs deleted. Both focused runs reported two ObjectDB instances leaked on exit, cause unverified. Full-world normal-speed visibility and performance acceptance remain open.

Test: restart Suryagarh and look upward from Bhairavpur; walk through open fields toward the river and watch the flocks. Debug F4 cycles landscape review points. Reusable check: Godot --headless --path . --script tools/world/validate_sky_birds.gd.

## Logic follow-up — 2026-10-08

Daytime flock activity now follows GameTimeSystem. Flocks fade through twilight, hide overnight and skip wing/route simulation while hidden. Sleep/load jumps update activity on the next frame. Flight faces the actual tangent and mirrored wings flap together. Clearance samples terrain beneath each bird as well as the route centre. Missing-clock isolated fixtures retain daytime activity.

Expanded reusable checks cover all 24 hourly states, partial twilight visibility, no night motion updates, daytime recovery after clock jumps, forward-facing travel and symmetric wingbeats. Native Metal checks PASS; two ObjectDB exit leaks remain unresolved. Full-world normal-speed dusk fade and terrain-route appearance remain open. No landing/perching simulation is claimed.

## Smooth flight and bounded cost — 2026-10-09

Each flock now samples its complete orbit at startup and flies at a fixed safe altitude with small gliding oscillation. This removes 120 terrain-height queries per active frame and avoids tracing abrupt terrain steps vertically. A 240-step route sweep with all 60 birds passed clearance checks. Focused Apple M4 headless measurements: motion-only update about 61 microseconds; update plus terrain validation about 259 microseconds. These figures are subsystem CPU samples, not world FPS or an 8 GB hardware certification.

Both focused validators now stop audio and allow backend retirement before exit; current headless runs pass without ObjectDB warnings. Historical warnings are not evidence of a remaining sky-owned leak. Reusable full-world route: tools/world/review_sky_world.gd (native renderer required); captures are optional and require caller-owned temporary storage and cleanup.

## Full-world route — 2026-10-09

Three routes now lie near Bhairavpur, riverbank and agricultural approaches; the remaining routes preserve broad landscape coverage. Route sweep verifies a flock remains within 180 m horizontally of each of those approaches. Final actual-world Metal run printed SKY WORLD ROUTE PASS, with motion assertions during day/twilight and no flight simulation at night; clean exit. Fresh 1280×720 images show distant airborne silhouettes in day/twilight and the actual-world moon/stars at night. The fixture hides Arjun only to keep the eye-height diagnostic camera outside his visible mesh; this is not ordinary player-camera acceptance.

Final route frame p50/p95 milliseconds: village 32.3/33.5, dusk 7.2/13.9, night 7.1/10.4, dawn 7.0/12.9. Short samples include warmup/scene streaming and concurrent renderer activity; not a stable world FPS certification. Whole-world performance and uninterrupted user-controlled traversal remain open. All review images removed. Repeat disposable native route with python3 tools/world/run_sky_review.py; its temporary images are deleted in cleanup even on timeout or interruption.

## Main-game integration — 2026-10-09

Configured title-menu startup and its real journey callback verified. Headless actual-world integration printed MAIN SKY INTEGRATION PASS for both New Journey and Continue with an existing save; exit 0, no reported script errors or ObjectDB leaks. Both routes instantiate the 60-bird system and use the world's GameTimeSystem; WorldEnvironment uses the moon/star shader installed by Sun. Restored-clock activity/visibility checked after Continue. No saves written or captures retained. Reusable check: Godot --headless --path . --script tools/world/validate_main_sky_integration.gd. Native rendering evidence remains recorded separately above.
