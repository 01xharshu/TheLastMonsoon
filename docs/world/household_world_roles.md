# Household roles in Suryagarh

Updated 2026-10-10. Integrated gameplay roles for the existing four residents and nine staff. Fictional quotes and fees below are balancing values, not historical price claims.

| NPC | World responsibility | Player action and consequence |
| --- | --- | --- |
| Landowner | Estate fields and rent-office accounts | Check three nearby cultivated boundaries using the normal held interaction, return for 5 rupees; one paid survey per game day. Map guidance tracks unchecked fields and then the resident. |
| Wealthy merchant | Produce purchasing and counting-house business | Sell one mango for 2 rupees, up to three per day while storage has room. Public shipping/cloth jobs remain with the existing dispatch clerk. |
| British official | This estate's accounts | Show an existing district revenue receipt; retain it, record acknowledgement and receive a one-time 2-rupee reimbursement. The NPC does not issue district clearances. |
| British household host | Household provisioning | Deliver two roti for 4 rupees and the existing help reputation award once per day; food enters the British household pantry. |
| Three cooks | Household meals | Buy stored roti for 2 rupees or supply roti using the secondary interaction. Pantry stock is shared with household deliveries; empty stock stops the cooking overlay until replenished. |
| Three water bearers | Household water supply | Fill a water bag in half-litre portions, bounded by bag capacity and two litres per household per day. Service points sit outside the kitchen walls. |
| Three coachmen | Reserved family transport | Explain the home–office route and direct public travellers to public cart stands. Family coaches remain reserved. |

## Integration and persistence

- Interactions are attached to the existing MPFB actors; no additional human placeholders are created. They follow the residents to home/office and are unavailable during walking, boarding, combat, unconsciousness or death.
- Interaction colliders use a ray-only layer, so conversation and field markers do not block people or coaches. Disabled services release their ray collider; death disables the conversation collider immediately.
- The household ledger owns pantry stock, orders, water allowance, paperwork acknowledgement and field progress. Daily consumption updates stock; daily limits follow `GameTimeSystem`.
- `SaveManager` stores this ledger alongside the existing inventory/fame state. Field indices are normalized after JSON loading, and survey waypoint ownership survives saving. The marker tracker caches world-scoped guidance references and preserves opening/tutorial guidance, followed story guidance, public errands and manually selected map destinations. Pending surveys resume when that guidance clears.
- If the landowner dies, the pending survey stops without a reward. Completed field checks and paid-day guards prevent duplicate payment.
- Resident journeys request their own entrance doors, wait for the swept opening and keep the door open while crossing. Inside egress remains possible; an explicit manual lock prevents re-entry. Coach clearance excludes its own coupling controls while retaining world collision.
- Private journeys use `systems/simulation_budget.gd`: full rate within 80 m of either coach or resident, 10 Hz through 200 m, and 2 Hz farther away. Remote elapsed time is consumed in at most five 0.1-second steps; approaching a resident restores full rate immediately. The cached viewer is the player, so cinematic camera switches do not leave nearby routines on distant updates. Translation clearance uses a swept shape followed by the destination overlap check. State, service ledger and collision remain active.
- Baked `waist_profiles.tres` supplies garment seam anchors without reading GPU body arrays during startup. Its reusable Blender builder is `tools/characters/build_household_waist_profiles.py`.

## Checks and remaining limits

Shared scheduler checks passed for near/middle/far cadence, retained elapsed time, immediate resident wake and bounded slices, including a thin obstacle between clear endpoints. Guidance checks passed for manual destinations and onboarding priority. Focused service checks passed: limits, pantry transfers, receipt prerequisites, water capacity, field range/replay, JSON state, day rollover and death/travel guards. The placed-world check passed normal interaction selection for all 13 services, field progress, a merchant trade and real save/load in an automatically deleted OS temporary folder. A native Metal run with unrelated HUD drawing hidden passed the same integration check. A later 180-frame native world sample at the estate measured 37.4 ms median and 49.5 ms p95 at the current game render scale (0.478); another headless cycle check was running concurrently, so this is a diagnostic sample, not an isolated benchmark. That run also emitted a Metal fence timeout before passing the service checks. An earlier run with the HUD visible emitted Metal fence timeouts in HUD drawing; that is not a clean whole-game rendering/performance approval.

The complete household cycle check passed after door access and self-collider fixes. Boarding ankle targets passed on the actual resident rigs with sub-millimetre error; office ankle targets were within 0.04 mm. These are joint targets, not sole/cloth/finger mesh-contact approval.

The merchant/landowner shawls retain distinct inner/outer layers fitted to the shirts, with interpolated weights. Moving surface checks covered 4,416 samples: maximum shirt/cloth gap about 10.7 mm; the lowest sampled signed clearance was approximately −0.045 mm. Bodies and opaque foundations stayed intact. Final fabric folds, performance acting, handovers, historical tailoring and continuous player-camera review remain open.

## Try it in game

1. Visit the landowner at home (−321, 7.2, 344) or the estate office (−309, 7.2, 315). Ask about work, follow the field marker, hold the check interaction at each boundary, then return for payment.
2. Bring mangoes to the merchant at home (−420, 8.0, −405) or the counting house (−366, 8.0, −328), during 09:00–17:00. Confirm the order closes after three purchases.
3. At the British home (−455, 8.5, −184) or office (−463, 8.52, −124), show the official a Treasury revenue receipt; supply the host with two roti. Speak to the cook afterwards to see the pantry stock used.
4. Use the cooks' secondary supply action and the water bearers' bag-filling action. Check that missing items, full bags and daily limits are explained without losing inventory.
5. Save, continue and confirm that paid work, acknowledged paperwork, pantry stock and checked boundaries remain recorded. Busy residents hide their service prompt; wait for them or meet them at their destination.

Reusable checks print results and retain no reports:

- `Godot --headless --path . --script tools/world/validate_household_roles.gd`
- `python3 tools/world/run_household_world_check.py`
- `python3 tools/world/run_household_world_check.py --native --hide-ui --profile-budget`
- `Godot --headless --path . --script tools/world/validate_household_budget.gd`
- `Godot --headless --fixed-fps 60 --path . --script tools/world/validate_wealthy_households.gd`
- `Godot --headless --path . --script tools/world/validate_household_step_feet.gd`
- `Godot --headless --path . --script tools/world/validate_household_shawl_fit.gd`

On this workstation, `Godot` is `/Applications/Godot.app/Contents/MacOS/Godot`. Test save data and captures use OS temporary directories with exit cleanup. No generated test screenshots, recordings, logs or reports are retained.
