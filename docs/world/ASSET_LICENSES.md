# Suryagarh landscape asset provenance

Verified 2026-09-22. These entries cover only the newly added landscape assets. They do not relicense the project or audit existing music, characters or furniture.

All six source assets are provided by Poly Haven under **CC0 1.0**. Commercial use and modification are allowed. Retain these records even though attribution is not required by CC0.

- Provider license: https://polyhaven.com/license
- License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode
- Exact download URLs and SHA-256: `asset_manifest.json`
- Derived mesh triangle counts and SHA-256: `derived_assets.json`

| Asset | Author(s) | Source | Use |
|---|---|---|---|
| aerial_grass_rock | Rob Tuytel | https://polyhaven.com/a/aerial_grass_rock | Ground cover and field surface |
| boulder_01 | Rico Cilliers | https://polyhaven.com/a/boulder_01 | Grounded rocks with simplified collision |
| brown_mud_dry | Rob Tuytel | https://polyhaven.com/a/brown_mud_dry | Soil and dirt paths |
| grass_bermuda_01 | Rico Cilliers | https://polyhaven.com/a/grass_bermuda_01 | Small ground-cover mesh |
| island_tree_02 | Rob Tuytel, Rico Cilliers | https://polyhaven.com/a/island_tree_02 | Temporary broadleaf vegetation; species/1857 regional suitability not approved |
| rock_boulder_dry | Dimitrios Savva, Rico Cilliers | https://polyhaven.com/a/rock_boulder_dry | Rocky slopes |

## Modifications

The Blender preparation script creates derived GLBs without changing downloaded sources. The tree is reduced to 18,000 triangles; the rock is welded and reduced to 1,800. Grass uses one eight-triangle component, normalized around its base and scaled for ground cover. Geometry is instanced with deterministic variation. All source texture inputs are 1K. No source human asset is used by this landscape.

## Tool decision

Godot 4.7.2 and Blender 5.2 were used locally. No new editor extension was installed. Terrain3D was evaluated via its official platform and installation documentation; native Godot ArrayMesh/ImporterMesh, HeightMapShape3D and MultiMesh are sufficient for this bounded foundation. This is a code-authored landscape, not a brush-sculpting editor workflow. Revisit terrain tooling before extensive hand sculpting, terrain holes, caves or large-scale streaming.

References: https://terrain3d.readthedocs.io/en/stable/docs/platforms.html and https://terrain3d.readthedocs.io/en/stable/docs/installation.html
