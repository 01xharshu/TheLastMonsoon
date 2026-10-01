# Arjun's errands and paid work — 2026-10-01

A first integrated job loop in Bhairavpur, using the existing rupee inventory, interaction finder, coin reward feed and merchant counting house. The screenshot supplied during this task guides the document layout: original procedural aged paper on the left, readable text/actions on the right, and an opaque black background. No screenshot artwork is reused. Job updates use a temporary wrapped message; coin rewards retain the existing item feed. No unrelated character or terrain assets are replaced.

## How to play

Approach the stranded traveller on the village road, the clerk inside the merchant counting house, the market receiver, or the wooden WORK NOTICES board beside the market receiver. Use the normal interaction button. Read the request and wage, then accept or leave. Only one errand is active at a time.

- Food aid: accept, bring one roti and speak to the traveller again. Removes the roti, pays 2 rupees from the fictional market relief fund and awards the existing +4 help reputation. The needy traveller does not pay from his own pocket.
- Cloth delivery: accept through the clerk or board, collect the sealed cloth parcel on the counting-house dispatch desk, and speak to the market receiver. Pays 8 rupees on delivery. The employer's parcel is held in job state, separate from saleable player inventory.
- Sorting work: accept through the market receiver or board, hold the sorting-table interaction for 3 seconds, then return to the receiver. Pays 5 rupees. Releasing early clears hold progress.

J opens the errand journal. Active jobs also appear when speaking to a job giver or reading the board. Mark next stop on map writes a waypoint into the existing field map. Leave/Escape resumes play; menu buttons support controller focus/confirmation and back. Controller users can revisit the board to access active-job controls. Cancellation clears progress and the employer's parcel without granting a wage.

The first three requests are one-time jobs. Repeatable schedules, broader city placement and a larger job catalogue remain future work. Jobs are data entries with stable IDs and endpoint roles; new people/buildings can share the same interaction and progression system.

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

`world/suryagarh/errands/destination_marker.gd` draws both markers. `tools/world/validate_destination_guidance.gd` checks the 400 m label, behind-camera arrow, stage/restore transitions, modal/cancel hiding, custom map pin and a normal-speed route using the real controller followed by the normal interaction input. Validation result and capture review are recorded after the final run below.
