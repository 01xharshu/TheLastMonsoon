# Dev inquiry — morning, refusal and guarded chamber

2026-10-09. Playable narrative candidate. New conversations are subtitles only; no dialogue voice assets are added. Continuous expressions, acting, costume, firearm contact and historical/owner approval remain open.

## Main sequence

The live new-game opening retains its night lighting and morning stand-up. `OpeningSequence._release()` starts `DevInquiry` only when control returns to Arjun. The objective reads **Find Dev · Ask at the police station** and has a distance/direction marker. The field map also lists the current inquiry destination, derived from the real station interaction point. The controller remains dormant during the opening and morning seat.

At the station, Arjun asks about his missing sepoy brother. The station officer gives no useful answer. Arjun asks for the superior and is referred to the west ground-floor chamber. The objective changes to that chamber; its interaction remains unavailable before the initial inquiry.

The chamber contains the district officer and two additional officials. They ridicule Dev and dismiss Arjun's concern. Arjun calls out their humiliation: **You know nothing about him. Do not dishonour my brother to amuse yourselves.** The district officer orders soldiers inside and has Arjun taken away. The mockery is fictional narrative abuse by these characters; it establishes neither Dev's location nor his fate.

Four additional guards use existing complete MakeHuman/MPFB British private exports: two on the entrance porch and two in the corridor outside the west chamber. They carry the shared Enfield asset. The two corridor soldiers receive separate collision-aware ground-floor paths and walk through the actual doorway to opposite sides of Arjun. They must both arrive before the existing station detention controller accepts the story order. The firearm moves to a carried-back pose when the guard needs his hands for custody.

The current punishment reuses the existing detention/booking/cell/time-passage/release sequence and its default three-day sentence. This duration is inherited gameplay tuning, not a new historical claim or a fixed narrative decision. The reason is `story_order`, separate from a witnessed theft/assault. Release completes this story beat and leaves Arjun free to explore for another lead.

## Optional Chacha encounter

Chacha remains an independent, temporary exploration encounter. Arjun can meet him at his house before or after the police inquiry; neither his advice nor collecting his weapons is required to unlock the main sequence. He first asks about Dev, listens to Arjun, expresses concern and gives his weapons/escape advice. See [Chacha's house](chacha_house.md). Walking away stops the optional conversation and restores Arjun's temporary expression meshes.

## Expressions, control and persistence

Speaker-labelled timed subtitles cover both conversations. Concern, disdain and anger use small additive face-region deltas on duplicated runtime MPFB meshes; vertices, indices, skin data, full body and source exports are retained. Chacha has concern and a speaking/listening arm blend. The chamber officials have a small head attitude and open-hand speech gesture. Arjun shifts from concern to anger at his objection. These are restrained acting candidates, not phoneme lip sync or approved performances.

The inquiry temporarily contains player movement during dialogue and restores the previous physics/interaction state on completion or cancellation. Unavailable officials/guards, death or a blocked summons cancel safely. Story progress persists through the existing save system. Saving during a conversation/summons is refused; existing police rules cover custody. A loaded completed beat does not repeat the punishment.

Production files: `story/dev_inquiry.gd`, `dev_inquiry_prompt.gd`, `dev_inquiry_official.gd`, `dev_inquiry_guard.gd`, `dialogue_expression.gd`; small startup, morning-release and save integrations. Existing office geometry, civilian thana staff, crime rules and unrelated asset owners are preserved.

## Review and limits

Start a **new game**, allow/skip the night opening, then stand up in the morning. Follow the police inquiry marker and interact with the officer. Follow the referral to the west chamber and interact again. Watch all three officials, Arjun's response and the two soldiers entering. After custody, verify control returns. Visit Chacha independently and confirm his encounter changes no main objective.

`tools/world/validate_dev_inquiry.gd` uses the real station, player, officials, soldier collision routes and detention controller. It covers order, roster, expressions, both soldier arrivals, punishment/release and isolated save/load. Provide an OS temporary directory with `TLM_INQUIRY_SAVE_DIR` and remove it in the runner's finally block. `tools/world/review_dev_inquiry.gd` exercises the real opening/morning handoff and normal station/chamber controller route; native views require `TLM_INQUIRY_REVIEW_DIR` in OS temporary storage and caller cleanup after inspection.

Focused inquiry and Chacha checks passed. The native full-world review confirmed the morning objective and multiple guard placement, but concurrent river-cloth blend-shape errors flooded that run. A test-only `TLM_INQUIRY_ISOLATE_RIVER=1` option pauses that unrelated routine in the review fixture; it does not change production source and cannot close clean whole-world approval. Fine face/finger contact, continuous acting, all-world stability and constrained-hardware performance remain distinct gates. No generated test images, logs, saves or reports are retained. Two ObjectDB instances are intermittently reported at focused-test shutdown.
