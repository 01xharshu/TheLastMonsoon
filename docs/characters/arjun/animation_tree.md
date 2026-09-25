# Arjun locomotion AnimationTree — 2026-09-25

`player/arjun_motion_tree.gd` builds a Godot AnimationTree from the gameplay GLB's idle, walk, swim idle, and swim forward clips. Ground and water each use a one-dimensional blend; a final blend moves between them. The clips loop in memory, and the baked Root position track is removed so the CharacterBody3D controls travel and collision.

`player/arjun_visual.gd` advances the tree manually from actual horizontal speed and swimming state. It keeps the existing procedural poses for prone, cover, river actions, climbing, riding, weapon grip, and attacks. Those systems still need visual tuning and transition review. The tree is a locomotion foundation, not a completed animation set or an approval of Arjun's rejected temporary appearance.

Focused check: `tools/characters/validate_arjun_motion_tree.gd` prints `ARJUN MOTION TREE: PASS` for idle/walk pose difference, water blending, and root track setup. An isolated player-scene launch also confirmed the tree is active. Full-world validation is currently blocked by parse errors in concurrently edited `world/suryagarh/landscape_layout.gd`; normal-speed Metal review of locomotion, foot contact, and transitions remains open.
