# Provision shops

Bhairavpur's shop sits on the central village market lane, beside the turn at the western end of the stalls. Suryagarh's shop sits between the western city market and its residential frontage. The field map and minimap use the same shop symbol. Selecting the shop on the field map sets a waypoint under its veranda.

Follow the roofed walkway and walk through the open side gate. Walk up to the merchant and press **E** to ask for the ledger. The shopkeeper reaches for the book and slides it towards Arjun before the camera cuts to a fixed overhead view of the book.

- **↑ / ↓** or **W / S** moves the pointer through the entries.
- **← / →** or **Page Up / Page Down** turns the sheet. Browsing past an end of the item list also turns the sheet.
- **Enter** buys the selected entry. The price is deducted from carried rupees and the item goes into the satchel. The current balance appears beside the existing coin icon at bottom left.
- **Esc** returns to the shop.

Both shops stock roti (2 rupees), mangoes (3), bandages (6) and leather water bags (12) on the Daily Provisions spread. Trail Supplies has stable fodder (4), six-arrow bundles (8), a utility knife (15) and a bow (24). The keeper checks ownership before selling another knife or bow. The cabinets have iron pulls, with stacked crates and tied sacks kept at the room edges. Purchases use the regular save and Continue system. Shop entrances remain open after loading older saves. Craft workshops have a separate tool symbol, and markets and civic sites retain distinct categories.

Each veranda has solid overhead cover, a clear walking lane and two tagged standing points for future rain-shelter behavior. The two keepers reuse existing adult MakeHuman/MPFB characters and the nearby actor animation system.

## Reusable verification

Run from the project root using a temporary save and capture directory.

```sh
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
TLM_SHOP_TEST_DIR="$temp_dir" \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/world/validate_provision_shops.gd
```

Omit `--headless` for native Metal and inspect the temporary captures before exiting the shell. The validator exercises normal walking and interaction targets in the populated world, checks open public entry and keeper contact, uses ledger key events, tests forward and reverse sheet turns and purchases from both spreads, verifies a rejected purchase and Escape mid-turn, selects the shop waypoints, then saves and uses Continue.

The populated-world check passed in headless Godot and native Metal on 2026-11-06. The native run exercised both road approaches and purchases, the village return path, the map waypoints, and Continue with the remaining balance, bought bandages and the open city passage. Temporary native captures were reviewed for the veranda, counter, ledger and map.
