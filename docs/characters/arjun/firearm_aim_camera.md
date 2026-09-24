# Firearm aiming camera and sight

2026-09-24: Third-person camera rests at 3.35 m (from 4 m). RMB/controller aim eases to a right shoulder camera at 1.65 m for Enfield or 1.35 m for Adams, with narrower field of view. First-person mode keeps its own camera. A short original synthetic click plays as aiming begins; existing shot/reload audio remains.

The HUD draws different rifle and pistol sights. The camera center ray tightens and changes the sight colour when its first collision belongs to a node in the `human_npcs` group (including an ancestor). Human NPC scenes need collision and this group for recognition. Current British/village visual studies do not provide a verified live combat NPC target, so target response and shoulder/hand framing still require a fresh Forward+/Metal play review with a suitable NPC. Arjun's current body is owner-rejected, so hand visibility and contact cannot be approved on that body.

Verification: Godot 4.7.2 editor import completed; `tools/weapons/validate_live_weapon_controls.gd` reported `LIVE WEAPONS: PASS`. This checks combat function, not rendered camera composition or sound balance.
