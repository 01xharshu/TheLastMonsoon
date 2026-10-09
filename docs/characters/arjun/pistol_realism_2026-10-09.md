# Pistol motion baseline — 2026-10-09

Current status: playable grip/recoil/loading baseline integrated; final hand skin, clothing contact, historical loading drill and character approval remain open.

## Changes

- Held Adams remains at 72% of imported scale. Right thumb lies alongside the handle; the index curls toward the trigger while aiming and straightens alongside the frame during ready/loading. Right hand recoil and recovery follow the existing shot event.
- Three filtered AnimationTree layers (`pistol_aim`, `pistol_reload`, `pistol_recoil`) blend spine/head poses over locomotion. The arm and finger contact solves run after evaluation. Aim/loading transitions use a 0.286-second smooth blend; rest/custody clear the layers.
- Loading brings the right hand to skeleton-space (-0.24, 1.42, 0.34), visible beside the shoulder. The left thumb/index form a reachable pinch before the wrist carries a small ball from the pouch to the cylinder. Loading is paced per missing chamber: one charge 4 seconds, five charges 16 seconds, with one sound click per insertion. Ammo transfers only on completion; stow/switch cancels without consumption.
- Four open pistol sight dashes tighten over a collidable `human_npcs` target, spread briefly after firing, then settle. Long-gun dash spacing remains distinct.
- Settings adds persistent **Camera angle** and **Aim camera angle**, -10 to +10 degrees, alongside the existing normal/aim distances. Day/time remains absent from the historical HUD.

## Verification and limits

`tools/weapons/validate_pistol_motion.gd` passed aim/reload AnimationTree transitions, trigger/thumb envelopes, shot/recoil recovery, null mount metadata, five-charge timing/accounting, cancellation, physical MPFB human target sight response, and camera settings application/restoration. Largest right wrist step at 60 Hz: 0.0552 m. Worst left loading joint midpoint to visible ball: below 0.001 mm. Joint envelopes do not establish skin contact approval. Isolated visual processing averaged about 0.120 ms on the M4; this is not whole-world FPS.

Native Forward+/Metal player-camera and close side views were inspected. Moving the loading pose above and beside the shoulder corrected its earlier occlusion. The right index straightens during loading. The side view still shows coarse finger skin and close left-hand/weapon overlap; final pad contact and sleeve deformation are not approved. The existing owner-rejected Arjun body/clothes were not edited. Retain its complete MakeHuman body and foundation garments.

This is a simplified ball-transfer reload. Powder/rammer/percussion-cap handling and a mechanically animated pistol loading lever are not implemented by this pass; do not label it a complete historical drill. Existing Enfield cartridge/ramrod sequencing is retained. Audio event timing is tested; natural sound balance still needs listening in the populated world.

The integrated world firearm regression also reported `FIREARMS TEST PASS`. The five-charge native player-camera sequence simulated 17.6 seconds in 17.8 seconds on Forward+/Metal; this is playback pacing, not a world performance benchmark.

The headless fixture exits with six ObjectDB and two resource cleanup diagnostics despite passing its assertions. Native review exited without those diagnostics. Whole-world errors/performance and final owner approval remain separate gates.

Review output is disposable: `python3 tools/weapons/review_pistol_motion.py` uses an OS temporary directory and deletes it after inspection, failure or interruption. `--side` selects the close prop view; `--charges 5` reviews a full loading sequence. No generated captures or reports are retained.

## In-game review

1. Equip and draw the pistol. Hold RMB: check the hand, shoulder, head edge and four open sight dashes. Aim at a human NPC with collision: check colour/spacing response.
2. Fire with LMB: check muzzle alignment, trigger finger, recoil recovery, sound and sight spread/settle.
3. Press R after one shot, then after emptying all five chambers. Check the visible left-hand pinch and loading movement, 4/16-second pacing, insertion sounds and ammunition count.
4. Stow or switch during loading: check that the ball disappears, the loading pose releases and ammo is not consumed.
5. Open Settings, adjust normal/aim camera distance and angle, resume and restart to check saved composition. Review while walking and near cover; first person has its own view.
