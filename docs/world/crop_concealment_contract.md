# Crop concealment — 2026-10-05

Field owners register an existing Node3D in `crop_concealment` and give it `crop_cover` metadata: a Dictionary with `bounds` (Rect2 in local X/Z metres), `height` (metres above the field), and `density` (0–1). Values must describe the rendered plants. Existing `bhairavpur_garden` nodes default to an 8 × 4.4 m rectangle, 0.55 m height and 0.10 density; these short sparse plants offer only slight prone concealment.

`player/crop_concealment.gd` reduces concealment outside the bounds, at edges, for close observers, and for elevated observers. Standing above the plants gives no concealment. `StealthStance` caches at most 32 nearest field nodes once per second. Patrol sight uses the resulting range and actual stance eye position, while retaining solid geometry line-of-sight checks. Plants do not grant absolute invisibility. No per-blade collision or new human geometry is introduced.

Validation: `tools/world/validate_crop_concealment.gd` passes posture, bounds, close sight, elevation, edges and sparse low plants. Full-world `validate_stealth_stance.gd` passes stance checks; native field escape, crouch motion and patrol reaction review remain open. Tall cultivated fields require field-owner geometry and metadata; no tall crop has been invented here.

Tatya Tope is the confirmed future escape-story identity. The precise episode, date and route remain pending historical research and story alignment.
