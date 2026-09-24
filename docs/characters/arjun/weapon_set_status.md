# Arjun equipment set — standalone asset study

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

Independent Enfield scale audit: `tools/weapons/audit_enfield_scale.gd` measured its current GLB at 1.41 m overall along its long axis. The [Smithsonian's British Pattern 1853 example](https://www.si.edu/object/british-pattern-1853-rifle%3Anmah_414637) is about 1.391 m overall. This supports the weapon's absolute length being plausible; perceived size, stock bulk and fit to an accepted Arjun still need review.

Next: review the standalone silhouettes, improve the bow/quiver/spear construction, then use a newly accepted Arjun to set carry sockets and test draw, aiming, projectile and strike contact. `tools/world/validate_arjun_equipment.gd` now stops before capturing the rejected export.

## 2026-09-24 grip diagnostic

The pistol grip now pivots with the right palm through the hand bone rather than receiving a second independent rotation during aiming. The bow grip is attached to the left palm, and the right arm tracks the bowstring nock during draw. In the headless world check (`tools/weapons/validate_live_weapon_controls.gd`), the settled pistol grip error is 0.00002 m and the left bow grip error is 0.00002 m. The right drawing hand remains 0.176 m from the fully drawn nock, so bow draw contact is **FAILED**. The functional fire/reload check passes but does not approve appearance or motion. The current Arjun visual is owner-rejected; final body fit and animation contact require the replacement character source and a fresh Metal visual review.
