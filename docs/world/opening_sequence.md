# Arjun's live opening

Updated: 2026-10-09 IST. The main checkout now consumes the opening refinements previously left in `/Users/harshmishra/.codex-extra/worktrees/6c91/TheLastMonsoon`. Earlier preview captures are not current evidence or final approval.

## Integrated requests

- The opening diya is 35% of the shared household lamp's size. Its glass panels, metal enclosure, cap and handle are removed. It stays on the table throughout ignition; Arjun does not lift it.
- The initial camera faces the match from the front, closes on the strike and wick, then moves backward to the room view. The room starts dark; the match and diya glow grow gradually.
- Surface-derived finger contacts keep the match held during ignition. The spent match is placed on the table. Walking foot contacts, restrained waiting, eyelid closure, speech-envelope mouth movement and continuous bed/rise staging are integrated.
- The fitted MPFB donor retains the complete body and separate opaque foundation. Editable source: `WorkingAssets/Arjun/opening_fit/arjun_opening_fitted.blend`; export: `characters/arjun/arjun_opening_fit.glb`; rebuild: `tools/characters/build_opening_clothing.py`. Shared gameplay climbing, pistol, rest-tree and trouser-yoke improvements are preserved rather than replaced with older worktree versions. Clothing/acting remain candidates.
- Wind, river, fire, NPC calls and shared world effects are suppressed during the night opening. The title/world score remains non-autoplay. Cinematic match, cloth, cot, steps, murmur and sigh remain intentional cues. No synthetic night-room bed is used.
- Morning reveals at 06:00 on day two. The sun controller refreshes before the black fade clears; sunrise now supplies daylight and ambient room fill. Shared world ambience fades up over 1.6 seconds and a recorded sparrow calls outside the open sleeping-room window. Normal canopy calls continue afterward.
- The world wind rebuild removes its previous whole-loop fade to silence. Cached PCM loop seams overlap for 150 ms; one-shot recordings have short edge fades. Cinematic foley permits overlapping voices, and the final cot cue can finish after control release. No temporary morning loop is destroyed when Arjun stands.

## World integration

The title's New Journey route calls `SaveManager.start_new_game`, which quiets world sound before loading Suryagarh. `SaveManager.apply_pending` creates the live `OpeningSequence` only for a new game. It uses the actual Player, AnimationTree, furnished home, Charpai, GameTimeSystem and Sun controller. Continue/load does not replay the opening. Space/Escape skip to the same morning seat; a fresh button press begins standing and restores controls. `DevInquiry.begin()` remains connected after standing.

Reusable checks: `python3 tools/world/run_opening_checks.py` runs the real house/player/timeline on Metal and temporarily records the bus for silence-gap and clipping checks. Its captures, WAV and logs are deleted in `finally`. `TLM_OPENING_SINGLE=1 Godot --headless --path . --script tools/world/validate_opening.gd` checks one actual Suryagarh new-game cycle without loading the whole district three times. Use an OS temporary `--log-file`; screenshots are opt-in through `TLM_OPENING_TEST_OUTPUT` and must be deleted afterward.

Verification: the actual Suryagarh new-game route passed night→morning→fresh W→control release. The native Metal house/rig/timeline passed, including skip, stationary small diya, case removal and dawn audio. A 47.00-second bus recording had peak .783, a silent opening, and zero silent 20 ms windows across the measured nine-second dawn interval after the fade (including the wind loop seam). Fresh match/wick/front-camera and visibly daylight-lit morning frames were inspected; all recordings, frames and logs were deleted. The earlier three-world test timed out at 160 seconds; the focused actual-world run passed. These establish integration and measured continuity, not final acting or human listening acceptance.

To review in-game: launch the main checkout, choose **New Journey**, watch the small stationary diya and visible match, listen for no night ambience, then check that morning is visibly lit and birds/wind enter gradually. Stand with a fresh button press and listen across control release. Repeat with Space/Escape and confirm Continue loads saved gameplay without replaying the intro.

## Remaining scope

Cloth intersections under the bent lighting pose, reclining/contact polish, final facial acting, flame appearance and the synthetic spoken performance still require refinement and live approval. The separate police confrontation, public beating/detention, Surya tutorial and weapon/combat batches remain tracked by their existing owners in `docs/world/dev_inquiry.md` and the character/combat handoff. Their broader animation scope is not declared complete by this intro integration.
