# Arjun equipment set — standalone asset study

## Selector visibility — 2026-09-25

Only the weapon currently equipped through the selector appears on Arjun. Switching hides every other held, back, hip, and waist model, including the bow quiver; stowing hides the selected weapon too. Inventory ownership and ammunition remain unchanged. `tools/weapons/validate_equipping.gd` passed pickup, switching, and stow visibility checks for the five store weapons. Fresh Forward+/Metal pistol, Enfield, and double gun diagnostic captures show the selected weapon without the other owned weapons on Arjun. These captures use the owner-rejected temporary body, so character fit and grip motion remain unapproved.

Owner reference: `weapon_set_reference_2026-09-23.png` (SHA-256 `d639e90b716d44281badac1f9958417c03c52d6d599ef0974a87ed26cf504439`). The image guides the set's silhouettes and intended carry positions. It is not a source mesh or texture.

| Item | Current asset | State |
| --- | --- | --- |
| Holstered pistol | `environment/weapons/adams_1851/adams_1851.glb` | Existing original study; no new attachment or firing behavior. |
| Waist sword | `environment/weapons/Talwar/weapon_talwar_01.glb` | Existing asset and controls; contact/pose not approved. |
| Bow | `environment/weapons/period_bow/period_bow.glb` | New standalone source and export; no draw/string animation. |
| Arrow | `environment/weapons/period_arrow/period_arrow.glb` | New standalone source and export; no projectile behavior. |
| Back quiver | `environment/weapons/period_quiver/period_quiver.glb` | New standalone source and export with seven visible arrows; no draw interaction. |
| Spear | `environment/weapons/period_spear/period_spear.glb` | New standalone source and export; no attack/carry behavior. |

The new props were authored by `tools/weapons/build_reference_arms.py`; exact input/output hashes are in `weapon_set_build.json`. They were imported and captured in Forward+/Metal by `tools/weapons/capture_reference_arms.gd`: `weapon_set_review_2026-09-23.png`. This capture is an asset review only. The bow, arrow, quiver and spear are simple first studies and need material, construction and animation review. They are not attached to the rejected Arjun model, and no gameplay weapon capability is claimed.

Independent Enfield scale audit: `tools/weapons/audit_enfield_scale.gd` measured its current GLB at 1.41 m overall along its long axis. The [Smithsonian's British Pattern 1853 example](https://collections.si.edu/search/results.htm?q=%22London+Armoury+Company%22) is about 1.391 m overall. This supports the weapon's absolute length being plausible; perceived size, stock bulk and fit to an accepted Arjun still need review.

Next: review the standalone silhouettes, improve the bow/quiver/spear construction, then use a newly accepted Arjun to set carry sockets and test draw, aiming, projectile and strike contact. `tools/world/validate_arjun_equipment.gd` now stops before capturing the rejected export.

## 2026-09-24 grip diagnostic

The pistol grip now pivots with the right palm through the hand bone rather than receiving a second independent rotation during aiming. The bow grip is attached to the left palm, and the right arm tracks the bowstring nock during draw. In the headless world check (`tools/weapons/validate_live_weapon_controls.gd`), the settled pistol grip error is 0.00002 m and the left bow grip error is 0.00002 m. The right drawing hand remains 0.176 m from the fully drawn nock, so bow draw contact is **FAILED**. The functional fire/reload check passes but does not approve appearance or motion. The current Arjun visual is owner-rejected; final body fit and animation contact require the replacement character source and a fresh Metal visual review.

## 2026-09-25 construction detail pass

Rebuilt the original bow, arrow, quiver, spear, and Adams pistol sources/GLBs. The bow has horn nocks, cord grooves, and bound grip ends; arrows have split nocks, bindings, and feather quills; the quiver has stitched reinforcing bands; the spear has socket rivets and a blade ridge; the pistol has a rear sight, frame screws, lever hinge, grip checkering, and cylinder line. Source and export hashes for the four archery/spear assets are in `weapon_set_build.json`. Pistol source SHA-256 `e7c9c5f3b2e5032c3fd3dc3117c6f2e291ab54c965b56da29dea28003b28abb0`; GLB SHA-256 `0b0422c0a883dff927b0625e5e9739a69eb0df4fb5857972cbac971f626170e2`.

Period material/form references: [Met Kashmir bow and arrows](https://www.metmuseum.org/art/collection/search/30293) (wood, bone, steel, reed, feathers; 18th–19th century), [Met Indian/Bhutanese bow and quiver](https://www.metmuseum.org/art/collection/search/30308) (wood, sinew, horn, leather; 19th century), and the [National Army Museum Adams revolver](https://collection.nam.ac.uk/detail.php?acc=1963-12-251-271). The exact decorative treatment and spear form remain original design inferences, not museum replicas.

Godot 4.7.2 Forward+/Metal produced `weapon_set_detail_review_2026-09-25.png` and individual `weapon_*_detail_2026-09-25.png` captures. In close view the geometry reads, but broad materials remain flat, especially on the quiver and spear. Functional bow/pistol check passes after export; full-draw right-hand/nock error remains about 0.177 m. The Enfield, talwar, and double gun did not receive a fine-detail pass here. Final materials, mechanical/historical accuracy, hand contact, and owner visual approval remain open.

## 2026-09-27 hand and revolver correction

The held and holstered Adams copies are now shown at 78% of the previous runtime size; the source mesh is preserved. The held socket was moved with the scale so its wood grip still meets the palm. The pistol finger curl is limited to 35% of the former full-fist pose, which removes the collapsed palm and dark triangular deformation in the fresh Forward+/Metal diagnostic (`grip_diagnostic_pistol.png`). The fingers still do not convincingly wrap the handle or settle on the trigger, so visual grip approval remains **FAILED**. Experimental wrist rotations were removed after they visibly twisted the arm or left the hand under the gun.

The bow now stands upright and has independent grip and string contact targets. In the focused control check, the left grip error is 0.00007 m and the fully drawn right-hand/nock error is 0.00012 m, versus the earlier 0.177 m failure. Those numbers measure pose targets, not skin quality. The current Arjun mesh remains owner-rejected; final palm weights, fingers and weapon contact need a replacement body and normal-speed visual review.

## Enfield reference-length correction — 2026-09-27

Enfield scale is now `1.39065 / 1.41`, matching the Smithsonian specimen's recorded overall length (54¾ inches / 139.065 cm) against the audited 1.41 m source. See [Smithsonian collection measurement](https://collections.si.edu/search/results.htm?q=%22London+Armoury+Company%22). This replaces the 0.82 runtime scale. Stored and held instances share the constant. Existing sockets and palm targets incorporate the scale automatically.

Fresh Metal side view (test output deleted) inspected; both palm targets reach the weapon (~0.17 mm right, ~0.15 mm left). Finger wrap, shoulder seating, exact model profile and final character approval remain open. `tools/weapons/validate_rifle.gd` and the Metal Company weapon-store pickup/support/save check PASS. The length audit now checks runtime length as well as source bounds.
