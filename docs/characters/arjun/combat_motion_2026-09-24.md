# Arjun combat motion and flag break — 2026-09-24

The mouse left button now waits 0.26 seconds to distinguish a single click from a double click. A single click dispatches the selected sword, rifle, bow, pistol or knife; with weapons stowed it punches. A double click kicks and cancels the pending single attack. Controller attack presses dispatch immediately. Punch and kick use short forward damage rays and procedural upper-body/leg poses.

The sword rest IK no longer overwrites the right-arm slash pose. The hand grip stays attached to the existing talwar socket. A cut EIC flag now leaves a timber stump and releases an upper pole, cloth, rope and finial together as a colliding rigid body. The cut remains one-time for fame. This still uses a timed slash target decision rather than swept blade geometry; blade-to-pole contact and final hand fit remain open.

The boat rider is now aligned to the middle bench after boat rotation, with forward-bent thighs and knees. Metal capture: `docs/world/captures/15b_arjun_boat_seat_close.png`. The close view was inspected; seated contact is visibly improved, while exact grip/body approval is pending the owner-approved Arjun source (`docs/characters/arjun/rejection_2026-09-23.md`).

Checks: `tools/weapons/validate_combat_motion.gd` PASS in headless (click timing, slash phase, physical falling pole); `tools/weapons/validate_live_weapon_controls.gd` PASS; `tools/weapons/validate_rifle.gd` PASS; `tools/world/validate_river_climb.gd` PASS in headless and Forward+/Metal, including bench-follow motion and close capture. These checks do not approve final animation contact or character likeness.
