# Day cycle, stamina and fruit

Implemented 2026-09-23. Suryagarh and the test world use 2.4 game minutes per real second: 600 real seconds per 24 game hours. Suryagarh's duplicate clock, sun, moon and environment were removed. The remaining sun controller drives sun/moon direction and intensity plus procedural sky, ambient light and fog, including twilight. Clock pause and explicit sleep/time skips remain supported.

Sprint drains 5 stamina per real second (20 seconds from 100 to empty), independently of the accelerated world clock. Walking/rest recover 10 per second; exhaustion clears at 25. Food, hydration and energy retain their existing game-hour rates.

Two mango trees and ten collectible fallen mangoes are beside the Bhairavpur approach, near (-240, 176) and (-246, 186). Fallen fruit snaps to baked terrain collision. Within 2.6 metres, face fruit to see E / Shift+E prompts. Third-person follows body facing; first-person follows horizontal camera facing. Occlusion blocks interaction. E stores one mango, Shift+E eats it directly, and the Satchel has an Eat mango row. A mango restores 12 food and 6 hydration. Eating when both stats are full preserves the fruit. Collection is guarded against repeated input before deletion.

## Evidence

Run `/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/world/validate_day_survival_forage.gd`.

- `day_survival_forage_validation.json`: exact day rollover/pause, noon/night lights, sprint duration/recovery, facing/range/occlusion, one-shot collection, satchel eating, direct eating and full-stat rejection.
- `captures/forage_12.png`, `forage_18.png`, `forage_0.png`: rendered daylight/twilight/night using Forward+/Metal, visually inspected.
- `captures/forage_prompt.png`: rendered third-person pickup/eat prompt, visually inspected.

Fruit uses a simple procedural mesh. These checks establish functionality and observed lighting/prompt appearance; they do not approve final fruit art or hand-contact/picking/eating animation. The existing tree model's decorative fruit is not individually harvestable. Collected fruit does not yet respawn.
