# City route population

IN_PROGRESS / 2026-10-08 23:03 IST / root. User reports sparse pedestrians, police and carts on city routes. Add populated routes using existing MPFB actors, live police observer/pursuit/custody AI and real boardable vehicles. Preserve previous clothing task and concurrent world/vehicle changes. Implementation and world verification next; no density/performance/art approval yet.

Implemented additive manager:72 pedestrians across9 existing surveyed route areas,10 additional officers registered with existing CombatEncounters patrol/witness/pursuit/custody logic,8 boardable ox carts/family carriages on long road sections. Walkers phase-spaced in opposing directions on road edges; setup staggered .06s, distant cadence .5s and mesh range190m. Cart clearance/grounding/player takeover retained plus rear-spacing stop. New files city_route_population.gd, city_street_journey.gd, city_cart_journey.gd; one additive install line in existing dirty world script. Parser checks PASS; actual full-world16s movement validation running.


## Movement repair — 2026-10-10

Terrain support now follows the actual ground on each pedestrian step; collision sweeps retain buildings, trees, vehicles and people. Bounded, swept lateral detours let walkers pass obstructions on surveyed roads. City carts choose a clear parallel lane at placement, resolving the Government House wall overlap; movement still uses normal clearance, terrain checks, traffic spacing and player takeover.

A disposable clean-import, actual-world headless check passed: 72/72 walkers across all nine route areas, 8/8 carts and 9/10 police patrols made progress over 16 simulated seconds. No blocked walkers or stopped carts were reported. The validator now requires every added walker and cart to progress. An earlier run under concurrent import/render load timed out while spawning; the sequential repeat passed. This is functional movement evidence, not approval of FPS, clothing, contact or long-term U-turn behavior.

Repeat with `python3 tools/world/run_city_population.py`; add `--native` for normal native timing. Test snapshots, logs and user data are automatically deleted. In-game: finish or skip the opening, then observe both directions on the village market road, Government House road and administrative approach; board a free seat and verify traffic yields to player use.

Native Metal actual-world repeat also PASS (177.1 wall seconds, exit 0, no Godot diagnostics): 72/72 walkers, 8/8 carts and 9/10 police, with zero blocked walkers/stopped carts. Transient review showed the Government House cart clear of the boundary wall. Unrelated household `leave_home` journeys logged EntranceDoor blocks for OfficialMan, OfficialWoman and MerchantHouseholdMerchant; handed to the existing household owner, and not counted as repaired by this traffic pass. Final FPS/contact/long-route review remains open.
