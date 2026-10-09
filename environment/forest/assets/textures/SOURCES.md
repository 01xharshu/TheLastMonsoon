# Shared forest material sources

- **Bark Brown 02**, Rob Tuytel / Poly Haven, CC0: https://polyhaven.com/a/bark_brown_02 . 2K JPG diffuse, OpenGL normal and roughness maps; photographed material, 1 m tile width.
- **Forest Ground 04**, Rob Tuytel and Rico Cilliers / Poly Haven, CC0: https://polyhaven.com/a/forest_ground_04 . 2K JPG diffuse, OpenGL normal and roughness; 3.2 m tile width.
- **Forest Leaves 02**, Rob Tuytel / Poly Haven, CC0: https://polyhaven.com/a/forest_leaves_02 . 2K diffuse, OpenGL normal and roughness maps of moss, fallen leaves and twigs; 3 m tile height.
- **Island Tree 02** leaf albedo/alpha, OpenGL normal and packed AO/roughness/metal maps: existing project Poly Haven asset, https://polyhaven.com/a/island_tree_02 . Shared 1K atlas; runtime uses the second photographed leaf region. Kept as rebuild inputs, not review images.
- Moss/grass and rock maps are copies of the existing project aerial_grass_rock and rock_boulder_dry material inputs. Originals remain unchanged. Rock geometry is the existing project boulder_01 export, copied as rock_reused.glb.

`tools/environment/fetch_forest_materials.py` retrieves the new CC0 maps and copies existing inputs. Retain these texture files for offline runtime and a recoverable clone. Blender sources link to them with relative paths. Runtime GLBs omit embedded images to avoid duplicating textures for each LOD. The forest generator assigns shared PBR materials after import.
