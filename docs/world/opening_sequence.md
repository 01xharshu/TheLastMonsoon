# Arjun's opening — first playable cinematic

Updated: 2026-09-30 IST. Functional prototype; final animation, audio, historical prop detail and owner approval remain open.

Play Game creates the live opening through `SaveManager.apply_pending` only for a new game. Continue/load and direct world review retain their existing routes. The scene reuses Arjun and Dev's surveyed house, existing character, AnimationTree and charpai. No video playback is involved.

The approximately 32-second timeline starts dark, reveals a hand-held match and warm oil-wick lantern light, moves Arjun to the open sleeping-room window, displays “Still no word from Dev…”, then returns him to the charpai and fades through the night. The shared clock moves from 22:00 on day one to 06:00 on day two. Arjun remains seated until a fresh keyboard, mouse or controller button press triggers his stand-up transition; movement and interactions resume afterward. Space and Escape skip to that same morning seat, with an idempotent clock change and no automatic second action from the skip press.

Normal gameplay CanvasLayers and gameplay input are hidden/locked throughout the opening. Black top and bottom bars occupy 12% of viewport height each; captions are vertically centered in the lower bar. There are no visible skip controls, buttons or permanent instructional prompts. The bars retract during the morning fade. The regular interface returns when Arjun stands.

## Historical basis

Friction matches existed before the game's 1856–1859 period. The [Science Museum's John Walker record](https://collection.sciencemuseumgroup.org.uk/people/ap25353) dates commercial sales to April 1827; its [day-book record](https://collection.sciencemuseumgroup.org.uk/objects/co8077012/the-day-book-of-john-walker) records sales in 1827–1829. This establishes chronological availability, not routine ownership in a specific Bengal village. Arjun's access to a purchased/imported supply remains a story inference requiring local trade evidence. No modern brand or safety-match packaging is shown.

The lantern is an original framed candidate around the existing oil-wick burner. Its construction is a blockout, not an authenticated period artefact. A final lantern needs glass, door, ventilation, handle, joinery and fuel review.

## Verification and open work

2026-09-30: full normal-speed Forward+/Metal run completed with explicit `OPENING SEQUENCE: PASS`; log `/tmp/tlm_opening_realtime.log`. Fresh dark, lantern, window/caption and morning frames were inspected. The checks establish timeline/input/UI behavior; they do not approve the outstanding acting/contact work.

Validator: `tools/world/validate_opening.gd`. `TLM_OPENING_REALTIME=1` runs the full timeline without seeking; ordinary mode samples beats quickly. It covers the real new-game integration, hidden HUD, bars/caption placement, open window, natural morning completion, both skip keys, repeated skip safety, fresh W stand-up and restored movement/rest locks. Metal evidence is in `captures/opening_00.png`, `opening_03.png`, `opening_06.png`, `opening_11.png`, `opening_16.png`, `opening_22.png`, `opening_27.png` and `opening_morning.png`.

The gesture, walking staging and reclining still require authored contact refinement. The current match gesture does not accurately bring the match tip to the wick; fingers do not yet grip it convincingly. The lantern starts on its table rather than being carried and placed. The waiting line has captions but no recorded speech; an audible sigh, match strike, room ambience and lip/facial animation are not implemented. Camera shots are staged cuts; continuous human review and player traversal out of the house remain open. Existing FortCook/FortSteward missing-skeleton errors appear during world startup and are unrelated to this sequence. Structural PASS does not approve character likeness, cinematic quality, contact or production readiness.

Next: author the match strike / wick contact / extinguish and lantern set-down on the selected rig; add voiced Dev line, sigh and period room sound; refine gaze and shoulders; review continuous Metal playback, morning camera and actual doorway/gate traversal.
