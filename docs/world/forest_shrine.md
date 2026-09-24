# Wooded ridge cave shrine — 2026-09-24

Status: **IN_WORLD_PREVIEW / VISUAL_REVIEW_FAILED**. The first playable placement is in the eastern wooded ridge, centred at (620, -260), outside the village, Government House, police and company compound plots. The forest precedes the cave from the lower southern slope. No quest marker, settlement, road, hall or village was added to this neglected wooded area.

`world/suryagarh/forest_shrine.gd` adds a deterministic dense grove, rocky passage, skylight, rear wall, and original procedural stone Ganesha blockout. The shrine is approximately nine metres tall. `landscape_layout.gd` levels only the cave floor; the landscape bake clears pre-existing trees from its passage. This is a working spatial composition, **not an approved sculpture or completed cave**.

## Asset and licence decision

The grove reuses `island_tree_02.glb`, already in the project with its Poly Haven source and CC0-1.0 licence recorded in `docs/world/asset_manifest.json`. No new downloaded tree was added. Poly Haven's [Tree Small 02](https://polyhaven.com/a/tree_small_02) is CC0 but identified as *Burkea africana* and the source is 5 million triangles. It is a poor direct fit for this Indian ridge and 8 GB target without species review and a low-poly derivative. The existing locally authored mango asset has no clear external licence issue, but a mango orchard canopy is not automatically right for a remote woodland.

## Evidence and gaps

- Godot scene parsed and loaded; revised landscape bake completed: 144 tiles, 2,129 baked trees.
- Fresh native renderer captures: [forest approach](captures/forest_approach.png), [cave entrance](captures/cave_entrance.png), [idol chamber](captures/idol_chamber.png). The first capture showed terrain blocking the idol; the revised floor removes that obstruction.
- Visual review fails: the approach camera intersects foliage, no guided walkable switchback has been proved from the lower slope, the cave still reads as assembled rock forms with sky exposure, and the idol remains a coarse procedural blockout. Day/night lighting, collision traversal, tree collision, 8 GB performance, cultural/sculptural review and final likeness are unverified.

Next: lay out and walk a forest path from the lower hillside; sculpt a continuous enclosed cave roof with a controlled skylight; replace the blockout with a commissioned/referenced stone sculpture; capture player-eye entry and approach in the target renderer and review with the owner.
