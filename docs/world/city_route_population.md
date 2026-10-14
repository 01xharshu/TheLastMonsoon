# City route population

IN_PROGRESS / 2026-10-08 23:03 IST / root. User reports sparse pedestrians, police and carts on city routes. Add populated routes using existing MPFB actors, live police observer/pursuit/custody AI and real boardable vehicles. Preserve previous clothing task and concurrent world/vehicle changes. Implementation and world verification next; no density/performance/art approval yet.

Implemented additive manager:72 pedestrians across9 existing surveyed route areas,10 additional officers registered with existing CombatEncounters patrol/witness/pursuit/custody logic,8 boardable ox carts/family carriages on long road sections. Walkers phase-spaced in opposing directions on road edges; setup staggered .06s, distant cadence .5s and mesh range190m. Cart clearance/grounding/player takeover retained plus rear-spacing stop. New files city_route_population.gd, city_street_journey.gd, city_cart_journey.gd; one additive install line in existing dirty world script. Parser checks PASS; actual full-world16s movement validation running.


## Movement repair — 2026-10-10

Terrain support now follows the actual ground on each pedestrian step; collision sweeps retain buildings, trees, vehicles and people. Bounded, swept lateral detours let walkers pass obstructions on surveyed roads. City carts choose a clear parallel lane at placement, resolving the Government House wall overlap; movement still uses normal clearance, terrain checks, traffic spacing and player takeover.

A disposable clean-import, actual-world headless check passed: 72/72 walkers across all nine route areas, 8/8 carts and 9/10 police patrols made progress over 16 simulated seconds. No blocked walkers or stopped carts were reported. The validator now requires every added walker and cart to progress. An earlier run under concurrent import/render load timed out while spawning; the sequential repeat passed. This is functional movement evidence, not approval of FPS, clothing, contact or long-term U-turn behavior.

Repeat with `python3 tools/world/run_city_population.py`; add `--native` for normal native timing. Test snapshots, logs and user data are automatically deleted. In-game: finish or skip the opening, then observe both directions on the village market road, Government House road and administrative approach; board a free seat and verify traffic yields to player use.

Native Metal actual-world repeat also PASS (177.1 wall seconds, exit 0, no Godot diagnostics): 72/72 walkers, 8/8 carts and 9/10 police, with zero blocked walkers/stopped carts. Transient review showed the Government House cart clear of the boundary wall. Unrelated household `leave_home` journeys logged EntranceDoor blocks for OfficialMan, OfficialWoman and MerchantHouseholdMerchant; handed to the existing household owner, and not counted as repaired by this traffic pass. Final FPS/contact/long-route review remains open.

## Current expansion and verification — 2026-10-12 IST

IN_PROGRESS. Current population defines **188 pedestrians across 12 routes, 20 additional foot police and 16 additional carts**. Civilian identities persist as logical records until within 400 m; actors remain persistent after instantiation. Shared simulation budgets, amortised spawning, collision sweeps, full retained MPFB bodies, original police witness/custody logic and boardable vehicle takeover remain integrated.

Current repairs: terrain-only city-cart and added-police support rays; raised estate lawn registered as support; pedestrians follow wider road-edge lanes and checked passing detours; carts prefer separate parallel lanes and clear grade alignment. Existing queued police navigation now also handles added city patrol duty. `city_contact_recovery.gd` resolves existing contacts through the physics server with bounded correction and supported, fully clear destination checks; police recovery skips pursuit/custody. Its collision-only regression, including generic RID exclusions and rejection of unsupported movement, passes.

Latest exhaustive clean-world result: import PASS59.8s, movement PASS94.8s; **188/188 pedestrians,18/20 police and16/16 carts progressed** in the unchanged30 simulated-second sample across all12 routes. No blocked pedestrians/stopped carts or script diagnostics. Patrol movement exceeds the80% threshold. Unsafe terrain steps now request detour recovery; substantial clear escape candidates avoid tiny sidestep oscillation. Cart passing retains swept pivot/path checks and bounded2.5m supported reverse travel. Native four-region measurement was stopped after Metal fence timeouts at `vehicles/coachman_seated_cloth.gd:31` garment mesh readback, while unrelated Blender/Godot checks ran. No fresh native/performance acceptance; temporary output/project/test saves cleaned. Repeat when those workloads finish; a recurring fence error requires renderer/readback diagnosis before timing acceptance. This movement pass does not establish sustained route completion, clothing deformation/contact or FPS approval.

Native Metal samples before the latest contact/navigation repairs, Medium, actual 1280×720, 120 measured frames per region:

| Region | Median frame ms | 95th percentile ms | Instantiated pedestrians |
| --- | ---: | ---: | ---: |
| Village | 207.958 | 274.355 | 76 |
| City market | 160.403 | 177.418 | 132 |
| Civil lines | 108.150 | 157.372 | 188 |
| Bazaar | 139.577 | 161.650 | 188 |

Performance FAIL; no smooth-FPS approval. GPU timer returned zero and is unavailable as evidence. These are whole-world samples, not attribution of cost solely to city traffic. Clothing appearance/deformation, cart contact/turns and full play remain open.

Repeat `python3 tools/world/run_city_population.py --city-budget`: disposable clean import, exhaustive 30 simulated-second movement, then native four-region timing only if movement passes. The native stage uses normal nearby spawning and wall-clock frames, without a fixed-FPS override. `--diagnose-import` adds verbose asset context for import failures. Logs, snapshots and test user data delete automatically. Reusable tests: `validate_city_route_population.gd`, `validate_city_population_budget.gd`, `validate_city_contact_recovery.gd`.

## Imported driver input readback — 2026-10-12

IN_PROGRESS. `vehicles/coachman_mesh_inputs.gd` retains immutable imported source surface arrays in the owning world, keyed by mesh instance/surface. Returned packed arrays are explicitly duplicated; generated meshes remain uncached. Coachman garment setup, exact body/pose signature and retained-body fitting use it. Isolated copy/mutation, resource identity, world lifetime scope and generated-refresh regression PASS. A shallow-copy failure was caught and repaired before integration approval. Existing source/geometry/native parity is extended to assert repeated signatures perform no further imported readback. Run `python3 tools/world/run_city_population.py --driver-inputs --import-timeout 600`; fresh import plus isolated input, coach/bullock headless and native parity. Earlier import retry timed out240s, later interruption yielded no parity result. No native/fence/FPS acceptance yet. Later shared city audit15/16 cart progress is retained alongside owner16/16 result; consistent movement still needs verification.

Driver gate completed: fresh import75.4s; isolated source cache PASS; coach/bullock headless PASS12.0s/5.5s and native Metal PASS13.6s/6.7s. Exact body/garment/pose signatures, zero fitted vertex difference,8 retained skinned meshes per driver, stale/changed-pose cache rejection and dynamic runtime cache restore PASS. Both native cached/rebuilt images are byte-identical, with stable repeated frames and zero difference metrics; no fence/script diagnostics. The parity fixture now waits for deferred runtime creation and synchronizes one carriage scene/exact bone values, avoiding independent draft-rig and quaternion-round-trip differences; pose-review keeps its original scene comparison. This completes focused driver input parity, not full-world rendering, motion contact or FPS acceptance. Next full-city repeat uses `python3 tools/world/run_city_population.py --city-budget --import-timeout 600`.

## Movement and native continuation — 2026-10-12 22:03 IST

Current functional baseline PASS. Genuine failures repaired: clear cart yaw movement no longer triggers passing replans during U-turns; police-compound lane avoids the mounted patrol; walkers finish supported horizontal waypoints despite cached floor-height differences; shorter fully swept detour legs handle gradients. Reverse legs now finish within5mm instead of trapping on sub-ULP residuals at large world coordinates. Collision/support checks remain; no teleport or phantom distance is credited. `validate_city_cart_retreat.gd` reproduces the actual5.9e-6m unrepresentable remainder and verifies unchanged position, zero credited travel and released motion/state.

Latest fresh `--city-budget --import-timeout 600`: import PASS55.8s, reverse fixture PASS0.5s, movement PASS64.3s:188/188 walkers,18/20 police,16/16 carts on12 routes, no blocked/stopped actors. Native Metal four-region run completed204.5s with no script/render/fence diagnostics. Actual1280x720 Medium,120 frames per region:

| Region | Median ms | p95 ms | Instantiated walkers |
| --- | ---: | ---: | ---: |
| Village |189.660|208.032|76|
| City market |152.458|224.428|132|
| Civil lines |93.087|163.932|188|
| Bazaar |149.185|224.028|188|

Frame budget FAIL against33.3ms for30FPS. GPU timer0 is unavailable and these measurements do not attribute global cost to traffic. No generated output remains. Keep earlier intermittent15/16 and14/16 failures as history; this repaired snapshot passes the current30-second sample. Sustained loops/boarding/contact, garment action review and performance remain OPEN; preserve their existing owners and the deferred FPS scope.
