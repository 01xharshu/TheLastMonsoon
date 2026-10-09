# Horse vehicle speed and infrastructure map

Updated 2026-10-05 IST. Scope: make horse-drawn vehicles clearly faster than walking/running, retain optional skippable paid coach travel, and make existing infrastructure inspectable on the field map. Existing MakeHuman drivers are reused; this task creates no humans.

## Movement

All three playable horse-drawn bodies use `vehicles/cart_rider.gd`: 10 m/s forward cruise, 15 m/s fast travel, 5 m/s² acceleration and a controlled 3.4 m/s reverse. Arjun walks at 4 m/s and runs at 7 m/s. Paid coaches target fast travel with 0.75 throttle on aligned roads (11.25 m/s), slowing/stopping to align at bends. Household coaches now use the shared 10 m/s cruising speed and animate from actual distance travelled. Slow backing, alignment, boarding and obstacle stops remain intentional.

Single-horse and paired-horse vehicles select the imported gallop above 6 m/s. Wheels still turn from distance/radius, and hoof playback follows the active animation. This is a gameplay speed change, not final approval of horse stride, harness tension, seated cloth or continuous contact.

`tools/horses/validate_cart_speed.gd` measures actual displacement over 60 physics frames for ekka, goods cart and family carriage: approximately 10 m/s cruise and 15 m/s fast in all three cases, versus 4/7 m/s on foot. Each cart stops before a solid obstacle at fast speed and supports exit. Evidence: measured results (test output deleted); log `/tmp/tlm_cart_speed_2026-10-05.log`.

Paid travel remains an explicit destination purchase. The skip control becomes available only during a booked trip. It checks destination ground and body clearance, keeps the player seated in the arriving coach, completes the journey without a second fare, and rejects occupied arrival points without moving the coach. Existing cancellation/refund/resume behavior is retained; the latest paid-coach check also passes a full disk save/load without a second fare. `tools/horses/validate_paid_coach.gd` passes fare, duplicate booking, connected stop graph, normal arrival, blocked skip, clear skip, repeat-skip rejection, cancellation, saved paid-state resume and stalled-trip refund. Log: `/tmp/tlm_paid_coach_2026-10-05.log`.

## Infrastructure distribution and map

The existing functional grouping is retained: village homes/agriculture/stables west of the river; police and administrative offices east of the bridge; military barracks, services, church and cemetery around the parade district; civilian residences and service quarters on a separate avenue; port/warehouse downstream; Government House on its own approach; ruined fort on the hill. Road spurs share the surveyed layout used by terrain and movement. No buildings were relocated solely to add a marker.

`player/map_infrastructure.gd` collects actual live building/service nodes, village structures, residence groups and barracks. Port and shrine builders author geometry beneath origin roots, so their markers use their authored world centres. The field map combines these live entries with landscape regions. It removes obsolete reserve labels and the duplicate compound label. The facility picker sorts the list, centres/zooms to a chosen facility and sets its waypoint. Current population: 114 live infrastructure entries (including the added cart standings) across 12 surveyed district plots.

`tools/world/validate_field_map.gd` checks required facilities, marker/live coordinate agreement, world bounds, plot separation (allowing at most 4 m of survey-envelope overlap at adjacent edges), screen/world projection, pan/zoom/click, picker focus and input release. These are map and plot-envelope checks, not proof of every doorway, exact building collision separation or every possible travel route.

Evidence: map validation (test output deleted), selected facility (test output deleted), map zoom (test output deleted). Latest native Metal log: `/tmp/tlm_infrastructure_map_2026-10-05.log`. The selected facility and distance labels occupy separate lines; picker/legend/control spacing is visually checked. Missing locations in the 40-location ledger are not presented as built infrastructure.

## Integrated route verification and limits

Higher-speed full-world Government House → Police Station paid trip across the bridge PASS: 607.27 m displacement, 1.98 m final road-waypoint error, fare 5 → 3 rupees. Actual 60 Hz physics, headless; log `/tmp/tlm_fast_paid_bridge_2026-10-05.log`.

The first household regression caught the landowner coach colliding during its second departure turn. Its old parking position was 5 m off the courtyard centre, leaving insufficient arcade clearance for the returned orientation. Parking now uses the centre of the existing court at (-321, 344), aligned with its approach. Forward cruising remains 10 m/s. The corrected route checks PASS: landowner and merchant coaches each complete two round trips, and the British household completes one; all three have zero blocked coach/resident frames. Route results (test output deleted); log `/tmp/tlm_household_speed_2026-10-05.log`. The broader household validator reports `office seated garment missing`, retained as an unresolved clothing check rather than a movement pass. Whole-game performance and final horse/driver/cloth motion approval remain separate.


## Coordinated travel scope — 2026-10-05

The user clarified that the request is **cart**, not car. Arjun’s location travel uses the existing horse carts/carriages, paid coach booking, optional skip, standings, save state and map destinations. The earlier motor-car clarification is resolved.

Ownership: this travel work owns horse-vehicle speed and infrastructure map coverage. The [combat owner](../characters/arjun/combat_rescue_2026-10-05.md) owns mounted-police pursuit, faction/crime response and arrest behavior; changes to those systems must use the existing horse/mount contract rather than a second vehicle implementation. The [runtime owner](runtime_optimisation.md) owns stable-source CPU/render profiling and shared distance/LOD policy. This note is the shared ownership record; no other chat was messaged.

Measured cost context is retained from the runtime report: native diagnostic p50/p95 frame times were 87.610/113.035 ms at the village, 149.121/195.272 ms at Civil Lines and 128.001/168.240 ms at the cantonment, with 3,053–3,856 draws. These were whole-scene diagnostic samples with concurrent source changes and 5120×2880 backing pixels; they cannot be attributed to vehicles or presented as a causal optimisation gain. The rein component is now measured below; full vehicle animation/physics and whole-frame attribution remain open.

Next coordinated performance gate: profile the existing small fleet on a stable snapshot, separately measuring occupied/player-near and distant parked/household coaches. Reuse shared horse/vehicle meshes, materials and existing MPFB drivers. Distance culling/LOD should reduce distant visual animation, rein solving and draw cost while keeping an occupied coach, active paid trip, nearby interaction, moving collision and combat-relevant horse active. Keep household/police active populations bounded; do not introduce map-wide per-frame route searches or duplicate actors. Preserve paid skip/save/arrival semantics and rerun measured movement/bridge/obstacle checks after any scheduling change. The rein-detail budget below implements the first visual distance tier; broader simulation culling remains with the runtime owner.

All human assets remain under the [complete-body standard](../characters/npcs/whole_body_standard.md): MakeHuman/MPFB source, complete body beneath clothing, clothing masks disabled, separate opaque foundations for adults, and clothing fitted to the preserved physique. This task creates/exports no human assets and does not certify existing exports or cloth/contact realism.


## Rein detail performance — 2026-10-05

`vehicles/flexible_cart_reins.gd` now checks camera distance at 4 Hz. Unoccupied carts keep full rein detail within 80 m, update at 10 Hz from 80–180 m, and hide/skip rein mesh rebuilds beyond 180 m. An occupied cart always updates contact at full rate regardless of camera distance. With no camera, detail remains active. Returning near resumes the existing strips within the 0.25-second distance-check interval. This only budgets visual rein work; routes, speed, collision, save, crime and horse/driver simulation are not disabled.

`tools/horses/profile_cart_visuals.gd` runs 600 direct rein updates per cart/distance, using paired LOD-disabled and LOD-enabled samples in the same process. [Original baseline](cart_visual_profile_baseline.json); [paired results](cart_visual_profile_after.json). At 120 m, mean CPU cost drops from 91.6–111.2 µs to 18.9–22.1 µs (about 79–82%); at 260 m it drops from 98.4–106.8 µs to 0.34–0.46 µs (over 99%). Near medians stay 79–81 µs. Timings are component CPU measurements, not frame-time/FPS or whole-world optimisation evidence.

Assertions pass for all three variants: 600 near updates, 100 medium-distance updates, zero far rebuilds, near visibility recovery, and full-rate occupied updates at 260 m with both rein endpoints pinned. Existing shared horse/driver assets are retained; no human mesh or clothing/foundation topology is edited. Logs: `/tmp/tlm_cart_visual_baseline.log`, `/tmp/tlm_cart_visual_after.log`. Native contact runner: `tools/horses/capture_cart_rein_grip.gd`, `/tmp/tlm_cart_rein_lod_metal.log`. The capture runner explicitly selects its review camera. All four native grip/sag checks PASS with zero rein endpoint residual; the refreshed turning view (test output deleted) was inspected and shows the driver and reins clearly. A separate `climb_opportunities.gd` Vector3 inference error was corrected to unblock the rerun. Numerical contact and this still do not approve human/cloth appearance or continuous motion.

Remaining performance ownership stays with the runtime task: horse/driver AnimationTree cost, larger-fleet bounds and stable-source full-world render profiling. Mounted-police behavior stays with the combat owner.

## Steering follow-up — 2026-10-08

The current manual controller filters steering input and yaw acceleration, reduces turn limits at speed, and reverses steering when backing. Three live-cart fixture variants pass sustained left/right input, steering reversal, release, full stop, obstacle stop and 10/15 m/s speed checks. Reusable check: `Godot --headless --fixed-fps 60 --path . --script tools/horses/validate_cart_speed.gd`. This is a behavior check, not continuous visual approval. The test no longer writes a report into the checkout.

Gradual paid-route braking failed the isolated route check (stall/refund around 50 m), so that change was withdrawn; paid coaches retain immediate stop-before-alignment safety. Isolated bridge mode lacks the complete bridge/world terrain and cannot certify the bridge route. Full-world paid-route and normal-speed horse/rider/rein/cloth review remain open. Test outputs are temporary and deleted; no retained captures or historical report links establish current approval.

In-game check: board each cart as driver, hold forward, engage sprint, steer continuously left then right, release steering, release forward to stop, and repeat backing slowly. Check that reins remain in the hands and the rider/horse follow the cart without a heading jump. Book a coach, ride through corners, then repeat using the skip button and confirm arrival with one fare. Open Escape → map and select the named infrastructure sites.

Bridge widening/lanes and current checks: [two-carriage crossing](two_lane_timber_bridge.md).
