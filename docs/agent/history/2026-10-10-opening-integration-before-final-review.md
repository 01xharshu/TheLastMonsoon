# Completed shared opening integration notes

## Startup loading error — updated 2026-10-09 IST — current chat
- Status: COMPLETE. Objective: reproduce and fix the error preventing game loading in the main checkout.
- Completed: fixed explicit float typing for `angle` in `story/opening_cart_passage.gd:132`. Dynamic gathering iteration broke inference, preventing opening sequence and SaveManager compilation.
- Files changed: `story/opening_cart_passage.gd`, this ledger. Preserved both pre-existing untracked .gd.uid files.
- Verification: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_opening_cart_passage.gd` PASS (exit 0; travel/camera/room/skip/restoration/audio). Native Metal `tools/maintenance/smoke_game.gd` MENU PASS (exit 0; configured studio intro → title, 8.496s). Native WORLD loads successfully (91.902s), but broader smoke FAIL: its 120-frame wait ends before current morning departure completes, so control/reload assertions run while opening controls are locked. `git diff --check` PASS.
- Limits: full gameplay smoke is not certified. Forced headless `--quit-after 600` emits two ObjectDB leaks; graceful native menu shutdown and cart validator emit none. No retained test captures/logs/reports; disposable project and custom test user data removed.
- Exact next action: user F5 → New journey, optionally Esc twice to skip → allow dawn/stand/walk-to-gate sequence to finish → verify controls. Future maintenance: update smoke fixture's opening wait to follow elapsed dawn/departure rather than 120 frames and account for tutorial locks.

## Automatic cinematic playback — updated 2026-10-09 22:58:07 IST — current chat
- Status: COMPLETE. Objective: opening story text and scenes play continuously without interaction, like a cinematic video.
- Completed: cards/cart/night/dawn/gate continue automatically. Added monotonic real-time playback timing so low rendering FPS does not stretch simulation-driven durations. Loading artwork still holds the clock; optional skip remains. Manual validator stepping with processing disabled retains supplied delta.
- Files changed: `story/opening_sequence.gd`, `docs/world/opening_sequence.md`, this entry. Existing concurrent changes preserved.
- Verification: `TLM_OPENING_SINGLE=1 TLM_OPENING_REALTIME=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_opening.gd` PASS, exit 0, no diagnostics. Full real-time actual-world run without input passed prologue/cart/night → automatic dawn/gate → control release and tutorial activation. `git diff --check` PASS. No captures/recordings/reports generated.
- Limits/blockers: no implementation blocker. Headless functional timing check does not certify native FPS or acting/clothing appearance.
- Exact next action: user F5 → New journey, then watch without pressing anything; controls/tutorial start after Arjun reaches the gate.

## Opening → police → Chacha animation refinement — current assignment
- Status: IN_PROGRESS / ART OPEN. User assigned complete scene/motion/weapon-contact/fall/clothing refinement and a 10-real-minute game day.
- Runtime pass: seated attentive officials with stand/desk route; persistent rifle-butt/punch/kick contacts; seekable AnimationTree collapse/recovery; two-guard exterior carry/throw, second fall and assisted departure. Existing 2.4 game-minutes/second clock verified; no rate change needed. Full bodies/assets retained.
- Checks: isolated story/training PASS; sampled contact/day/pause PASS; actual-world opening/onboarding/gate/recovery/farm/save-load PASS. Native Metal sampled review completed and found visible Chacha skin/clothing deformation. Tests use temporary output only; all outputs removed. Details: `docs/world/story_cinematics_and_training.md`.
- Unresolved: Chacha support clothing/limb deformation and exact support/finger contact; continuous natural motion, settling, facial nuance and FPS approval. Conservative support gesture replaces the distorted IK candidate. **No perfection/final-art approval.**
- Exact next action: repair editable MPFB merchant source/skin/clothing for Chacha, preserve complete body/foundation, then rebuild paired lift/support and review uninterrupted wake-up→station→rescue. Preserve concurrent opening/city changes.

## Public passenger cart / traffic — 2026-10-10
- Existing MPFB driver + two passengers, two free bench seats, exterior lantern, Bhairavpur dialogue/head gesture and 8–13s driver shot integrated; no spoken audio. Skipped opening retains public fittings. Native fixture + actual-world opening PASS; final cloth/contact/FPS review open. `docs/world/opening_passenger_cart.md`.
- Actual-world headless movement PASS: 72/72 walkers, 8/8 carts, 9/10 police progressed; zero blocked walkers/stopped carts. Government House initial wall overlap fixed with collision-checked parallel lane placement. Native Metal repeat PASS (same counts); household EntranceDoor stalls for OfficialMan/OfficialWoman/MerchantHouseholdMerchant handed to existing owner. `docs/world/city_route_population.md`.
- Working files and temporary complete index size/LFS PASS; eight storage tests PASS. Main/remote matched `a6b6b876`; no commit/push/history rewrite. Disposable test outputs deleted after review.

- Cart caption correction (2026-10-10): removed the world-space Label3D. Opening uses its existing bottom subtitle only; nearby gameplay arrivals use a bottom 2D caption. Speaking gesture remains. Native Metal caption review + fixture PASS (exit 0, 17.5s): bottom caption only, gesture/boarding intact; temporary outputs deleted.
