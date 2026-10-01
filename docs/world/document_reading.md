# Wall notices and Arjun's record
Updated: 2026-10-01 IST

## Period and scope
Suryagarh is fictional north India in 1857. The [National Archives teaching source](https://cdn.nationalarchives.gov.uk/documents/education/india1857.pdf) reproduces the Calcutta Gazette's 16 May 1857 proclamation. [Rajiv Gandhi University's history course](https://rgu.ac.in/wp-content/uploads/2023/05/MAHIS-505.pdf) describes a seditious poster pasted on Delhi walls before the uprising. These support printed proclamations and posted notices as period categories. Our English market/road wording, local placements, and removable/reposted paper are original gameplay interpretations, not facsimiles or proof of exact local practice. No modern photographic wanted-poster template is introduced.

## Behavior
- O opens Arjun's record with an unroll motion. O, Escape, or controller B closes it with a roll-up.
- E on the town hall or police facade sheet reaches, detaches and lifts the paper; closing returns and presses it back. These are reusable news notices, not an implemented wanted/bounty progression system.
- Both hands follow paper edge targets after locomotion. Weapons stow for reading and restore on completion. Recovery retains a modal input lock, preventing overlapping documents or premature movement.
- Opening is blocked during incompatible map/inventory/weapon-wheel, mounted, climbing, rest, river, low-stance, first-person or dead states.
- Six reusable cards show identity, live fame/recognition, stamina, actually owned weapons, actual health/injury and the current notice. Wide screens leave room for the character; narrow screens use a scrollable single column.
- Reuse meshes, materials and UI nodes. Draw parchment only during transition/resize; poll data at 4 Hz and replace label content only when its snapshot changes. Document motion processing stops while inactive. This is a local efficiency change, not an 8 GB full-world performance certification.

## Evidence and remaining gates
Validator: tools/world/validate_document_reading.gd runs in the actual Suryagarh scene with a bounded watchdog.
Captures: docs/world/captures/document_{unroll,cards,wall_lift,notice_cards,hand_contact,repost,narrow}.png.
Functional checks cover six cards, physical prop visibility, temporary wall removal, repost, modal recovery, equipment restoration, unchanged fame, no settled parchment redraw, and narrow layout.
Final Metal/Forward+ world pass: DOCUMENT READING: PASS. Both reading palms measured 0 m gap to their paper edge targets. Wrist basis is explicitly aligned with the paper, elbow poles are transformed into rig space, and the reading height follows the shoulders. Inspected fresh lift, settled contact, close/recovery and responsive card captures. These contact measurements do not certify the entire transition or final hand anatomy.
The rejected pale text cards were replaced with dark ink cards, category illustrations, prominent values, compact details, and stamina/health bars. All six fit in the 1280×720 wide-screen capture; 800×600 uses a scrollable single column.
Normal-speed preview: docs/world/captures/document_scroll_motion.mp4. Frames were timed with actual capture timestamps (7.6 seconds) rather than assigned a faster playback rate. The sequence uses a staged close camera in the full Suryagarh world; it is not manual player-control acceptance.
Existing full-world errors: FortCook/FortSteward missing imported skeletons, also recorded in the handoff. They are not caused by these scripts.
Owner acceptance of the revised card design, natural finger/cloth detail, and continuous manual-play contact remain open. No production acceptance or full-world frame-rate certification is implied.
