"""Bounded eyelid contact correction on the existing MPFB mesh, no new body."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from fit_arjun_reference_face import shaped_coordinates
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_boot_panels_candidate.blend'
OUT=ROOT/'docs/characters/arjun/reference_fit/eye_contact_2026-10-05';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
body=bpy.data.objects['Arjun_MakeHuman_Body'];points=shaped_coordinates(body);basis=body.data.shape_keys.key_blocks[0];key=body.shape_key_add(name='Arjun_eyelid_contact_candidate');moved=0;maximum=0
for index,(x,y,z) in enumerate(points):
 w=math.exp(-((abs(x)-.030)/.014)**2-((z-1.6073)/.010)**2)
 w*=max(0,min(1,(-y-.095)/.025))
 dz=-(z-1.6073)*.18*w;dy=-.0012*w
 # Limit the local correction to the eyelids; cheek/brow influence fades sharply.
 delta=Vector((0,dy,dz));key.data[index].co=basis.data[index].co+delta
 if delta.length>.00001:moved+=1;maximum=max(maximum,delta.length)
key.value=1
brows=bpy.data.objects['Arjun_Eyebrows'];zs=[v.co.z for v in brows.data.vertices];centre=(max(zs)+min(zs))/2
for v in brows.data.vertices:v.co.z=centre+(v.co.z-centre)*1.12
for mat in brows.data.materials:
 if not mat or not mat.use_nodes:continue
 nt=mat.node_tree;bs=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if not bs:continue
 socket=bs.inputs['Base Color']
 if socket.is_linked:
  upstream=socket.links[0].from_socket;mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(.5,.45,.4,1);nt.links.new(upstream,mix.inputs[1]);nt.links.new(mix.outputs[0],socket)
scene=bpy.context.scene;c=scene.camera;scene.cycles.samples=20;scene.render.resolution_x=900;scene.render.resolution_y=900;c.data.ortho_scale=.40;c.location=(0,-2,1.60);c.rotation_euler=(Vector((0,0,1.60))-c.location).to_track_quat('-Z','Y').to_euler()
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_eye_contact_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('face',(0,-2,1.60)),('face_three_quarter',(1,-2,1.60))]:
 c.location=pos;c.rotation_euler=(Vector((0,0,1.60))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','source':str(SOURCE.relative_to(ROOT)),'candidate':str(candidate.relative_to(ROOT)),'body_origin':'existing MPFB Arjun_MakeHuman_Body','shape_key':key.name,'affected_vertices':moved,'maximum_delta_m':maximum,'exact_match':False,'runtime_replaced':False},indent=2)+'\n')
