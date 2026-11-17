# Farm boundaries, wet tracks and settlement police

2026-11-03. Scoped additions to the normal Suryagarh world. Current verification and unresolved findings are in the root handoff.

The existing 24 cultivated plots, 25 rural homes and three farm sheds remain. Four additional 42 × 30 m planted fields lie at X −632, Z −348, −304, 282 and 326, avoiding the indigo factory. The western farm spine extends south and north, with short access spurs to the new plots and a northern connection to the village lane. `countryside_density.gd` owns these shared lane polylines and additional field coordinates; the full map and minimap reuse the lanes, and the full map draws the added plots.

`settlements/farm_boundaries.gd` adds low timber posts and two rough rails around all 28 plots, with a five-metre opening on each east side. Road reservations omit boundary sections near public/cart routes and farm tracks. Each plot uses one visual MultiMesh and one persistent static collision mesh; only the visuals fade with distance. Crops reuse the established plant mesh and foliage shader. New soil, fences and track vertices use cached rays against the registered terrain support layer through `terrain_surface_survey.gd`, avoiding assumptions about saved mesh vertex ordering. Construction yields between plot batches and has no per-frame callback. A bounded node-local grass mask clears new plot interiors and tracks while preserving shared instance buffers and LOD.

The farm-track shader uses photographed earth/normal textures, uneven shoulders, darker wheel ruts and patchy wetness. The broad consignment cart road also receives textured earth and irregular visual shoulders; its route, vertex positions and collision are retained. Moving carts throw small mud clods and flattened wet droplets from their actual wheel positions on wet village/farm roads. Up to four wheels are supported. Stopped, distant, dry-road and unsupported wheel positions do not emit wet splashes. Effects are bounded and cosmetic; they do not change collision, vehicle speed, save state or the terrain mesh. Existing dry-road dust remains.

`settlement_police_routes.gd` restricts routine regional authority routes to inhabited village, city, port and cantonment streets. Fort, mountain, wilderness and remote service roads cannot become ordinary patrol routes. Old regional route saves repair unsafe routine coordinates while retaining health, travel and visit state. Crime pursuit/navigation remains owned by `combat_encounters.gd`; a pursuing officer can still enter the mountains and later return to duty. Existing mission/custody ownership and witness/last-seen rules remain.

Reusable checks use a temporary project and private save directory, cleaned on exit:

```sh
python3 tools/world/run_tutorial_guard_check.py --checks validate_rural_roads
python3 tools/world/run_tutorial_guard_check.py --native --review --checks validate_rural_roads
python3 tools/world/run_tutorial_guard_check.py --checks validate_crime_perception validate_police_search_navigation
```

The rural check loads the normal populated world, checks new plots/boundaries, real field openings and lane collision clearance, legacy police-save migration, live regional route selection, actual MPFB police movement on the mountain trail, and an actual four-wheel coach's moving/stopped wet splashes. Native review provides temporary farm and coach views and, with `TLM_RURAL_PROFILE=1`, a bounded hidden/visible/repeat frame sample at 1280 × 720 with 3D scale 1.0. This comparison is a local rendering measurement in a changing world, not whole-game FPS approval. Test captures/logs are removed automatically.

To review in game, travel west from Bhairavpur to the farm spine at X −570. Follow it north to Z 342 for the new northern plots and south toward Z −348 for the southern pair. Walk through the east openings, then drive a cart along a dark wet patch on the farm or village lanes. Stop to confirm the splashes cease. Explore the mountain ridge without a wanted case to check its quietness; an active pursuit should remain able to follow.
