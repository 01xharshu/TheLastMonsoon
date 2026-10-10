# Resident work and physical consignments

Updated 2026-10-10. Integrated behavior baseline; final clothing, moving contact and whole-world performance approval remain open.

The military hospital's existing Indian linen porter now takes three actual crates from a parked bullock cart, carries them through the entrance, places them on a solid ward shelf and returns to the cart. This reuses the complete MakeHuman worker and the existing bullock-cart/draft-animal system. It creates no primitive human or substitute body. The cart, worker, building and stored goods retain physical collision.

The worker has a private AnimationTree work branch, a gradual lifting/lowering lean, palm targets and finger grip. Physical movement checks the complete capsule against support and solid obstacles. A sustained blockage triggers local route planning around people and furniture; the porter does not pass through them. Work runs from 07:00 to 18:00. After-hours pauses retain the actual carried load. The existing institution save hooks preserve identity, phase, consignment count, carried goods and position through Continue.

This is a finite daily hospital provisioning routine. The next day's stock reset currently places the three supplies back on the parked cart. A visible incoming supply cart and restocking sequence remain unfinished. Other workers and workplaces retain their existing assigned routines; this batch does not certify all requested occupations or all interior deliveries.

Nearby work runs at full rate. Remote work uses the shared simulation budget and accumulated elapsed time; world references are cached during setup. Collision remains present at every distance. Guards retain their animation processing and use the shared budget for head-watch updates.

Village residents' journeys home now use capsule occupancy between route points as well as swept checks. This prevents a route-planning edge from skipping narrow veranda posts. The current real-physics commute check passes for all 14 assigned village residents.

## Verification and remaining review

Reusable checks:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_resident_goods_run.gd
python3 tools/world/check_resident_integration.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_village_daily_activities.gd -- --commute
```

The focused hospital check exercises all three physical transfers, obstacle pause/resume, after-hours retention, mid-carry JSON restore, persistent solid stored goods and hand-target errors. The completed baseline passed with maximum palm-target error 8.46 mm with the receiving orderly present and the revised grip. The native hospital fixture also completed its transfers, but full moving clothing and finger presentation still need approval. Its latest native palm-target error was 8.15 mm. Numerical hand targets do not certify fingers or clothing fit.

A native fixture diagnostic at a 3600 × 2260 backing texture and 0.477876 render scale (approximately 1720 × 1080 actual 3D) sampled 180 ordinary frames: median 18.888 ms, p95 19.105 ms. Concurrent headless tests and a Blender rebuild were running. This is a scoped diagnostic, not isolated whole-game FPS approval.

The New Journey → save → Continue test uses the real population owners and temporary save files. It now derives expected counts from the configured population rather than obsolete fixed totals. The updated paid ending passed through New Journey → save → Continue: the receiver physically collected the saved goods, returned, thanked the player and paid 18 rupees once. Movement and navigation now use consistent boarding-handle exclusions, capsule margin and height. The receiver check accelerates its elapsed time while retaining actual physics steps; it does not certify ordinary-speed acting. The strengthened real-game run also passed: a mid-carry hospital save restored the actual carried crate through Continue, and the porter delivered it past the real receiving orderly. The configured 188 civilians, 20 police and 16 traffic carts restored through the population owner.

For player review, enter Suryagarh and visit the military hospital during working hours. Watch the existing linen porter behind the parked cart, follow him through the entrance and inspect the ward shelf. Stand in the route to check solid body contact. Save while he carries a crate and Continue; inspect the same load and work progress. For paid warehouse consignments, use the marked goods-cart bays and verify collection, unloading, thanks and a single payment.

All generated review media and logs are temporary and removed after inspection. Editable assets and reusable checks are retained.

The porter review exposed an unwanted foundation layer on the hands. The donor foundation used height-only selection, which included lowered rest-pose hands. The street builder now excludes arm/hand/finger garment faces; all four formal male and four workman variants were rebuilt with the complete 13380-vertex MPFB bodies intact. Fresh native hand appearance review remains required.
