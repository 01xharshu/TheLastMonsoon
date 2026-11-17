"""Add restrained individual MakeHuman facial targets to adult candidates."""
import bpy,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
profiles={
 'female_05':{'nose/nose-scale-horiz-decr':.35,'nose/nose-scale-depth-incr':.18,'chin/chin-width-decr':.20,'cheek/l-cheek-bones-incr':.18,'cheek/r-cheek-bones-incr':.18},
 'female_06':{'nose/nose-scale-horiz-incr':.25,'nose/nose-scale-depth-decr':.20,'chin/chin-height-incr':.20,'cheek/l-cheek-volume-incr':.20,'cheek/r-cheek-volume-incr':.20},
}
if slug not in profiles:raise ValueError('Unknown adult candidate')
bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.targetservice import TargetService
from bl_ext.blender_org.mpfb.services.locationservice import LocationService
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if body.get('individual_mpfb_face'):raise RuntimeError('Face targets already applied')
targets=Path(LocationService.get_mpfb_data('targets'))
for target,weight in profiles[slug].items():
 key=TargetService.load_target(body,str(targets/(target+'.target.gz')),weight=weight,name='Individual '+target)
 if not key:raise RuntimeError('MPFB target did not load: '+target)
body['individual_mpfb_face']=json.dumps(profiles[slug]);bpy.ops.wm.save_as_mainfile(filepath=str(path));print('INDIAN_MPFB_FACE',slug,json.dumps(profiles[slug]),flush=True)
