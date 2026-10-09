# Station arrest sequence — 2026-10-01

Status: physical escort foundation. The current default cinematic custody/release behavior and current test results are in [police custody transfers](police_custody_transfers.md). Historical deleted captures below are not current evidence. Animation, costume and historical acceptance remain separate.

## Playable behavior

The DistrictPolice station now observes local theft of its weapon/supply pickups and assaults through the actual damage receiver. A living daroga or burkundaz needs an unobstructed sight line; the record clerk does not arrest. Unknown offences, incidents outside the station footprint, dead witnesses and repeated reports during an active arrest are rejected.

The officer approaches along a collision-checked route. When Arjun is in a supported detention state, weapons stow and travel/combat/actions are locked. The officer leans toward Arjun's restrained wrists; small original cord loops follow the wrist bones. Arjun and the officer then walk through the hall alongside one another. Arjun enters the ground-floor cell alone, sits on its platform, waits, stands and walks through the reopened gate. Release restores ordinary control, and the officer returns to his post. The gate is a hinged interactive leaf with a matching moving collider; E works while it is unlocked.

Default custody is a short **12-second gameplay wait**, not a historical sentence. The validation harness shortens it to three seconds. Officer loss and unreachable/timed-out routes release the player safely. Movement uses the actual collision body; collision is never disabled for the escort. Cached station grids are built only when an incident needs a route, with live collision checks during movement.

## Motion and contact

The existing Arjun rig remains authoritative. The detention tree filters the upper body so locomotion legs can continue during escort. Seated waiting uses the rest tree, pelvis/platform placement, boot support targets and hand targets above the knees. Arms blend during sitting/standing, and palm orientation is directed down onto the lap rather than leaving the fingers pointing through the trousers.

The three previous thana exports had no skin. Independent rigged motion exports now retain the village MPFB source skin and deform weights. Officer animation uses the established independent NPC tree, a forward restraint lean and a post-tree palm solve. The uniform fittings, trousers, shoes, cap/turban and beard follow the rig. These remain art candidates rather than finished likeness or clothing approval.

## Evidence

`tools/world/validate_police_arrest.gd` loads the actual Suryagarh world. It exercises the real assault receiver, all nine arrest/release phases, gate lock/unlock, continuous player movement, formation clearance, actual pickup theft, outside-incident and dead-witness rejection, and safe abort on officer loss. Position measurements run every physics frame, independently of screenshot waits. JSON evidence: `arrest_sequence_validation.json` and `arrest_sequence_validation_metal.json`.

The passing route covers about 17.01 m. The final player displacement per physics tick is about 0.0192 m. The settled restraint palm error is about 0.0156 m against a 0.025 m validation threshold. This metric measures palm-to-wrist position; it does not certify finger shape, cloth thickness or convincing acting. Fresh Metal frames include restraint, escort, seated waiting, standing and exit; `arrest_sequence_escort_back.png` exposes the restrained wrists during walking.

The motion capture harness uses the same station, collisions and sequence at fixed 30 fps. It hides meshes outside the station/player for capture rendering while retaining the world simulation. Its encoded playback rate is not a measured full-world frame rate or 8 GB performance result. The approximately 29-second preview ends after Arjun is released while the officer starts returning to his post; the full return is checked by the separate validator. The early capture exit reports two retained objects/one resource at shutdown; the completed validation harness cleans up without that warning. See `police_arrest_motion.mp4` for the final capture, and the thana staff document for uniform review images and references.

Regression: the original timed detention/action/ammunition-conservation checks and idle/walk/run/swim/sit/long-gun AnimationTree envelopes pass. `validate_thana_staff.gd` now checks the rigged actors, individual AnimationTrees and animated body colliders rather than the obsolete static preview shape.

## Limits

This is a station-local arrest loop. City-wide wanted levels, reinforcements, save/load persistence during arrest, inventory confiscation, court/sentence rules and dialogue are not implemented. The damage API still assumes the current player caused a reported assault; an explicit attacker identity is needed before other AI can reliably commit crimes. Moving furniture can block a cached route; live collision prevents penetration and timeout safely ends the arrest, but dynamic replanning is limited.

The cord and short detention procedure are fictional gameplay choices. Exact wrist/finger/clothing contact, escort gait cadence, seated garment clearance, officer acting and owner-controlled play review remain open. Existing unrelated household route warnings are recorded separately from arrest results. Physical 8 GB device performance remains unverified.
