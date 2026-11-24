"""Create a saddle-specific variant of the owner-reference uniform; body stays identical."""
import bpy,bmesh,hashlib,json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'WorkingAssets/NPCs/police_uniform/burkundaz/burkundaz_motion.blend'
out=ROOT/'WorkingAssets/NPCs/police_uniform/mounted';out.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
# Recover embedded source textures so relocating the editable blend cannot drop skin/eyes.
original=ROOT/'characters/npcs/thana/patrol_uniform/burkundaz_motion.glb'
with original.open('rb') as f:
 f.read(12);size,kind=struct.unpack('<II',f.read(8));doc=json.loads(f.read(size));size,kind=struct.unpack('<II',f.read(8));binary=f.read(size)
textures=out/'textures';textures.mkdir(exist_ok=True)
for entry in doc.get('images',[]):
 view=doc['bufferViews'][entry['bufferView']];start=view.get('byteOffset',0)
 path=textures/(entry['name']+'.png');path.write_bytes(binary[start:start+view['byteLength']])
 for image in bpy.data.images:
  if entry['name'] in image.name:
   image.filepath=str(path);image.reload();image.pack()

body=bpy.data.objects['village_farmer_MakeHuman_body']
def digest(obj):return hashlib.sha256(b''.join(bytes(str(tuple(v.co)),'utf8') for v in obj.data.vertices)).hexdigest()
before=digest(body)
panel=bpy.data.objects['Kurta loose lower panel']
bm=bmesh.new();bm.from_mesh(panel.data)
bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=1,use_grid_fill=True)
low=min(v.co.z for v in bm.verts);high=max(v.co.z for v in bm.verts)
remove=[f for f in bm.faces if f.calc_center_median().z<low+(high-low)*.55 and abs(f.calc_center_median().x)<.07 and abs(f.calc_center_median().y)>.14]
bmesh.ops.delete(bm,geom=remove,context='FACES_ONLY');bm.to_mesh(panel.data);bm.free()
# Relieve the saddle hem; retain the top seam at the waist and all skin groups.
for v in panel.data.vertices:
 t=max(0,min(1,(high-v.co.z)/(high-low)))
 v.co.z+=.035*t
panel.name='Mounted tunic front rear saddle vents'
trousers=bpy.data.objects['Police full trousers']
for v in trousers.data.vertices:
 z=v.co.z
 ease=max(0,1-abs(z-.72)/.22)*.012
 if abs(v.co.x)>.045:v.co.x+=math.copysign(ease,v.co.x)
 v.co.y+=math.copysign(ease*.6,v.co.y)
trousers.name='Mounted trousers thigh seat ease'
assert digest(body)==before,'Body changed'
bpy.ops.wm.save_as_mainfile(filepath=str(out/'mounted_police.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'characters/npcs/thana/patrol_uniform/mounted_burkundaz.glb'),export_format='GLB',use_selection=True,export_animations=True)
(out/'fit_manifest.json').write_text(json.dumps({'source':str(source),'body_sha256_before':before,'body_sha256_after':digest(body),'saddle_vent_faces_removed':len(remove),'hem_relief_m':.035,'max_thigh_ease_m':.012,'scope':'garment only; original headwear/belts/boots and foundation retained'},indent=2)+'\n')
print('MOUNTED UNIFORM BUILD PASS vents',len(remove))
