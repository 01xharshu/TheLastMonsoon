# NPC livelihoods and purposeful travel

22 November 2026. The existing city walker population now derives a stable livelihood and reason for travel from its authored route and resident index. Office approaches include clerks and visitors. Estate roads include domestic workers and visitors. Port approaches include porters and job seekers. Markets mix vendors, shoppers and job seekers, and village roads include day labourers. A visitor has a neighbourhood destination without an assigned income. These are street approach points. Existing workplace actors own the jobs inside buildings, and military duty owns sepoy posts and patrols.

Visible and logical city walkers use the same destination dwell policy. Saved route, direction and remaining dwell still use the existing save format. Clerks, domestic workers and vendors pass through outbound travel without accepting spontaneous peer chats. The peer gate leaves collision, traffic yielding and existing reactive dialogue eligible. No new bodies or paths are spawned by this policy.

Next implementation slices:

1. Connect appropriate approach endpoints to named home, workplace, hiring and market anchors. Mark a person as working only when a real work slot is assigned. Let day labourers reserve a timed opening at a market or freight yard. If none is available, give them a bounded wait and another reason to travel. Give unemployed residents errands and visits independently of hiring.
2. Keep wages and stock with the owner of each job. Start with one shift and one payment per saved worker, job and day. Validate capacity, cancellations and Continue before widening the economy. Use the existing workplace cargo, seat and tool contact where relevant.
3. Route witnessed events through the existing awareness owner. Use role, current task, distance, line of sight and urgency to choose a brief response, delayed response or continuation. Use the existing speech and expression owners for playback, gesture and cooldown. Sepoy duty and mission commands take precedence during their assigned actions.
4. Add fixture cases for full hiring capacity, missed shifts, route obstruction, urgent interruption, distant-to-near parity and saving during a shift. Compare native frame times on the same populated route and graphics settings before accepting any batching changes.

Current fixture: Godot headless, `--script res://tools/world/validate_street_livelihood.gd`. It loads the city and social owners with project autoloads and checks representative role choices, activity, dwell and the clerk's peer pause gate. It passed. Live endpoint placement, real hiring/payments, role-specific spoken lines, visual performance and native frame timing remain open.


## Port hiring baseline

The existing port approach endpoint now offers one casual freight slot to arriving port walkers between 07:00 and 17:00, with admission closing early enough to complete the shift. An accepted worker waits at the approach for twenty in-game minutes and is unavailable for spontaneous peer chatter. Other arrivals use their normal bounded stop. The world clock continues the shift across simulation tiers, and the saved payroll records one rupee for the resident per completed day. Continue restores the active reservation, deadline and accumulated wages through a separate optional save field. Older saves start with an empty ledger.

The shift is represented by time at the approach. The assigned freight worker still handles the physical crates. Transfer of actual freight by the casual worker, explicit interruption when a worker is injured, rendered endpoint clearance, normal disk Continue through the full world, and native frame measurements remain open. The focused fixture covers capacity, opening hours, an in-memory mid-shift save round trip, once-only settlement and next-day eligibility.

The port now releases a reservation without paying if its worker is dead or knocked out when the shift is checked. The hiring owner checks the loaded actor by stable port identity or uses saved condition data while the actor is still logical. This check runs before settling, admitting a replacement, or exporting payroll. The focused fixture exercises the materialized journey's arrival callback, cancellation at the deadline, logical arrival for a replacement, JSON round trip during the replacement's shift, and paid departure. It uses the authored port route without loading terrain or writing a game slot.

### Populated port verification

22 November 2026. The populated headless fixture materialized the existing porter, placed him on supported ground two metres before his route endpoint, and let the normal movement controller reach the hiring point. It saved the active shift through SaveManager, loaded a fresh world through Continue, verified the worker and deadline, then advanced the clock to the deadline and confirmed exactly one rupee across repeated payroll reads. This covers the final approach and disk reservation, not a complete pedestrian route, cargo operation, or native frame budget.

Run Godot with `--headless --path . --fixed-fps 60 --script res://tools/world/validate_port_hiring_world.gd`. Set `TLM_PORT_TEST_SAVE` to a save directory inside a disposable OS temporary folder and direct `--log-file` there.

The freight controller now emits a receipt after the crate is parented to the receiving station and the delivery count advances. The event carries the actual worker, shipment number, crate index and crate node. The shipment and index are scoped to the receiving station. Restore reconstructs cargo placement without emitting another receipt. The port fixture subscribes to this event and checks that all three crates produce distinct receipts after placement.

For a casual handoff, the station should grant one crate only when the hired worker reaches a supported pickup point, the cart is parked, and the crate has no other owner. The save needs the station and worker identities, crate key and transfer phase. A resumed shift must rebind those identities before advancing. Payment should consume a receipt for that reserved crate and worker once. The current timed reservation remains in use until this physical path is connected.

23 November 2026. Port payroll can now serialize a delivery reservation and consume a matching worker and crate receipt exactly once. Timed settlement leaves that reservation pending. The real port freight fixture feeds the assigned porter's shelf placement event into this payroll mode, verifies wrong worker and crate rejection, and restores the reservation and paid ledger across JSON round trips. The city hiring path still uses timed shifts until casual workers can take physical custody of the freight.
