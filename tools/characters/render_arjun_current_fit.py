"""Latest full-character and face evidence for the retained boot-panel source."""
import bpy, argparse, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_boot_panels_candidate.blend');parser.add_argument('--output',type=Path,default=ROOT/'docs/characters/arjun/reference_fit/boot_panels_2026-10-02');parser.add_argument('--full-only',action='store_true');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()))
s=bpy.context.scene;c=s.camera;s.cycles.samples=16;s.render.resolution_x=700;s.render.resolution_y=950;c.data.ortho_scale=1.92
for name,pos in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 c.location=pos;c.rotation_euler=(Vector((0,0,.88))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
if args.full_only:sys.exit(0)
s.render.resolution_x=900;s.render.resolution_y=900;c.data.ortho_scale=.4;c.location=(0,-2,1.60);c.rotation_euler=(Vector((0,0,1.60))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(OUT/'face.png');bpy.ops.render.render(write_still=True)
