# Public passenger cart — 2026-10-10

The opening uses the existing village bullock cart as a public passenger service. Freight bundles are hidden, two bench rows carry two existing complete MakeHuman/MPFB residents, and two passenger sockets remain free for Arjun. Existing driver and human sources remain intact beneath clothing. The same fittings install when gameplay creates VillageBullockCart, including a skipped opening.

The driver announces “We’re in Bhairavpur. Mind your step!” with a bottom caption and a rigged head turn/nod. There is no floating text above the driver. During the cinematic, only the opening subtitle renders the line; nearby gameplay arrivals use a matching bottom caption. The opening camera follows the driver from seconds 8–13 before the wheel shot. The existing rig has no jaw bone; this is a speaking gesture, not lip sync. Dialogue lasts 4.2 real seconds and cancels at the cut or skip. No voice audio is included. Public boarding uses the existing destination/fare interface; fares are game currency.

An exterior iron plate, upright and bracket support the lantern outside the side rail. The lantern follows the cart, sways slightly while moving, and lights at night. Passenger foot targets use the deck height; boarding as a passenger retains the driver. Flexible reins pin to the visible driver's actual palms.

Verification: disposable clean import PASS. Native Metal fixture PASS, exit 0 in 17.7 seconds with no diagnostics: real passenger boarding animation completes, destinations appear, driver remains visible, speaking head pose changes, dialogue names Bhairavpur, and the exterior mount follows translation/rotation. Transient native review showed two seated passengers, driver, dialogue and exterior lantern. Integrated actual-world opening PASS, exit 0 in 40.1 seconds: passenger service, arrival subtitle, uninterrupted travel, fixed wheel camera after the driver shot, room handoff, dialogue cleanup and skip/restoration. Explicit scene teardown resolved the first fixture's shutdown timeout. No screenshots, recordings or logs are retained. Final cloth/contact and in-world appearance remain subject to play review.

Repeat with `python3 tools/world/run_city_population.py --passenger --native --opening`. For a transient review image, add `--review` in an interactive terminal; it deletes the image after Enter. In-game: F5 → New journey → watch the cart arrival without input; inspect the driver's gesture, passengers and outer lantern. Skip to gameplay, board a right-side public bench seat, and verify the destination menu and visible driver.

Caption-only correction native Metal review PASS (2026-10-10): dialogue renders at the bottom, with no world-space text above the driver. Existing speaking and boarding checks passed; exit 0 with no diagnostics. Temporary review image/project/user data deleted.


## Shared-budget continuation — 2026-10-10

Public cart setup now caches its own world's clock/player references and supplies the player to both passenger controllers. Passenger pose/contact work uses `systems/simulation_budget.gd`: full rate nearby, 0.1s at medium distance and 0.5s remotely, retaining accumulated time, seating, identity and collision. Boarding, cinematic use, missions and combat remain full rate; approaching immediately restores full updates. The exterior light activates only near the active camera or during the opening. Caption-only presentation is unchanged.

Actual-world native Medium (1280×720 maximum 3D budget) near → remote → approach → cinematic-remote measurement via `python3 tools/world/run_city_population.py --budget --native`. This prints frame-time samples and verifies tier restoration, seated contact and collision; no A/B speedup or whole-world FPS approval is implied.

Actual-world native result: passenger assertions PASS for cached references, retained collision, seated pelvis/socket contact and all four tiers. Per 48 rendered frames, pose updates were 384 near, 12 remote, 368 on approach and 352 during a remote cinematic. Actual output was 3600×2260 at scale 0.318584 (approximately 1147×720 3D pixels). Median/p95 milliseconds: near 421.731/12362.701; remote 174.909/243.232; approach 293.758/313.108; cinematic-remote 172.536/220.358. Views/content differ, so these are diagnostics, not an A/B speedup.

The overall native gate FAILED despite those functional assertions: four Metal fence timeouts at coachman_seated_cloth.gd:30 and 39 freed-instance discovery errors. The latter typed-Node queue issue was already corrected to Variant in the shared checkout after the test snapshot. The Metal clothing readback issue was handed to its existing performance owner. No 30-FPS/whole-world acceptance. Temporary outputs removed; clean isolated native passenger follow-up PASS (exit 0, 15.4s, no diagnostics): cached references, remote cadence, seating during cart motion, immediate approach/cinematic restoration, retained collision, caption-only speech and completed boarding/destination menu. Transient native review showed the same seated passengers, driver and exterior lamp; all outputs deleted.

## Open shared cart and selected wheel tracks — 2026-11-06

Bhairavpur's shared bullock cart has two rows of bare plank seats, slatted backs, open handrails and an exterior oil lamp. The public boarding prompt identifies it as a shared bullock cart. The open body and visible passengers establish the visual contrast with the enclosed household coaches reserved by the existing booking rules. The two-ox team and front driver draw on [Narayan Dajee's 1855 Gujarat photograph](https://www.rct.uk/group/381/content/collections/photographs-collection/photographs-1842-61/a-travelling-bullock-cart). The open two-row layout is an adaptation of the gameplay references.

The western stretch of Bhairavpur's main lane near the parked cart uses a pair of worn wheel lines and a broken green strip between them. Suryagarh's market street has overlapping wheel lines and damp patches. Both treatments use the existing terrain material and road mask. They are surface details, with the existing terrain support and route geometry underneath.

In-game, start a New Journey to see the shared cart during arrival. After the tutorial, look for **Board shared bullock cart** at the two right-side seats by the west end of Bhairavpur. The wheel lines run along the main lane east of the cart. For the busier road treatment, visit Suryagarh's east–west market street.

### Populated road and seated contact follow-up

The western stretch of the village spine fades its existing earth ribbon over the terrain tracks. The market street uses the terrain surface in place of its old decorative stone ribbon. Native populated views showed the village wheel pair and green center and the market's overlapping tracks beside the stalls.

Side treads now support Arjun's existing transfer foot target ahead of the wheels. He turns toward the rail to step up or down and turns forward as he settles into the seat. The bench backs sit farther behind the occupants for clothing clearance. The shorter front passenger uses a closer ankle target to keep both feet on the deck with a bent knee. In the focused test both NPCs held the pelvis and ankle targets within 1 mm during 90 translating and turning samples. The native review covered boarding, seated movement from both sides, and exit. Existing outfit deformation remains stylized in close views.

Repeat the focused checks with `python3 tools/world/run_tutorial_guard_check.py --checks validate_public_passenger_cart` or add `--native` for the renderer. In game, board from the right at the village's west end, watch the side step, select a destination, and dismount after stopping.
