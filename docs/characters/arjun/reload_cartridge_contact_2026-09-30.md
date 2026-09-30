# Enfield cartridge contact — 2026-09-30

The cartridge is now a Node3D placed explicitly after the arm/finger pose. The previous BoneAttachment3D overwrote the manually calculated transform during skeleton updates: the immediate palm check passed while rendered placement failed. The cartridge follows the midpoint of the left thumb/index second joints, with a small protrusion along the palm's finger axis. A partial finger curl replaces the fully open loading hand.

Validation: firearm gameplay check PASS; AnimationTree idle/walk/run/swim/sit entry/exit and long-gun envelope check PASS. Fresh Godot 4.7.2 Metal Forward+ close-up inspected: cartridge visible at the fingers. The capture asserts finger proximity after a forced draw, covering the deferred attachment failure even when another renderer window has focus. Evidence: `/tmp/tlm_enfield_cartridge_diagnostic.png`, `/tmp/tlm_enfield_reload_diagnostic.png`, `/tmp/tlm_adams_reload_diagnostic.png`. Subsequent muzzle-side palm/wrist and revolver outside-cylinder repairs, ammunition and station expansion: `docs/world/police_ammunition_2026-09-30.md`.

A pre-existing parser error in the seated boat pose referenced the climb-only `mantle_shift`; restored the seated height to -0.9 so the player script loads.

Open: normal-speed complete loading sequence, cartridge-to-muzzle orientation/contact, ramrod hand contact, accepted Arjun body, and final visual approval. The diagnostic continues to use the explicitly rejected runtime appearance. This is a contact repair, not character approval or a complete historically authored reload. The firearm fixture reports resource/instance cleanup warnings on exit.
