"""Rebuild the shared CC0 bark/soil PBR inputs at 2K; no test output.
Sources/licence are documented in environment/forest/assets/textures/SOURCES.md.
"""
from pathlib import Path
import urllib.request, shutil
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'environment/forest/assets/textures'
OUT.mkdir(parents=True, exist_ok=True)
for asset in ['bark_brown_02','forest_ground_04']:
    for channel in ['diff','nor_gl','rough']:
        name = f'{asset}_{channel}_2k.jpg'
        url = f'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/{asset}/{name}'
        destination = OUT / name
        if not destination.exists():
            request = urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
            with urllib.request.urlopen(request,timeout=60) as response: data = response.read()
            if not data.startswith(b'\xff\xd8'): raise ValueError('Not a JPEG: '+url)
            destination.write_bytes(data)
        print(name, destination.stat().st_size)
for source, name in [
    ('island_tree_02_island_tree_02_leaves_diff-island_tree_02_leaves_alpha-island_tree_02_leaves_alpha_1k.png','leaves_albedo.png'),
    ('island_tree_02_island_tree_02_leaves_nor_gl_1k.jpg','leaves_normal.jpg'),
    ('island_tree_02_island_tree_02_leaves_arm_1k.jpg','leaves_arm.jpg')]:
    shutil.copyfile(ROOT/'assets/nature/models'/source,OUT/name)

for source, name in [('aerial_grass_rock_diff_1k.jpg','moss_grass_albedo.jpg'),('aerial_grass_rock_nor_gl_1k.jpg','moss_grass_normal.jpg'),('rock_boulder_dry_diff_1k.jpg','rock_albedo.jpg'),('rock_boulder_dry_nor_gl_1k.jpg','rock_normal.jpg')]:
    shutil.copyfile(ROOT/'assets/nature/materials'/source, OUT/name)
