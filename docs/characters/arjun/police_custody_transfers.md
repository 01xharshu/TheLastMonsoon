# Police pursuit and custody — 2026-10-07

The playable DistrictPolice loop now pursues witnessed local theft/assault, allows Arjun to resist, restrains him, fades into station booking, fades into the locked ground-floor jail, and releases him on the front porch at 06:00 after three game days. This is fictional gameplay procedure.

Police pursue at 3.8 m/s on the existing collision-checked station routes. If Arjun keeps a weapon drawn or continues punching/kicking, the nearby officer uses a guarded punch motion and nonlethal damage (8 per landed attack, capped to leave at least 20 health). Stowing the weapon and stopping attacks permits arrest; sufficiently weakened Arjun is also arrested. Dead/knocked-out officers cannot continue the sequence. The player can still damage officers through the existing combat system.

Arrest retains the existing detention/AnimationTree branch, wrist restraint and action locks. Two 0.7-second fades cover transfers to a clear hall booking position and the seated jail pose. Five seconds show custody before a 0.9-second fade and two-second black hold saying “3 days later.” The authoritative GameTimeSystem advances to 06:00 three days later, updating its normal listeners. A 0.9-second morning fade reveals Arjun on the clear station porch. The cell unlocks, restraint controls release and the officer returns to duty. The day count is configurable from 1–30 on ArrestCoordinator.

All relocations assert full screen opacity. Officer loss, missing clock and explicit abort remove the overlay and release detention safely. This reuses the existing full-body MPFB player/officers; no new human asset was created.

## Verification and play check

`python3 tools/world/review_mango_contact.py --police --headless` tests the actual station geometry, player and officers: pursuit, resistance, damage, arrest, all fade/booking/jail phases, three-day advance, exact morning clock, locked/unlocked cell, clear booking/porch positions, restored controls and partial-fade abort. Focused headless and Metal checks PASS. Native temporary review showed guarded strike, booking, seated custody, fade caption and porch release. Test output is deleted; these text results do not grant final garment/contact approval. The accelerated fixture is not a real-time performance benchmark. The headless fixture still reports retained-object warnings on exit (2–5 across the current runs); exit cleanup is not approved.

For temporary visual review, run the same command with `--inspect` instead of `--headless`, inspect the printed temporary directory, then press Enter to delete it. The historical physical escort validator explicitly disables cinematic transfers and no longer writes a report.

In-game: enter DistrictPolice and commit a witnessed theft or assault near a living officer. Keep a weapon drawn/attack to resist; stow and stop attacking to submit. After restraint, check station fade, booking, jail fade and locked-cell waiting. Confirm “3 days later,” morning release on the front porch, working WASD/camera and clock at 06:00. Repeat by fleeing or defeating the pursuing officer to check escape/abort.

The existing three road patrols now share this custody sequence with station police. New dispatch/reinforcement teams and persistence of an unfinished police case are not added; saving while wanted or detained is explicitly blocked. Close strike/wrist/cloth polish and whole-world controller play remain review tasks; passing phase checks are not final realism approval.

## Pursuit and release edges — 2026-10-08

Resuming pursuit after Arjun backs away now routes to the same side approach offset, instead of his exact body position. Moving-goal refresh is 0.25 seconds / 0.35 m, and finishing an outdated route replans instead of dropping the incident. The officer returns to approach animation state and clears the previous strike. An unsupported detention state, such as an open weapon wheel, waits at the approach point without expiring the chase timer; closing it permits arrest.

Focused headless and temporary Metal review PASS for backing away during resistance and resumed pursuit, maintained body spacing, incapacitated witness rejection, an open-wheel wait longer than the old timeout, closing-wheel arrest, officer incapacitation during a partial fade, and actual forward input after morning release. All temporary output is deleted. Whole-world play and final strike/cloth contact remain separate from these checks.

Additional in-game check: back away during police resistance, then stop and open the weapon wheel. Police should continue pursuing and then wait nearby; closing the wheel and stowing the weapon should allow arrest. After the 06:00 porch release, hold W and verify movement. Defeating the arresting officer during transfer should clear the screen and release controls safely.

## Combat contact and case logic — 2026-10-08

Police punch targets now lie on the near torso surface. Damage requires the palm to reach within 10 cm of that target and a clear ray; a blocked strike replans to the other approach side. The officer guards with the other hand and leans into the strike. Hits use Arjun's normal combat receiver, including frontal block reduction/stamina cost. A staggered officer stops attacking until recovery. These are gameplay contact checks, not skin-triangle or final clothing approval.

Assault events now pass the original attacker through the deferred callback, preventing later `last_attacker` changes from attributing the event to someone else. Unknown/NPC attackers do not implicate Arjun. Local witnessed incidents alert the existing road-police logic. Road theft requires a live nearby witness with visibility; remote fabricated theft is rejected. Police updates no longer depend on a surviving rescue NPC.

Road captures retain their four-Space escape window, then hand off to the cinematic station/jail/day-skip loop. Breaking restraint interrupts arrest but preserves pursuit until ordinary escape/search logic loses Arjun. Completing the sentence clears wanted/search/attack state; other patrols stand down while he is detained. External officers return to a clear porch point before resuming patrol. The station navigation grid now includes that porch.

SaveManager rejects saves during an outstanding police case or detention, before creating files. The save page explains the restriction; normal saving resumes after release and preserves the advanced morning clock. This avoids reloading a jail/chase position without its unfinished police state. The pause menu remains above the custody fade and opens the game-controls page while detained, so Resume/Quit are reachable even during full black.

Focused headless and temporary Metal review PASS: contact-based damage, wall obstruction, stagger and block/stamina behavior; explicit/deferred attacker identity; live/incapacitated theft witnesses; road capture handoff and completed sentence; escape retaining pursuit; no rescue-NPC dependency; blocked-save/no-write policy and actual save/read after release; save-page explanation; pause during opaque fade; and the existing custody/control-return checks. A reusable production-logic fixture uses the existing full MPFB station actors. All temporary saves, images and logs were deleted. Two ObjectDB exit warnings remain in headless review. Whole-world road travel/player acceptance and exact wrist/cloth motion remain open.

In-game checks: commit a witnessed theft or assault near a station or road officer. Face the officer and block to check reduced damage/stamina use; hit the officer to stagger, back away to resume pursuit, or press Space four times while initially caught to break restraint. Escape should not immediately pardon the case. Submitting to road capture should now use the same station/jail fades and three-day 06:00 porch release. Try Save during pursuit (explanation, no save) and after release (normal save). Press Esc during black transfer, then Resume; the menu should remain usable.

### Capture dependency recovery — 2026-10-08

Road capture now releases detention safely when its officer disappears or its station becomes unavailable. It retains the wanted case, resets surviving officer duty, and avoids reaching invalid nodes from capture contact rendering. Removed patrols are skipped by sensing and witness checks; loss of the player safely clears a pending escort.

The reusable custody check covers missing officer/station dependencies and a removed patrol alongside both complete custody loops, escape, blocked saving and morning release. Headless run PASS; temporary output deleted. Two ObjectDB exit warnings remain. Whole-world travel and wrist/clothing appearance remain unapproved.
