"""Retain the measured individual fit settings in the separate adult studies.

This changes metadata only. It does not change bodies or approve production
assignment. Re-export and independently check after calibration.
"""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[2]
for number in range(1,7):
    identity=f'female_{number:02}'
    path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/identity/'tailored_armhole_study.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
    body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
    if body.get('body_profile')!=identity or body.get('fuller_profile')!=identity:
        raise RuntimeError('Requires the existing matching adult fuller MPFB study')
    body['street_arm_clearance_rad']=.18 if number==3 else .12
    body['street_fit_body_waist']=True
    body['street_body_fit_version']=1
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print('INDIAN_OUTFIT_CALIBRATION',identity,body['street_arm_clearance_rad'],flush=True)
