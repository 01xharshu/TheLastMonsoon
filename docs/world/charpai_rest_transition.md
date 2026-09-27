# Charpai rest transition

`objects/charpai.gd` now locks interaction and movement, stows the selected weapon, places Arjun at the charpai, animates a seated-to-reclining pose, fades to black, advances the shared world clock eight hours while fully covered, restores energy, fades back in, rises, and returns control. Repeated interaction is blocked until the sequence ends. The game clock and survival systems still receive the normal `advance_hours` event.

`tools/world/validate_charpai.gd` passed in Forward+/Metal on 2026-09-27. It checks the four charpai feet, bed collision, that time does not jump during the first second of pose motion, the eight-hour change after fade-out, energy restoration, and the release of control. Captures: `captures/charpai_sitting.png` and `captures/charpai_sleeping.png`.

Visual review is **not approved**: the seated figure is still somewhat high, and the reclined pose leaves a hand below the woven surface and one leg raised. The procedural pose and bed pivot need an authored sit/lie clip or rig-space contact correction, followed by full-motion capture and a player-driven entry/wake review. The currently rejected Arjun runtime body also blocks final character approval. The logic PASS does not certify contact or animation quality.
