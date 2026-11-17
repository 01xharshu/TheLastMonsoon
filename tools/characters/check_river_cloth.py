"""Actual Godot skin and morph contact check; generated surfaces are disposable."""
import os, subprocess, tempfile, argparse, json
from pathlib import Path
from private_godot_project import private_project
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layers',action='store_true',help='Also audit foundation/blouse/pallu crossings on the same native snapshots')
    parser.add_argument('--foundation-fit',action='store_true',help='Measure inward-audit-independent foundation separation on the same snapshots')
    parser.add_argument('--body-only',action='store_true',help='Check body self-contact and actual hand/foot targets before garment rebaking')
    parser.add_argument('--skin-triangles',action='store_true',help='Audit actual lower-wrap and full-body triangle crossings')
    args=parser.parse_args()
    if args.body_only and (args.layers or args.foundation_fit):parser.error('--body-only cannot audit garment layers')
    with tempfile.TemporaryDirectory(prefix='tlm_river_contact_') as folder, private_project(ROOT,Path(folder)) as project:
        env=dict(os.environ,TLM_RIVER_TEST_OUTPUT=folder)
        commands=[
            [GODOT,'--headless','--path',str(project),'--log-file',str(Path(folder)/'native.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_body_contact.py'),'--',folder,'--summary'],
        ]
        if not args.body_only:commands.append([BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_native_contact.py'),'--',folder])
        if args.layers:commands.extend([
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/validate_river_layer_checker.py')],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_layers.py'),'--',folder],
        ])
        if args.skin_triangles:commands.append([BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_skin_triangles.py'),'--',folder])
        if args.foundation_fit:commands.append([BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_foundation_fit.py'),'--',folder])
        failed=False
        for index,command in enumerate(commands):
            result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=600)
            output=result.stdout+result.stderr
            foundation_summary={}
            for line in output.splitlines():
                if line.startswith("RIVER_FOUNDATION_FIT "):
                    row=json.loads(line.split(" ",1)[1]);region=row["region"]
                    if row["maximum_m"]>foundation_summary.get(region,{}).get("maximum_m",-1):foundation_summary[region]=row
                    continue
                if line.startswith(('RIVER_NATIVE_SURFACES','NATIVE_CONTACT','RIVER_LAYER_CHECKER','RIVER_LAYER_CONTACT','RIVER_FOUNDATION_FIT','RIVER_BODY_CONTACT','RIVER_SKIN_TRIANGLES')):print(line,flush=True)
            if foundation_summary:print("RIVER_FOUNDATION_FIT_SUMMARY",json.dumps(foundation_summary),flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
                if not any(label in output for label in ['NATIVE_CONTACT','RIVER_LAYER_CONTACT']):print('\n'.join(output.splitlines()[-12:]))
                if index==0:return 1 # Later checks require a complete native export.
                failed=True
            if index==0:
                hand=foot=0.0;worst={}
                for path in Path(folder).glob('river_*.json'):
                    pose=json.loads(path.read_text());h=max(pose.get('hand_errors',{}).values(),default=0.0);f=max(pose.get('foot_errors',{}).values(),default=0.0)
                    if max(h,f)>max(hand,foot):worst={'pose':pose['label'],'time':pose.get('pose_time'),'hand_m':h,'foot_m':f}
                    hand=max(hand,h);foot=max(foot,f)
                passed=hand<.015 and foot<.015
                print('RIVER_REACH',json.dumps({'passed':passed,'hand_m':hand,'foot_m':foot,'worst':worst}),flush=True)
                failed=failed or not passed
    return 1 if failed else 0
if __name__=='__main__':raise SystemExit(main())
