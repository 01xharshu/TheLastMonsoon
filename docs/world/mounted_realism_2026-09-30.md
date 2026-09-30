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

## Owner correction — 2026-09-30 17:25 IST
IN_PROGRESS, chat 01a0e88d-3689-7963-8dd7-09f101cc449c. Owner says pose reads as standing, requires visibly seated legs and active forward control/lean on jumps. Existing foot solver stretches legs toward stirrups 0.85 m below pelvis; tiny spine-only offsets do not convey riding. Next shorten stirrups, inspect actual knee bend, increase smoothly blended gallop/takeoff/airborne/landing torso response and produce normal-speed rendered motion/contact evidence. Preserve uniform hoof sound and other character work.

First shortened-stirrup native review: seated legs now bend visibly; forward jump lean visible. A blocking live jump defect exposed: imported horse body rises inside its rig while saddle/rider track only the physics body, causing saddle and pelvis penetration despite passing socket checks. Next bind tack/seat targets to animated body delta and include actual mesh-to-seat render review before acceptance. Headless/Metal input/contact logs `/tmp/tlm_rider_seated_headless.log`, `/tmp/tlm_rider_seated_metal.log`.

Animated tack/seat frame now follows Torso pose relative to its rest; bridle bit follows Head. Rider seat sync runs after animation and before rider posing. Replaced hanging legacy stirrups with the shortened fitted pair. Next native regression and continuous pose/contact capture.

Continuous seated-motion diagnostic: knees ~98 degrees maximum, seated/walk/gallop contact stable, but jump apex had one large asynchronous seat/hand error. Imported AnimationPlayer now advances explicitly with horse physics before updating animated tack and rider targets; native motion validation pending. New `tools/horses/validate_rider_seated_motion.gd` checks all sampled contacts and leans, records actual input-driven phases.

Apex defect fixed by applying rider pose after the final horse physics/back transform, rather than at an independent render phase. New continuous headless check PASS across 102 samples: knees maximum 98.26 degrees (180 straight), seated lean 6.84 degrees, gallop 23.07, jump 35.77; seat/stirrup/rein residuals below 0.000004 m. Native render/movie next, no cloth approval implied.

## Step 1 — trouser waist and knee weights

Runtime-only `player/arjun_trouser_fit.gd` now smoothly anchors the upper trouser rings to pelvis, blends into each matching thigh, and smooths the thigh/calf transition. Applied once by clothing setup; source GLB and Blender files preserved. Both legs contain 118,272 imported vertices; no additional meshes or per-frame geometry rebuilds. The animation lookup now guards an empty/finished horse clip rather than logging missing-animation errors during jump recovery.

`tools/horses/review_rider_trouser_fit.gd` uses the current physical rider fixture and records fresh seated/walk/gallop/jump/recovery views without the frame-post-draw stall encountered in the movie fixture. Headless and Metal PASS across 102 samples. Native maximum knee angle 98.31 degrees, seated lean 6.90, gallop 23.40, jump 35.31. Seat/sole/palm residuals under 0.000004 m. Evidence: `trouser_fit_motion_metal.json`, `trouser_fit_motion_headless.json`, `captures/trouser_fit_seated.png`, `captures/trouser_fit_jump.png`. These are pose/contact checks and sampled pixels, not a normal-speed movie. Sharp trouser folds remain; source body and cloth are unapproved.

Older combined `validate_mounted_realism.gd` fails its cart speed >4 m/s assertion in this checkout; that failure is independent of trouser weights and is retained as an unresolved cart regression. Next step: close finger/thumb grip and cart passenger fit, then continuous route review.

Cart driver Metal frame refreshed, but `capture_cart_boarding.gd` stops at its dismount assertion (line 45), so passenger capture was not reached. Driver frame is not a boarding/dismount PASS. Preserve current cart collision work; fix the exit fixture/contract before extending passenger review.
