# Arjun's opening — first playable cinematic

Updated: 2026-10-01 IST. Functional prototype; final animation, audio, historical prop detail and owner approval remain open.

Play Game creates the live opening through `SaveManager.apply_pending` only for a new game. Continue/load and direct world review retain their existing routes. The scene reuses Arjun and Dev's surveyed house, existing character, AnimationTree and charpai. No video playback is involved.

The approximately 32-second timeline starts dark, reveals a hand-held match and warm oil-wick lantern light, moves Arjun to the open sleeping-room window, displays “Still no word from Dev…”, then returns him to the charpai and fades through the night. The shared clock moves from 22:00 on day one to 06:00 on day two. Arjun remains seated until a fresh keyboard, mouse or controller button press triggers his stand-up transition; movement and interactions resume afterward. Space and Escape skip to that same morning seat, with an idempotent clock change and no automatic second action from the skip press.

Normal gameplay CanvasLayers and gameplay input are hidden/locked throughout the opening. Black top and bottom bars occupy 12% of viewport height each; captions are vertically centered in the lower bar. There are no visible skip controls, buttons or permanent instructional prompts. The bars retract during the morning fade. The regular interface returns when Arjun stands.

## Interior window performance — 2026-10-01

The camera stays in the house and frames Arjun beside the front sleeping-room window. The former separate view down the approach is removed. A restrained inward brow lift and mouth-corner drop develop as he waits. He murmurs “Still no word from Dev…”, lowers his gaze, gives a small torso sigh, turns away gradually, and walks around the lantern table to the charpai. The camera moves gently within the room as he leaves the window; no normal HUD or skip buttons appear, and the caption remains in the lower black bar.

`story/opening_expression.gd` adds temporary sadness and murmuring shapes to duplicated runtime body/eyebrow meshes. It preserves source geometry, skin arrays and surface materials; morning/skip restores the original meshes. The original `characters/arjun/arjun.glb` is untouched. This is a restrained acting candidate, not final likeness or facial-animation approval.

The quiet 1.607-second line is a synthetic placeholder produced locally with macOS's Rishi voice, rate 125, from the original English dialogue. Asset: `assets/audio/opening/arjun_murmur_draft.wav`. It plays from Arjun near the caption cue at reduced volume; skip stops it immediately. The mouth motion is an approximate speech envelope, not phoneme lip sync. Replace with a directed, recorded performance and refine expression/contact before final cinematic approval. The sigh is currently a body gesture; an audible breath and complete period room sound remain open.

The approximately 175 m terrain-following approach remains in the world. Its previous 20/40/80 m clear sightline checks are historical evidence in `opening_approach_validation.json`; the old road-view insert is superseded by this interior performance.

`tools/world/capture_opening_approach.gd` now captures interior beats at 14, 16, 19, 21.5 and 23.5 seconds, with live skip input and timeline advance disabled for exact framing. It asserts that the camera remains inside the front/side room walls. Evidence: `captures/opening_interior_14.png`, `opening_interior_16.png`, `opening_interior_19.png`, `opening_interior_21.png`, `opening_interior_23.png`. Precise staged frames and containment checks do not replace continuous acting review.

## Historical basis

Friction matches existed before the game's 1856–1859 period. The [Science Museum's John Walker record](https://collection.sciencemuseumgroup.org.uk/people/ap25353) dates commercial sales to April 1827; its [day-book record](https://collection.sciencemuseumgroup.org.uk/objects/co8077012/the-day-book-of-john-walker) records sales in 1827–1829. This establishes chronological availability, not routine ownership in a specific Bengal village. Arjun's access to a purchased/imported supply remains a story inference requiring local trade evidence. No modern brand or safety-match packaging is shown.

The lantern is an original framed candidate around the existing oil-wick burner. Its construction is a blockout, not an authenticated period artefact. A final lantern needs glass, door, ventilation, handle, joinery and fuel review.

## Verification and open work

2026-10-01: the revised interior performance completed a full normal-speed Godot 4.7.2 Forward+/Metal run with explicit `OPENING SEQUENCE: PASS`, exit 0 and no script errors in `/tmp/tlm_opening_acting_verified.log`. Camera containment was checked continuously during seconds 13–24. Natural completion, both skip keys, fresh W stand-up, control release, voice stop and original facial-mesh restoration passed. The fresh normal-playback `captures/opening_16.png` was inspected for face/window framing and lower-bar caption. Staged interior captures separately passed containment at all five beats. These checks establish behavior and current framing; final acting, audio and contact acceptance remain open.

2026-09-30: full normal-speed Forward+/Metal run completed with explicit `OPENING SEQUENCE: PASS`; log `/tmp/tlm_opening_realtime.log`. Fresh dark, lantern, window/caption and morning frames were inspected. The checks establish timeline/input/UI behavior; they do not approve the outstanding acting/contact work.

Validator: `tools/world/validate_opening.gd`. `TLM_OPENING_REALTIME=1` runs the full timeline without seeking; ordinary mode samples beats quickly. It covers the real new-game integration, hidden HUD, bars/caption placement, open window, natural morning completion, both skip keys, repeated skip safety, fresh W stand-up and restored movement/rest locks. Metal evidence is in `captures/opening_00.png`, `opening_03.png`, `opening_06.png`, `opening_11.png`, `opening_16.png`, `opening_22.png`, `opening_27.png` and `opening_morning.png`.

The gesture, walking staging and reclining still require authored contact refinement. The current match gesture does not accurately bring the match tip to the wick; fingers do not yet grip it convincingly. The lantern starts on its table rather than being carried and placed. A synthetic spoken line and additive facial/body acting are implemented as drafts; final recorded speech, an audible sigh, match strike, room ambience and authored lip sync remain open. The window camera stays inside; continuous human review and player traversal out of the house remain open. Existing FortCook/FortSteward missing-skeleton errors appear during world startup and are unrelated to this sequence. Structural PASS does not approve character likeness, cinematic quality, contact or production readiness.

Next: author the match strike / wick contact / extinguish and lantern set-down on the selected rig; replace the synthetic Dev line with a recorded performance, add sigh and period room sound; refine gaze, facial shapes and shoulders; review continuous Metal playback, morning camera and actual doorway/gate traversal.
