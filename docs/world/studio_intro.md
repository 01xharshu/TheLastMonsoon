# HeyaHarshu Creative Studio startup ident

2026-10-09: `project.godot` opens `ui/studio_intro.tscn`, then the existing `ui/main_menu.tscn`. Returning from gameplay goes directly to the menu. No gameplay or loading scene ownership changed.

Revised after the first restrained serif/card direction was rejected: custom angular twin-H metal monogram, converging outlines, slow camera settle, travelling highlight, seam flare, expanding atmospheric pulse and short-lived sparks. Bold modern studio wordmark, spaced Creative Studio credit and `visit: heyaharshu.vercel.app`. Native canvas geometry and `ui/studio_atmosphere.gdshader` stay sharp across resolutions. System sans font uses Arial/Helvetica with engine fallback; typography may vary on mobile. The original synthesized audio signature adds a soft riser, low impact and decaying chord, with no external recording dependency.

Timing: logo resolves around 2.35 seconds; name follows; website appears from 3.4 seconds. At 7.8 seconds it fades into the existing menu. Space/Enter/Escape, controller A/B/Start, left click and touch skip after a brief input guard. Repeated activation is ignored and mouse visibility is restored. This implementation is an in-engine ident, not a rendered video.

Verification: native Metal timed startup and simulated keyboard/controller/touch/mouse skip routes; headless menu integration including actual gameplay-return callback. Revised reveal stages visually inspected at 800×600 and final composition at widescreen. These checks establish rendering and routing, not user art approval, physical device input approval or listening approval. Temporary captures and test scripts removed; reusable check is `tools/world/validate_studio_intro.gd`.

Review: F5, watch the complete intro with speakers/headphones, then restart and try Space or tap to skip. Confirm the normal title appears. In gameplay, return to Main Menu; the ident should not replay. Existing exported applications need rebuilding to include this change.
