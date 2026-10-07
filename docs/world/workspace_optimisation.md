# Workspace, opening hours and cart standing

Updated 2026-10-05 IST. Parking and rendering-work reduction implemented; whole-game smoothness remains unverified.

## Storage and documentation

Earlier duplicate-evidence cleanup is historical. The user’s 2026-10-07 policy now requires deleting disposable test output after each run; `tools/maintenance/clean_test_artifacts.py` supersedes the retired duplicate-only cleanup tool. Useful editable sources and rebuild inputs remain protected. See `../assets/repository_storage.md`.


## Parking and return

`vehicles/cart_parking_bay.gd` supplies six terrain-following dirt standings: three public carts and three reserved household coaches. Each records a fixed map location, one-cart capacity, 6 × 12 m standing footprint, occupancy and docked state. Occupancy refreshes at 2 Hz using polygon overlaps of actual cart collision footprints, with a foreign vehicle taking precedence over the owner. Public, household and borrowed cart types register automatically. This remains one standing per assigned cart, not a general multi-slot allocator. Docking requires the owning cart within 0.6 m and 0.15 rad, then checks actual vehicle clearance before final placement and collider synchronization. Surface construction probes the physical ground and keeps a single mesh with no added invisible road collider.

Public coach destination menu includes **Return to cart standing · 2 rupees**, following the existing connected road graph, braking before rotation, slowing on final approach and aligning to its original heading. It does not offer a teleport skip for parking. Obstruction/stall retains the existing refund behavior. Return destinations persist through the existing paid-trip save mechanism. Household coaches remain reserved; existing household journeys already return home. No new humans or human source changes were made here; complete body topology and foundation garments must remain intact during later optimization.

All current 18 map/menu icon families remain filled, including the seven newly added clinic/church/stable/jail/civic/treasury/cemetery categories. Parking markers read actual standing nodes rather than moving cart coordinates. Doors retain configurable default 06:00–20:00 entrance hours, overnight ranges and all-day equal-hour behavior; office services remain 09:00–17:00 prototype rules.

## Runtime changes

Hinged door boards, braces, fittings and rings are combined into one mesh per leaf with separate timber/iron surfaces. Hinge pivots, collider leaves, swept actor protection and pull markers remain. Original board coordinates are retained in UV2 for the timber shader so grain does not change to hinge coordinates. A representative door retains 4,656 triangle vertices and identical bounds, reducing 48 mesh nodes to two. Player latch uses the retained `IronPullRing` and `InteriorPullRing` markers.

The existing village batching step now also accepts eligible static imported furniture with real source materials, retaining scripted/skinned objects and custom shadow settings. General settlement batching also excludes scripted/skinned actors. Household seated cloth caches garment mesh references and only changes visibility when the seated state changes; pelvis-following updates remain continuous. Human meshes, body topology and source rigs are preserved.

Populated geometry audit: 18,200 → 12,454 geometry nodes (31.6% reduction); representative `BhairavpurHouse9` 249 → 20. Reports: `runtime_geometry_before_house_batch.json`, `runtime_geometry_audit.json`. This snapshot predates concurrent complete-body export changes and is a measured workload reduction, not a stable full-world FPS comparison.

## Verification and remaining gates

- `tools/world/validate_door_batch.gd`: geometry, dimensions, hinge/collision and pull markers PASS; native small fixture completed after UV2 preservation. Final fixed-resolution 960 × 720 native before/after images are pixel-identical (zero changed pixels); `door_batch_validation.json` and `captures/door_batch_current.png`. Only the latest batched view is kept in the workspace.
- `tools/world/validate_cart_parking.gd`: isolated physical docking, occupancy, foreign vehicle/obstacle rejection and paid return PASS (`cart_parking_validation.json`). Clean full-world accelerated return PASS: 1,071 60 Hz simulation steps, original standing position/heading, one fare and all six clear standing positions (`cart_parking_live_validation.json`; `/tmp/tlm_cart_return_live.log`). This is accelerated behavioral validation, not a normal-speed player review.
- House access/shutter/inside-egress/night lock, staff latch/cloth/contact and administrative transactions/save/strongroom regressions passed after pull-marker correction. Staff latch rerun with body/foundation checks passed after shader updates; final full-world access rerun passed too. Existing full-world cleanup warnings remain (two objects/one resource); paid-coach regression also emitted existing Arjun basis/grip errors despite its behavioral PASS. These are not clean production runs.
- Native full-world `capture_parking_and_batch.gd` produced standing, village and selected parking-map views, overwriting those same paths. Standing winding, ground texture/feathered edges and village camera placement were corrected after inspection. Final native full-world capture rerun completed without script/renderer errors, and the map shows filled icons and the real selected parking location. These still views do not establish normal-speed gameplay or final art approval.
- The final populated `profile_runtime.gd -- --door-batch` run completed after Metal fence timeouts. Diagnostic village draws fell from 6,764 to 3,053; Civil Lines from 5,548 to 3,866; cantonment from 4,519 to 3,976. These counts also span concurrent asset changes. Final wall-frame medians 51.3/58.2/10.0 ms and CPU timings are inconsistent under contention, so no controlled whole-game speedup or smoothness claim is supported. `runtime_profile_door_batch.json` preserves the diagnostic report. Profiling now records CPU process/physics time alongside draws. Next: uncontended native profile and normal-speed parking/night routes on target hardware, then actor/render budgets with complete human bodies retained.

One integration repair restored church `PewEnd` coordinates to the local pew-loop x/z variables after a concurrent fodder variable replacement caused full-world parse failures. Other concurrent edits were retained.
