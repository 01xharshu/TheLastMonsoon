# Arjun's errands and paid work — 2026-10-01

A first integrated job loop in Bhairavpur, using the existing rupee inventory, interaction finder, coin reward feed and merchant counting house. The screenshot supplied during this task guides the document layout: original procedural aged paper on the left, readable text/actions on the right, and an opaque black background. No screenshot artwork is reused. Job updates use a temporary wrapped message; coin rewards retain the existing item feed. No unrelated character or terrain assets are replaced.

## How to play

Approach the stranded traveller on the village road, the clerk inside the merchant counting house, the market receiver, or the wooden WORK NOTICES board beside the market receiver. Use the normal interaction button. Read the request and wage, then accept or leave. Only one errand is active at a time.

- Food aid: accept, bring one roti and speak to the traveller again. Removes the roti, pays 2 rupees from the fictional market relief fund and awards the existing +4 help reputation. The needy traveller does not pay from his own pocket.
- Cloth delivery: accept through the clerk or board, collect the sealed cloth parcel on the counting-house dispatch desk, and speak to the market receiver. Pays 8 rupees on delivery. The employer's parcel is held in job state, separate from saleable player inventory.
- Sorting work: accept through the market receiver or board, hold the sorting-table interaction for 3 seconds, then return to the receiver. Pays 5 rupees. Releasing early clears hold progress.

J opens the errand journal. Active jobs also appear when speaking to a job giver or reading the board. Mark next stop on map writes a waypoint into the existing field map. Leave/Escape resumes play; menu buttons support controller focus/confirmation and back. Controller users can revisit the board to access active-job controls. Cancellation clears progress and the employer's parcel without granting a wage.

The initial catalogue has two daily paid jobs and one permanent roadside-aid request. Merchant delivery and market sorting can each pay once per game day. Broader city placement and a larger job catalogue remain future work. Jobs are data entries with stable IDs and endpoint roles; new people/buildings can share the same interaction and progression system.

## Ownership and persistence

`world/suryagarh/errands/errand_system.gd` owns offers, accepted/carrying/worked/completed state, wage and journal UI. `errand_target.gd` supplies six contextual world endpoints. The world creates the module before pending-save restoration. Saves store active/completed jobs alongside inventory money, and now persist existing fame points/witnessed deeds. Old saves without job/fame fields use empty defaults. Unknown IDs and invalid job stages are rejected.

Job conversations pause the world and preserve mouse mode. Opening/reading/accepting does not grant money or fame. Range/dead-person guards apply to world interactions. Completion clears the active job before granting money, so repeating the receiver interaction cannot pay twice.

## Validation and remaining gates

Focused fixture: `tools/world/validate_errands.gd`. Initial populated-world headless run passed aid inventory/fame, delivery order, interrupted/full controller hold progression, exact wages, cancellation, save/resume and same-job duplicate-payment protection (`/tmp/tlm_errands_check.log`). A stricter pass also checks the real player's target finder at all six endpoints. Forward+/Metal final progression run PASS: `/tmp/tlm_errands_final.log`. All six targets passed the real target finder at standing capsule height. Board/journal and market captures were inspected: `captures/errand_board.png`, `captures/errand_journal.png`, `captures/errand_market.png`. Final message-layout follow-up PASS on Forward+/Metal: `/tmp/tlm_errands_release.log`; the updated market capture was inspected and the earlier cropped job-feed entries are gone.

The first native attempt was interrupted by concurrent parse errors in `player/detention_contacts.gd`; the owner fixed those independently. The stricter fixture was corrected to use Arjun's global facing and capsule-centre height; both affect real targeting. Outdoor placement rays exclude NPC combat hitboxes and sample solid ground. Final market capture shows grounded Arjun and receiver. These staged captures and direct progression calls do not establish continuous normal-speed player acceptance.

NPCs reuse the current rigged village candidates; their existing cloth/appearance acceptance remains open. Conversation gestures, parcel carry/hand-off, sorting hand contact, spoken dialogue, broad-city routes, historical wage calibration and constrained-device profiling are not validated by the job-state tests.

Earlier item-use/contact status remains in [collection/item use](collection_merge_and_item_use.md); bandage/save behavior remains in [medical supplies](medical_supplies.md).

The document overlay scales from a 1280 × 720 logical canvas to the actual window, keeping paper, text and buttons proportionate at higher display resolutions. Final scaled native run PASS: `/tmp/tlm_errands_scaled.log`; the refreshed journal capture was inspected.

## Destination guidance — 2026-10-01

Accepting an errand automatically displays the current destination in the gameplay view. A yellow diamond-and-cross symbol carries the remaining horizontal distance above it (for example, `400 m`). A matching small icon and the current objective appear in the upper-left corner, following the two marker reference screenshots supplied in this chat. The marker becomes a screen-edge arrow when the destination is outside the camera view or behind Arjun. It guides the player without moving or steering Arjun.

Collecting the cloth parcel changes the target and objective to the market receiver; finishing sorting changes them to wage collection. Save restoration re-derives the appropriate stop from job state. Completing/cancelling clears job guidance and a matching job map pin. Independent player map pins retain their own destination marker. Journal/map/inventory/pause hide gameplay guidance. Long temporary notices use the lower centre so they do not overlap the upper-left objective.

Roadside traveller placement now uses the clear edge of the actual merchant lane at `(-378, 315)`, rather than a point beside a competing house entrance. Conversation targets sit at chest height while their physical collider stays around the body, preventing terrain interception of the interaction ray. Outdoor ground sampling ignores combat hitboxes.

`world/suryagarh/errands/destination_marker.gd` draws both markers. `tools/world/validate_destination_guidance.gd` checks the 400 m label, behind-camera arrow, stage/restore transitions, modal/cancel hiding, custom map pin and a normal-speed route using the real controller followed by the normal interaction input. Headless walking check PASS: `/tmp/tlm_destination_arrival.log`. Forward+/Metal movement/arrival check PASS: `/tmp/tlm_destination_verified_metal.log`; the 400 m, off-screen and arrival captures were inspected. Existing errand progression regression PASS: `/tmp/tlm_errands_marker_regression.log` (with two ObjectDB/one resource shutdown diagnostics). The last visual follow-up raises NPC pins above the head and clears stale notices on save/state restoration; final evidence is recorded below.

Final Forward+/Metal follow-up PASS: `/tmp/tlm_destination_final_review.log`. Fresh `captures/destination_400m.png`, `captures/destination_offscreen.png` and `captures/destination_arrived.png` were inspected. The normal-input final approach travelled from `(-376, 327)` to approximately `(-377.919, 315.762)`, selected the traveller, completed the food-aid interaction, awarded 2 rupees and cleared the marker. This checks the final approach, not a complete 400 m journey or owner acceptance of the existing character/world art.

## Daily paid work — 2026-10-01

Merchant deliveries (8 rupees) and market sorting (5 rupees) reopen on the next game day. Their board entries show “Paid today · Return tomorrow” after completion. Roadside aid remains permanently completed, preserving its one-time money/reputation reward. The wage limit is per job, so Arjun can do both daily paid jobs.

`completed_days` stores the last paid day separately from the active job stage. Accepting/cancelling tomorrow's shift does not erase payment history. Jobs spanning midnight charge the actual completion day; active parcels and worked-but-unpaid shifts survive day changes. The existing errand save field now includes this ledger. Completed jobs in older saves without payment dates are conservatively treated as paid on their saved current day, with daily work available tomorrow. Invalid active state claiming a job already paid that day is rejected, and clock rewind does not reopen its wage.

Focused native validation `tools/world/validate_daily_errands.gd` PASS (`/tmp/tlm_daily_errands.log`): two deliveries on separate days, same-day rejection, paid-state save/load, cancellation, midnight active sorting, completion-day accounting, permanent aid, old-save migration, corrupt active-state rejection and clock-rewind guard. Native notice board inspected at `captures/daily_errand_board.png`; final paid-status capture review follows. These checks validate schedule/payment state and UI; parcel hand-off/sorting motion and broader route/owner art gates remain open.

## Port, family cart and urgent requests — 2026-10-02

Four requests extend the current job ledger: port consignment (18 rupees, counting house → port warehouse → counting house, daily), medicine (10 rupees, worried neighbour → market dispenser → neighbour), sealed emergency money (12 rupees, roadside sender → family by port), and brother's passenger-cart trip (20 rupees, counting house → village cart stand → family home). The medicine/money/passenger requests are one-time. Entrusted goods and money remain job state, so they cannot be spent as Arjun's currency. Wages occur only after handover. Cargo stages persist in saves.

The employer lends a passenger ekka beside the waiting brother. Another nearby ekka with a PassengerSeat can be used. Cart must be within 5m and stopped for pickup; arriving cart must be within 7m and stopped before payment. A driver can board/unload the passenger by stopping close to the marked person; on foot the regular conversation interaction also works. Cancelling releases the passenger without payment. The 2026-10-05 continuation below supersedes the original pickup-only save behaviour.

Nearby food, medicine and money requests call out within 16m when no job is active. A 45-second shared cooldown limits repetition. Temporary synthetic spatial speech is paired with subtitles; provenance/rebuild sources are retained in `audio/errands/README.md`. No voiced performance approval is claimed.

Functional evidence: latest `/tmp/tlm_expanded_jobs_audio.log`, earlier `/tmp/tlm_expanded_jobs_checked.log` — EXPANDED ERRANDS PASS for ordered pickups, saved cargo, exact 60 total wages, cart proximity, seated hip anchor, stopped arrival, and duplicate-payment guard. Existing daily wage regression `/tmp/tlm_expanded_regression.log` PASS. Initial full-world runs additionally report an unrelated cattle caretaker `sole` type inference error. Native Metal run `/tmp/tlm_expanded_jobs_metal.log` PASS for the same staged checks; latest native run `/tmp/tlm_expanded_jobs_seat.log` PASS; current occupied cart and objective were inspected in `captures/errand_cart_resume.png`. The seated pose owns its bones while aboard. Full road drives, boarding/disembark motion and cloth contact, final voices and historical/owner acceptance remain open. Scripted relocation is not evidence of a continuous driven route.

Documentation check: handoff shortened to 60 lines. The index check still reports missing captures in other ongoing sections after shared evidence cleanup; the errands index now links the retained current passenger/marker capture. Scoped diff whitespace check passes.


## Occupied passenger-trip saves — 2026-10-05

The errand save now retains the employer cart's transform and the occupied passenger vehicle's stable world path, position and heading. Loading a valid in-progress trip restores the passenger's seated pose and keeps the family-home objective. Registering the borrowed ekka with the existing live-cart save system also restores Arjun in the driver seat. This uses the existing MPFB village-farmer rig; no new human body or primitive placeholder is authored.

Restore works both when the errand targets are already built and when save application precedes their deferred creation. Missing, invalid, non-finite, outside-world or non-passenger vehicle records safely return the job to pickup without payment. An occupied errand passenger seat no longer offers or accepts Arjun's passenger boarding action; driver boarding remains available. Dead passengers cannot complete the trip for wages.

Functional PASS: `/tmp/tlm_errand_driver_disk.log` and native Metal `/tmp/tlm_errand_driver_disk_metal.log`. The fixture writes a temporary real SaveManager slot with Arjun driving and passenger aboard, mutates state, loads it, verifies cart transform/both occupants/home objective/unchanged 40 rupees, rejects an invalid path, then finishes for exactly 60 total with no duplicate payment. Test save files are removed afterward. The headless run reports two ObjectDB and one resource shutdown diagnostics; do not interpret exit status alone as cleanliness. Fresh restored-occupant Metal review PASS and inspected in `/tmp/tlm_errand_resume_review.log` and `captures/errand_cart_resume.png`. Boarding/disembark blending, physical route driving, hand/foot/cloth contact, and owner approval remain open.

Evidence retention: `captures/errand_cart_resume.png` replaces the superseded single-passenger overview; its links and capture fixture were updated. No character sources were removed. Documentation index/handoff check PASS; scoped whitespace check PASS. A shared coachman script emitted an unrelated initialization error in an earlier headless run; final rendered run completed with explicit errand PASS.


## Passenger transfer motion — 2026-10-05

Boarding and unloading now run for 2.4 seconds rather than moving the NPC straight to the seat or ground. Hip position and seated leg bend blend through the cart step; the existing household leg solver places each foot on the tread/footboard in separate swings, and the existing MPFB actor hand solver reaches toward the side rail. The original MakeHuman village-farmer rig is reused. This is a runtime contact candidate, not a new human body or approved performance.

The driver controller suppresses throttle/steering while `errand_transfer` is active. Interaction re-entry cannot restart a transfer. Unloading requires a support ray with a walkable normal and height within 0.35m of the cart floor, plus capsule clearance beside the cart. If both sides are blocked, the passenger stays aboard and the player is asked to park on clear ground. The 20-rupee wage occurs only after the full exit transition. Cancellation/death clears the movement lock and pays no wage. In-progress transfer saves restore the existing occupied-trip state to the seated pose rather than replaying or paying for an exit.

Validation: `/tmp/tlm_errand_transfer_blocked.log` explicit PASS: gradual per-frame movement (<0.25m root change per sampled physics tick), delayed payment, stopped/blocked exits, occupied disk save/load, invalid vehicle fallback, exact wages and duplicate-payment prevention. The fixture now waits for the passenger to follow staged cart relocation before unloading; relocation itself does not claim a driven route. Native initial synchronized motion PASS: `/tmp/tlm_errand_transfer_synced.log`; final native contact/blocked-exit capture PASS: `/tmp/tlm_errand_transfer_final.log`; clear-view follow-up PASS: `/tmp/tlm_errand_transfer_clear_views.log`. Distinct current views: `captures/errand_boarding_step.png`, `captures/errand_exiting_step.png`, and `captures/errand_cart_resume.png`. These replace earlier versions of the same views in place.

Open gates: full player-input route driving, continuous video/normal-speed owner acceptance, quantitative palm/sole contact and cloth clearance. The transfer uses prescribed root/foot paths; a swept-body obstacle check for every boarding segment is not yet implemented. Final voiced performances remain placeholders. Functional PASS does not close these appearance/contact gates.

The upper-left objective now says to wait during boarding and to let the passenger step down during unloading, then returns to the home-driving objective. Latest HUD capture follow-up explicit PASS, no script errors in log, and both current views inspected: `/tmp/tlm_errand_transfer_hud.log`. Clear-view contact candidates show a planted step foot; rail reach/finger grip and cloth appearance remain unapproved.
