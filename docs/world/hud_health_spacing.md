# HUD health and spacing

2026-10-06 20:53 IST — COMPLETE, root.

Owner reference implemented: four solid survival symbols arranged as a diamond cross at bottom left, thin framed health bar alongside, circular nearby minimap at bottom right. Diamond interiors fill bottom-up from actual water, food, stamina and rest values. Fine aged-brass outer frames, ivory highlights and dark ink grounds match the existing historical UI. Removed large health blocks, panel and survival labels. Health follows actual player health, with a delayed damage trail and amber/red warning states. Ammunition sits above the radar; horse stamina above the survival cluster.

Changed: player/historical_hud.gd, player/circular_stat.gd, player/survival_hud.gd, player/minimap.gd, player/player.tscn. Existing survival signals and shared map/waypoint state remain integrated.

Native Apple M4 Metal verification:

- `/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/world/validate_hud_health.gd` — PASS: actual health, live survival signals, right-radar logical alignment, damage trail and healing. Log `/tmp/hud_health_review.log`.
- `tools/world/validate_hud_diamonds.gd` with the same Godot command — native PASS at 0, 1, 20, 50 and 100 percent, including zero-fill triangulation guard. Log `/tmp/hud_diamond_extremes.log`.
- Visually inspected full-world captures: [full health](captures/hud_health_100.png), [critical health](captures/hud_health_15.png). UI frames/icons and empty/filled portions remain readable; both corners have clear spacing. Captures use temporary low 3D quality in memory, preserving saved settings.
- Scoped `git diff --check` and `python3 tools/check_agent_docs.py` PASS.

Fixture corrections: assign actual survival values before emitting (the producer refreshes them); compare radar position with HUD logical width rather than Retina pixels; disable fixture input so desktop keystrokes cannot open the document overlay. Rejected obscured captures were replaced by the final gameplay views.

No remaining implementation blocker. Next: owner art review of the supplied native captures. This verifies this HUD change, not whole-game performance or every display aspect ratio.

Prior shared ledger history: ../agent/history/2026-10-06-handoff-before-ordered-completion-compaction.md.

2026-10-06 21:01 IST — COMPLETE: add live rupees rectangle below health, aligned width 140px with 11px gap, matching brass/ivory/ink and coin symbol. Changed historical_hud.gd and validator. Native payout/spend assertions PASS: +37 rupees followed by -12 updates the displayed balance to 25. No persistent save modified. Fresh full/critical captures above replaced prior screenshots and were inspected; money rectangle is readable and spaced beneath health. Log: /tmp/hud_money_review.log. The full-world Metal run logged one recovered fence timeout before the successful captures; this is not a clean whole-game performance result. No money-box blocker; next owner art review.

2026-10-06 IST — COMPLETE, root: owner requested no icon-to-amount gap. MoneyLabel now left-aligned at x199, exactly the coin outer edge (centre x192 + radius7), replacing the right-aligned amount. Same live balance and rectangle. Scoped diff/coordinate review passed; previous captures predate this text alignment adjustment. No additional full-world rerun for this alignment-only edit.
