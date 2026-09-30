# Fictional Hooghly estuary port

Updated: 2026-09-30 21:25 IST. Status: IN_PROGRESS. Chat objective: continue the Suryagarh river downstream into a compact fictional British shipment harbour, with a large period cargo ship at berth, sea scenery extending beyond the playable area, and invisible physical limits for swimming. User follow-up explicitly adds a large ship Arjun can board and properly explore: main deck, forecastle, helm/poop, captain's cabin, below-deck hold and crew berths. Sailing a large vessel, cargo handling and new character roles are not requested actions in this milestone.

## Design and period basis

The south/downstream end of the current map widens into a fictional tidal Hooghly reach facing the Bay of Bengal. The Hooghly is a river/estuary; the location compresses the journey to the sea for gameplay. Working name: Hooghly Reach Port. It is not a reconstruction of a named real dock.

Use an original three-masted wooden merchant ship of approximately 1850s Blackwall/India trade character, moored with sails furled rather than travelling under full sail. Royal Museums Greenwich records the 1848 East Indiaman Trafalgar as registered for London–Calcutta: https://www.rmg.co.uk/collections/objects/rmgc-object-15144. The Aberdeen museum's 1854 Raphael record describes three masts, ship rig, one deck plus poop, fixed bowsprit and square stern: https://emuseum.aberdeencity.gov.uk/objects/99551/raphael. The National Army Museum's Hooghly shipping print provides contextual shipping evidence: https://collection.nam.ac.uk/detail.php?acc=1971-02-33-496-2. These support a period-inspired fictional merchant vessel, not exact replica dimensions or a certified historical model. No museum imagery is incorporated into project assets.

## Continuity

- Baseline read: root AGENTS.md, CODEX_HANDOFF.md, git status, landscape layout/runtime, terrain/map bake, water/swim and boat routes. Numerous unrelated dirty character, horse and village files are preserved.
- Existing landscape is 1728 m square; existing level water at y=0 and layout-height swimming can support the new estuary. Terrain, nature clearance, river surface, horizon and field map must share the same coast source.
- Completed: placement/design inspection and period research; continuous estuary/deep seabed/port terrace/approach added to `world/suryagarh/landscape_layout.gd`; scenic water extent in `tools/world/bake_landscape.gd`; original ship generator `tools/world/build_merchant_ship.py` including open stairs, cabin and hold.
- Verification pending. Next: author the confluence layout and independently reusable ship/port, integrate world, bake terrain/map, then exercise collision/swimming with actual player and inspect Metal port/ship/sea views.
- No current implementation blocker; concurrent source drift must be rechecked before baking.
