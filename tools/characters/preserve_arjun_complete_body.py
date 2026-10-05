"""Apply full-body/foundation rule to latest MPFB candidate and render its fit."""
import bpy,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_eye_contact_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
report=ensure_full_body();bpy.context.view_layer.update()
OUT=ROOT/'docs/characters/arjun/reference_fit/current';report['source']=str(SOURCE.relative_to(ROOT));report['status']='FULL_BODY_STRUCTURE_PASS_VISUAL_OPEN';report['runtime_replaced']=False
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_complete_body_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate));report['candidate']=str(candidate.relative_to(ROOT));(OUT/'full_body_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
