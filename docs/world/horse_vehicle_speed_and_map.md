# Horse vehicle speed and infrastructure map

Updated 2026-10-05 IST. Scope: make horse-drawn vehicles clearly faster than walking/running, retain optional skippable paid coach travel, and make existing infrastructure inspectable on the field map. Existing MakeHuman drivers are reused; this task creates no humans.

## Movement

All three playable horse-drawn bodies use `vehicles/cart_rider.gd`: 10 m/s forward cruise, 15 m/s fast travel, 5 m/s² acceleration and a controlled 3.4 m/s reverse. Arjun walks at 4 m/s and runs at 7 m/s. Paid coaches target fast travel with 0.75 throttle on aligned roads (11.25 m/s), slowing/stopping to align at bends. Household coaches now use the shared 10 m/s cruising speed and animate from actual distance travelled. Slow backing, alignment, boarding and obstacle stops remain intentional.

Single-horse and paired-horse vehicles select the imported gallop above 6 m/s. Wheels still turn from distance/radius, and hoof playback follows the active animation. This is a gameplay speed change, not final approval of horse stride, harness tension, seated cloth or continuous contact.

`tools/horses/validate_cart_speed.gd` measures actual displacement over 60 physics frames for ekka, goods cart and family carriage: approximately 10 m/s cruise and 15 m/s fast in all three cases, versus 4/7 m/s on foot. Each cart stops before a solid obstacle at fast speed and supports exit. Evidence: [measured results](horse_vehicle_speed_validation.json); log `/tmp/tlm_cart_speed_2026-10-05.log`.

Paid travel remains an explicit destination purchase. The skip control becomes available only during a booked trip. It checks destination ground and body clearance, keeps the player seated in the arriving coach, completes the journey without a second fare, and rejects occupied arrival points without moving the coach. Existing cancellation/refund/resume behavior is retained. `tools/horses/validate_paid_coach.gd` passes fare, duplicate booking, connected stop graph, normal arrival, blocked skip, clear skip, repeat-skip rejection, cancellation, saved paid-state resume and stalled-trip refund. Log: `/tmp/tlm_paid_coach_2026-10-05.log`.

## Infrastructure distribution and map

The existing functional grouping is retained: village homes/agriculture/stables west of the river; police and administrative offices east of the bridge; military barracks, services, church and cemetery around the parade district; civilian residences and service quarters on a separate avenue; port/warehouse downstream; Government House on its own approach; ruined fort on the hill. Road spurs share the surveyed layout used by terrain and movement. No buildings were relocated solely to add a marker.

`player/map_infrastructure.gd` collects actual live building/service nodes, village structures, residence groups and barracks. Port and shrine builders author geometry beneath origin roots, so their markers use their authored world centres. The field map combines these live entries with landscape regions. It removes obsolete reserve labels and the duplicate compound label. The facility picker sorts the list, centres/zooms to a chosen facility and sets its waypoint. Current population: 108 live infrastructure entries across 12 surveyed district plots.

`tools/world/validate_field_map.gd` checks required facilities, marker/live coordinate agreement, world bounds, plot separation (allowing at most 4 m of survey-envelope overlap at adjacent edges), screen/world projection, pan/zoom/click, picker focus and input release. These are map and plot-envelope checks, not proof of every doorway, exact building collision separation or every possible travel route.

Evidence: [map validation](infrastructure_map_validation.json), [selected facility](captures/infrastructure_map_selected.png), [map zoom](captures/10_map_zoom.png). Latest native Metal log: `/tmp/tlm_infrastructure_map_2026-10-05.log`. The selected facility and distance labels occupy separate lines; picker/legend/control spacing is visually checked. Missing locations in the 40-location ledger are not presented as built infrastructure.

## Remaining verification

Higher-speed full-world Government House → Police Station paid trip across the bridge PASS: 607.27 m displacement, 1.98 m final road-waypoint error, fare 5 → 3 rupees. Actual 60 Hz physics, headless; log `/tmp/tlm_fast_paid_bridge_2026-10-05.log`.

The first household regression caught the landowner coach colliding during its second departure turn. Its old parking position was 5 m off the courtyard centre, leaving insufficient arcade clearance for the returned orientation. Parking now uses the centre of the existing court at (-321, 344), aligned with its approach. Forward cruising remains 10 m/s. Household round-trip regression is rerunning; record its final result before calling all three household routes verified. Whole-game performance and final horse/driver/cloth motion approval remain separate.
