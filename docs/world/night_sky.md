# Moon and stars — 2026-10-07

Sun controller now installs a shared day/night sky shader: small warm moon disc with subtle surface variation and soft halo, sparse fixed stars, horizon attenuation and continuous dusk/dawn fading. Moon direction follows the existing moon light; daytime sky gradients and sun disc remain clock-driven. No extra scene objects or light sources.

Focused native Metal/Forward+ review on Apple M4 showed moon and stars at 22:00. Reusable validator printed NIGHT SKY PASS for moon above horizon, full night visibility and noon fade; clean exit. Temporary image removed. This is focused rendering evidence; full-world fog/exposure, dusk/dawn traversal and total performance remain unverified. The moon uses a fixed full-disc appearance rather than a lunar-calendar simulation.

Test in game: restart Suryagarh, wait for night or sleep to a nighttime hour, go outside into an open field and look around the upper sky. The moon travels with the clock; stars fade near the horizon and with sunrise. Reusable check: Godot --path . --script tools/world/validate_night_sky.gd.

## Clock logic verification — 2026-10-08

Expanded native Metal validator PASS: all 24 hourly light/visibility states, above-horizon moon during deep night, immediate large forward/backward clock jumps, equivalent midnight direction across day wrap and unchanged lighting state with a stopped clock. Two ObjectDB exit warnings remain unresolved. These checks do not establish full-world exposure or historical lunar-calendar accuracy.

## Exit verification — 2026-10-09

The focused validator now stops audio and waits for backend retirement. Current headless night-sky check passes with a clean exit. Full-world route verification uses the actual world environment and a camera at player eye height; it is separate from focused shader/clock verification.

## Full-world rendering — 2026-10-09

Actual Suryagarh scene loaded in native Metal/Forward+ on Apple M4. At 22:00, the eye-height review camera showed a visible moon, soft halo and sparse stars with the world's fog/exposure active; birds were hidden. Native full-world route exited cleanly. This checks world integration and rendered visibility; uninterrupted player-controlled dusk/dawn travel and target-device performance remain separate gates. Earlier body-obstructed fixture images were rejected and the camera setup corrected. Temporary images are discarded after inspection.

## Main-game integration — 2026-10-09

Configured title-menu startup and its real journey callback verified. Headless actual-world integration printed MAIN SKY INTEGRATION PASS for both New Journey and Continue with an existing save; exit 0, no reported script errors or ObjectDB leaks. Both routes instantiate the 60-bird system and use the world's GameTimeSystem; WorldEnvironment uses the moon/star shader installed by Sun. Restored-clock activity/visibility checked after Continue. No saves written or captures retained. Reusable check: Godot --headless --path . --script tools/world/validate_main_sky_integration.gd. Native rendering evidence remains recorded separately above.
