# Doubled population and street behaviour

Updated 2026-10-10. Implementation integrated; actual-world density/save/motion and native performance verification in progress.

The current city definition contains 94 civilians across 12 surveyed routes. Its multiplier now produces 188 civilian identities, 20 added police patrols and 16 traffic carts. Cart drivers and the existing passenger selection double with their vehicles. The first eight cart names and the original civilian save keys remain stable.

`PopulationExpansion` discovers each other original NPC's imported MakeHuman/MPFB model and registers one independently saved regional colleague using that complete export. It does not duplicate Arjun or story/service controllers. The additional household, civic, military, community, driver and story-group people travel between regional destinations; additional police register with the existing crime/pursuit/custody owner. Late-spawning humans are discovered through skeleton installation. Counterparts of departing roadside callers leave too, retaining their saved state for the identity's return. Original quest owners and complete bodies/foundations remain intact.

Street journeys accelerate, brake on arrival, turn gradually through small changes and turn in place for large reversals. Individual road-edge offsets vary gently between existing surveyed waypoints. Terrain support, slopes, whole-capsule sweeps and destination overlap checks reject unsafe movement. Bounded local detours handle obstacles. A shared world-local spatial index refreshes nearby neighbours at 4 Hz; traffic references refresh once per second. Walkers slow behind people, give the player space and yield before entering a cart's clearance area. Some continue directly to their destination; social residents can negotiate a short mutual roadside/market conversation, face one another and alternate speaking/listening gestures before returning to their journeys. These conversations are silent visual acting.

Both managers preserve distant identities as route records until approach. Logical updates retain night returns, destination pauses, health and incapacitation and now check real terrain/obstacle clearance without allocating human rigs. Materialised walkers retain collision at reduced cadence through `simulation_budget.gd`; nearby interaction/combat returns immediately to full cadence. Police preserve elapsed remote patrol movement and whole-capsule sweeps; pursuit/custody remain full rate. Spawn clearance is checked before allocating a new rig. AnimationTrees retain the existing walk-rate/idle/turn/combat branches and foot contact solver.

## Verification

- Production-rig physical crowd fixture PASS: mutual talk/listen, mission interruption releasing both participants, resumed destination movement, two swept detours past a thin wall, cart yielding/release and immediate approach wake.
- Logical budget/save fixture PASS: distance boundaries, essential bypass, elapsed progress, endpoint pause, roundtrip state and incapacitation, without allocating rigs.
- Full-world census/save/native frame checks remain open. Source/fixture checks do not establish final clothing, foot/hand contact, crowd density or FPS approval.

Repeat with `python3 tools/world/run_population_expansion.py --fixture`, `--budget`, or without an option for the actual world; add `--native` for 1280 × 720 native frame measurement and transient visual review. The runner deletes its temporary checkout, logs, saves and images in final cleanup, including interruption. No test outputs are retained.

In-game: finish the opening, observe the Bhairavpur market and road edges, then the administrative approach and western market. Watch opposite-direction passing, destination stops and short conversations; approach people after travelling away, drive a cart past walkers, then save/continue and check the same residents resume their destinations. The source-defined population includes logical people and late fort/roadside identities; an on-screen headcount is smaller.
