"""Run in Blender per rank: --background --python ... -- <rank>."""
import bpy, sys, math
from pathlib import Path
root=Path(__file__).resolve().parents[2]
rank=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.open_mainfile(filepath=str(root/f'WorkingAssets/NPCs/british/{rank}_pair/{rank}_pair_mpfb_candidate.blend'))
skirt=bpy.data.objects['Companion gathered skirt']
bridge=bpy.data.objects['Companion fitted waist transition']
maxz=max(v.co.z for v in skirt.data.vertices)
ring=[v.co for v in skirt.data.vertices if abs(v.co.z-maxz)<0.0001]
assert len(bridge.data.vertices)==len(ring)*6
error=max((bridge.data.vertices[j].co-ring[j]).length for j in range(len(ring)))
assert error<0.000001,(rank,error)
assert bridge.parent==skirt.parent
assert bridge.modifiers.get('Rig deformation').object==skirt.parent
print('BRITISH_WAIST_VALIDATION',rank,'seam_error_m',error,'top_ring_vertices',len(ring),'bridge_vertices',len(bridge.data.vertices))
