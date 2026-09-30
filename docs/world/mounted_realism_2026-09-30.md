# Mounted motion refinement — 2026-09-30

Arjun now follows the active horse animation phase with a small spine response, increasing the forward riding posture at gallop. Takeoff fold follows vertical velocity; descent releases it and a short impact response decays after landing. Pelvis remains at the saddle socket and feet retain the existing stirrup solve. The close Metal side review caught an inverted spine bend; the bend was corrected so takeoff/gallop move the chest forward. Both palms now face down and solve toward paired rein grips ahead of the pommel, with mild finger closure; flexible reins still use actual palm endpoints.

Cart drivers respond to smoothed acceleration and turning; passengers receive a smaller torso response. Holding sprint while driving raises forward speed from 3.4 to 5.2 m/s with the existing acceleration and collision checks. Reverse speed stays 3.4 m/s. Cart jump mechanics were not introduced.

## Evidence

- `tools/horses/validate_mounted_realism.gd`: headless and Metal Forward+ PASS for actual input-driven cart acceleration above 4 m/s, horse gallop above 9 m/s, airborne jump, landing event and impact recovery.
- `tools/horses/validate_cart_boarding.gd`: PASS for family, ekka and goods driver/boarding/dismount.
- `tools/world/validate_horse_reins.tscn`: headless and Metal PASS for articulated reins and moving palm endpoints.
- Latest Metal sampled contacts: palm target error rounded to 0.000 m; boot sole target error 0.000 m seated and 0.004 m during gallop/jump. These are socket diagnostics, not skin/cloth clearance approval.
- Fresh Metal poses: `captures/cart_arjun_horse_seated_refinement.png`, `captures/cart_arjun_horse_gallop_refinement.png`, `captures/cart_arjun_horse_jump_refinement.png`. Isolated floor fixture; these are sampled frames, not a continuous normal-speed recording or full-world route acceptance.

Current Arjun body remains owner-rejected. Side frames inspected: forward bend and rein grip improved; trouser distortion at thighs/knees remains visible. Seat/thigh mesh clearance, close finger shape, jump timing against the imported horse clip and long rough-road behavior remain visual review gates. Existing headless fixtures report resources retained during shutdown; gameplay assertions still pass. No production or character appearance approval is claimed.
