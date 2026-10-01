# Fictional Hooghly estuary port

Updated: 2026-10-01 IST. Status: COMPLETE (playable port and explorable moored ship; final art review open). Chat objective: continue the Suryagarh river downstream into a compact fictional British shipment harbour, with a large period cargo ship at berth, sea scenery extending beyond the playable area, and invisible physical limits for swimming. User follow-up explicitly adds a large ship Arjun can board and properly explore: main deck, forecastle, helm/poop, captain's cabin, below-deck hold and crew berths. Sailing a large vessel, cargo handling and new character roles are not requested actions in this milestone.

## Design and period basis

The south/downstream end of the current map widens into a fictional tidal Hooghly reach facing the Bay of Bengal. The Hooghly is a river/estuary; the location compresses the journey to the sea for gameplay. Working name: Hooghly Reach Port. It is not a reconstruction of a named real dock.

Use an original three-masted wooden merchant ship of approximately 1850s Blackwall/India trade character, moored with sails furled rather than travelling under full sail. Royal Museums Greenwich records the 1848 East Indiaman Trafalgar as registered for London–Calcutta: https://www.rmg.co.uk/collections/objects/rmgc-object-15144. The Aberdeen museum's 1854 Raphael record describes three masts, ship rig, one deck plus poop, fixed bowsprit and square stern: https://emuseum.aberdeencity.gov.uk/objects/99551/raphael. The National Army Museum's Hooghly shipping print provides contextual shipping evidence: https://collection.nam.ac.uk/detail.php?acc=1971-02-33-496-2. These support a period-inspired fictional merchant vessel, not exact replica dimensions or a certified historical model. No museum imagery is incorporated into project assets.

## Implemented

- Continuous downstream estuary, deep channel, compact playable sea and graded port approach. Native terrain, horizon, nature clearance and field map were rebaked from the same layout.
- Original 51 m wooden three-masted merchant ship MERCY, 11.8 m beam, with furled sails, rigging, bowsprit, anchors, deck planks, wheel and mooring lines. Recoverable source: `WorkingAssets/Ships/hooghly_merchant_1850s.blend`; runtime: `assets/vehicles/ships/hooghly_merchant/hooghly_merchant_1850s.glb`; generator: `tools/world/build_merchant_ship.py`.
- Walkable quay, warehouse, shipment cargo, supported timber jetty, gangway and tidal shore exit. Ship exploration covers weather deck, forecastle, poop/helm, captain cabin, lower cargo hold and crew berths with continuous stair access.
- Physical ship shell and furnishings, usable deck/hold passages, warm interior lights, dry below-waterline hold and river-surface hull exclusion.
- Invisible full-height sea collision at z=820 and lateral limits; distant scenic water continues beyond. Deep sea opacity increases toward the horizon while upstream river transparency is retained.
- Integrated `world/suryagarh/hooghly_port.gd`/`.tscn`, landscape layout, world scene, water-state logic and seventh F4 review point named Hooghly Reach Port.

## Verification and evidence

Final verification: 2026-10-01 IST, root chat. `docs/world/hooghly_port_validation.json`: PASS, zero failures, 105 channel/baked-terrain samples, all actual-controller routes arrived. Includes boarding, both raised decks, cabin entry/exploration/exit, hold descent, cargo/crew passages and return climb. Swimming stopped at z=819.0999; boundary rays tested below/at/above water with the player collider excluded; swimmer returned to shore through the tidal landing. These use the live Player controller and physics rather than position-only assertions.

Commands:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/bake_landscape.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/validate_hooghly_port.gd
for view in overview ship deck hold cabin sea; do
  TLM_PORT_VIEW="$view" /Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script res://tools/world/capture_hooghly_port.gd > "/tmp/tlm_hooghly_capture_$view.log" 2>&1 || exit 1
done
```

Native Godot Forward+/Metal terrain bake PASS: 70.585 s, 144 tiles, 1974 trees, 728 rocks. Field map refresh PASS, 1024x1024. Ship Blender export and import PASS. Route log: `/tmp/tlm_hooghly_routes.log`; build/import logs: `/tmp/tlm_hooghly_ship_build.log`, `/tmp/tlm_hooghly_import.log`. Six final native captures completed successfully in `docs/world/captures/hooghly_port_{overview,ship,deck,hold,cabin,sea}.png`; ship/deck/hold/sea pixels inspected after the final shader and collision edits. Cabin and overview were also reviewed during implementation. Deep horizon is opaque, hold floor is dry and open stair/aisle geometry is visible.

Evidence hashes and route count: `docs/world/hooghly_port_evidence.json`.

## Limits and exact next action

The requested playable port and explorable moored ship are implemented and proportionately verified. Final owner playthrough and AAA visual approval remain open: current timber, hull, warehouse and furnishings are stylized and need a separate material/weathering/detail pass for photorealism. The ship is moored; sailing, shipment AI and British arrival missions are future gameplay work. This is a period-inspired fictional vessel rather than an exact historic replica.

Full-world startup still reports unrelated `arjun_house.gd:23` child access and FortCook/FortSteward missing skeleton diagnostics, plus some household journey warnings. They did not prevent port validation/capture completion and were not edited by this task. Preserve concurrent character/village/horse changes.

Next action: owner normal-speed playthrough at Hooghly Reach Port (reachable downstream or through the F4 review point), reviewing third-person camera clearance and desired art detail. The earlier river fish/AAA realism art review remains independently open in the river refinement work.
