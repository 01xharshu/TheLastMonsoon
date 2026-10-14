# Resident work and physical consignments

Updated 2026-10-13. Integration remains in progress. Five independent goods workers and four guards are attached to real startup-owned workplaces. Complete MakeHuman bodies and separate opaque foundations remain in their editable sources and runtime exports. Numerical contact checks do not grant garment, ordinary-play or whole-world performance approval.

## Implemented routine

Hospital linen, commissariat stores, customs freight, market stock and merchant-household supplies use independent workers, schedules, carts, shelves and saved job identities. The household worker is a female servant assigned to the covered rear service bay; the household owner is not assigned this labour. Hospital and depot guards retain their separate duties.

Each worker takes three solid crates from the bullock cart, carries them along an authored route through the actual workplace, places them on a solid shelf and returns. A private AnimationTree work branch supplies gradual lifting/lowering and palm contact. The complete capsule checks support and sweeps against people, carts, furniture and boundary posts. Tall support obstructions enter the same bounded detour queue as other obstacles. Port and market routes skirt their carts and shelves. The depot worker starts behind the freight bay, avoiding a path through its wheels.

After unloading, the worker visibly lifts three wrapped parcels from the stored crates and places them on a solid issue table. Hospital/depot receipts credit actual dressings, ration and fodder stock once per shipment and crate. Their stock no longer resets merely because the day changes. Actual treatment/ration consumption updates the visible issued parcels. Civil hospital services without a supply worker retain their existing stock behavior.

The empty cart reverses clear of the workplace and travels to its supplier bay. Authored lateral distances are hospital53m, depot33m, port24m, market24m and household24m, followed by real turning and final receiving approaches. At the next workday, the worker loads three goods from a solid supplier bench using low solid steps. The worker clears the vehicle, the loaded ox team turns and returns, and unloading resumes after parking. No cart position teleport or obstacle removal is used. Supplier production onto the loading bench remains abstract; this is a visible local supplier journey, not a complete regional production economy.

Cart translations now sweep the whole clearance volume as well as checking endpoint occupancy. A thin intervening obstacle regression verifies that an empty endpoint does not permit crossing it. All five focused cycles also pass with that sweep enabled.

All crates and parcels remain solid while stowed, carried or stored. Vehicle clearance excludes only its own cargo, and the worker excludes its own manipulated goods from movement/planning queries. Other bodies retain contact with those props. Consumed parcels are removed from visible stock and collision because they have been used.

Work runs 07:00–18:00. After-hours retains carried goods. Saves include worker facing, parcel lift/turn/place progress, loading goods, shipment identity and the actual moving cart position. Institution-anchor rebasing supports relocated service bays; old cart origins migrate to the current bay. Receipt identity prevents duplicate credit after Continue.

Nearby work runs at full rate. Remote simulation accumulates elapsed time and retains up to five swept state steps; only the final step evaluates the pose/contact, using the total elapsed pose time. Collision and saved job identity remain active. A focused headless CPU comparison sampled30 updates per mode: median474us reference versus154us batched,150 versus30 pose evaluations, and under1mm palm error with equal stopping positions and no overlap with the test obstacle. These are subsystem diagnostics, not native frame-budget acceptance.

## Current evidence and open defects

Earlier real New Journey→save→Continue checks passed the nine configured institution residents, carried hospital/depot goods, all three added workplaces’ first delivery and a paid18-rupee consignment ending without duplicate payment. The story restore readiness defect was subsequently corrected by its owner. Latest expanded daily-cycle checks must be assessed separately after route and world changes.

The actual boundary was added to the focused cantonment fixture after the full world exposed a depot cart obstruction. The receiving bay now sits clear of that post. Depot supplier loading uses a clear gap and its turn extends5m away from the boundary before returning. All five focused workplace cycles pass unloading/issuing/source loading/return and issuing/loading/arrival saves. Hospital receiving/supplier palm maxima7.91/16.00mm; depot9.79/14.48mm; market6.53/13.58mm; port12.54/14.84mm; household22.77/12.61mm. Port shelves and routes are inside the open cargo-door leaf and approach around the shelf end. The household supplier uses the east yard, avoiding its solid main house. The populated main rerun remains separate and in progress. Earlier runs hit concurrent Dev-story parser and forest expansion errors; those failed runs are not integration evidence. The later actual hospital next-day cycle and once-only parking-bay payment pass; the all-five rerun remains in progress.

Shared queued navigation now supports caller-owned cargo exclusions and cancels searches when its world leaves the scene tree. The strengthened architecture navigation regression passes8 checks, including world teardown during a pending search. An initially requested separate lifecycle filename did not exist; it was replaced with that actual reusable teardown check.

All four female street variants now use a connected cotton blouse/wrap surface and a separate fitted shoulder tail, with retained original garments in the editable source. Hair identities retain long braid, short braid, rear bun and side braid. Male workwear retains four sleeve lengths, palettes and turbans. The eight imported male/female identities also pass all 24 player approaches: the player stops against their solid bodies and the NPC detects the player. A first headless attempt requested render images and timed out; the physics-only repeat passed and all temporary output was removed.

Source audits sampled eleven arm/leg, working-lean and bent-elbow carrying poses per female, about40,392–40,436 probes each, with zero body penetration. The native review caught shoulder-tail overlap with the blouse despite that source result; the tail has been refitted over the garment and a fresh corrected render plus all eleven-pose source audits pass. Visual approval remains false.

The female household worker also completed two deliveries during 75 s of ordinary-speed native Metal playback, with maximum palm error 21.78 mm and no diagnostics. The sampled backing was 3600 × 2260 at0.477876 render scale (about 1720 × 1080 actual 3D); p50/p95 frame intervals 7.152/9.549 ms with a concurrent main-world headless run. The corrected shoulder tail and lower waist seam were inspected; first lifting camera occlusion was corrected and the fresh rear/side sample reviewed. This is a scoped workplace measurement and does not certify the populated world or final cloth/finger presentation.

Whole-world FPS remains failed in the traffic owner’s current native measurements. This batch does not certify the8GB target. Ordinary-speed full cycles, moving clothing/fingers, passenger/cart contact and final character art remain open.

## Reusable checks and player review

Use temporary logs and saves; remove generated media after inspection. Reusable tests and editable assets remain.

```sh
# Run with --log-file pointing inside an OS temporary directory.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_resident_goods_run.gd -- --restock
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_resident_goods_run.gd -- --restock --depot --pose-budget
python3 tools/world/check_resident_integration.py --full-jobs --only-job CustomsReceivingPorter
```

Visit the military hospital, commissariat, customs warehouse, city trading market and merchant household between 07:00 and 18:00. Follow a worker from the cart to the interior shelf and issue table. Watch the empty cart leave, then next day’s loading and arrival. Save while the worker carries or issues goods, and while the cart is returning; Continue should retain the same physical progress. Stand in a route to confirm blocking, then move clear and observe recovery. For paid cart consignments, the shared errand owner currently completes the job once the whole stopped cart is inside the marked bay and pays once. The old receiver/thanks sequence is historical; the independent NPC goods cycle above remains physical. The main validator now checks that current parking-bay ledger contract rather than attempting an already-completed handover.
