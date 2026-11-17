"""Exercise actual MPFB activity actors using disposable logs, images and saves."""
from pathlib import Path
import argparse, json, math, os, shutil, subprocess, tempfile, time
from run_performance_checks import other_native_jobs
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native',action='store_true')
    parser.add_argument('--village',action='store_true')
    parser.add_argument('--world',action='store_true')
    parser.add_argument('--unseen-crime',action='store_true',help='Exercise an anonymous hillside shooting in the actual world')
    parser.add_argument('--review-seconds',type=int,default=0)
    parser.add_argument('--playback',action='store_true')
    parser.add_argument('--repair-stance',nargs='+',type=float,metavar='VALUE',help='forward half-width offset and optional yaw in degrees and stool height')
    parser.add_argument('--abandoned-carts',action='store_true')
    parser.add_argument('--repair-outfit',type=Path,help='Editable Blender candidate for the real repair yard')
    parser.add_argument('--repair-cycle', action='store_true', help='Sample the full mallet cycle as well as seat entry')
    parser.add_argument('--keep-fitted-source', action='store_true', help='Keep the editable repair candidate after a passing audit')
    parser.add_argument('--refit-cycle', action='store_true', help='Fit a shared seated correction across flagged mallet poses')
    parser.add_argument('--refit-entry', action='store_true', help='Fit entry frames flagged after the settled repair refit')
    parser.add_argument('--refit-repair',action='store_true',help='Fit a disposable copy against the actual settled repair pose')
    args=parser.parse_args()
    fitted_source = ROOT/'WorkingAssets/NPCs/occupation_wardrobe/artisan/cartmaker_repair_workwear.blend'
    if args.keep_fitted_source and (not args.refit_cycle or fitted_source.exists()):
        parser.error('--keep-fitted-source requires --refit-cycle and an unused candidate path')
    if args.unseen_crime and not args.world:
        parser.error('--unseen-crime requires --world')
    if args.refit_cycle and not (args.refit_entry and args.repair_cycle):
        parser.error('--refit-cycle requires --refit-entry and --repair-cycle')
    if args.refit_entry and not args.refit_repair:
        parser.error('--refit-entry requires --refit-repair')
    if args.refit_repair and not args.repair_outfit:
        parser.error('--refit-repair requires --repair-outfit')
    if args.repair_cycle and not args.village:
        parser.error('--repair-cycle requires --village')
    if args.repair_outfit and not args.village:
        parser.error('--repair-outfit requires --village')
    if args.repair_stance and (not args.village or len(args.repair_stance) not in (3,4,5)):
        parser.error('--repair-stance requires --village and forward half-width offset [yaw [height]]')
    if args.native:
        deadline=time.monotonic()+120
        while other_native_jobs():
            if time.monotonic()>deadline:print('Native renderer busy; not launched.');return 2
            time.sleep(2)
    with tempfile.TemporaryDirectory(prefix='tlm-npc-activities-') as folder:
        directory=Path(folder);project=directory/'project';project.mkdir()
        userdata=Path.home()/'Library/Application Support'/directory.name
        try:
            for item in ROOT.iterdir():
                if item.name not in ('.git','project.godot'):(project/item.name).symlink_to(item,target_is_directory=item.is_dir())
            config=(ROOT/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"',1)
            (project/'project.godot').write_text(config)
            env=dict(os.environ,TLM_EXPECT_USER_DATA=str(userdata),TLM_ACTIVITY_REVIEW=folder)
            if args.repair_cycle:
                env['TLM_REPAIR_CYCLE']='1'
            if args.repair_stance:
                env["TLM_REPAIR_STANCE"] = ",".join(map(str,args.repair_stance))
            if args.repair_outfit or args.repair_cycle:
                blender='/Applications/Blender.app/Contents/MacOS/Blender'
            if args.repair_outfit:
                candidate=directory/'repair.glb'
                subprocess.run([blender,'--background','--python-exit-code','1','--python',
                                str(ROOT/'tools/characters/export_occupation_workwear.py'),'--','--source',
                                str(args.repair_outfit.resolve()),'--output',str(candidate)],
                               check=True,stdout=subprocess.DEVNULL,timeout=120)
                env['TLM_REPAIR_OUTFIT']=str(candidate)
            cmd=[GODOT,'--path',str(project),'--log-file',str(directory/'engine.log')]
            cmd+=['--rendering-driver','metal','--resolution','1280x720'] if args.native else ['--headless']
            script = 'validate_abandoned_carts' if args.abandoned_carts else ('validate_unseen_crime_world' if args.unseen_crime else 'validate_npc_activities_world' if args.world else 'validate_npc_activities')
            cmd+=['--script',f'res://tools/world/{script}.gd','--']
            if args.village:cmd+=['--village']
            if args.playback:cmd+=['--playback']
            failed=False
            for load in ([False,True] if args.world or args.abandoned_carts else [False]):
                command=cmd+(['--load'] if load else [])
                process=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                try:output,_=process.communicate(timeout=600 if args.world else 240)
                finally:
                    if process.poll() is None:process.terminate();process.wait(timeout=20)
                lines=output.splitlines()
                for line in lines:
                    if any(x in line for x in ('UNSEEN_CRIME ','BANK_CUSTOMER_PROGRESS ','SLAP_CONTACT ','ACTIVITY_PLAYBACK ','SEAT_CONTACT ','WORK_CONTACT ','REPAIR_WHEEL_CLEARANCE ','REPAIR_FIT_POSE ','MILK_ROUTE ','ACTIVITY_CONTINUE ','NPC ACTIVITIES ','ABANDONED CARTS ','CART_SITE ','ERROR','at:','backtrace','res://')):print(line,flush=True)
                failed=process.returncode!=0 or '"passed":true' not in output or any(x in output for x in ('SCRIPT ERROR:','SHADER ERROR:','\nERROR:'))
                if failed:break
            if args.refit_repair and not failed:
                reference=directory/'reference'
                reference.mkdir()
                subprocess.run([GODOT,'--headless','--path',str(project),'--script',
                                'res://tools/characters/export_occupation_native_surfaces.gd',
                                '--',str(candidate),str(reference)],env=env,check=True,
                               stdout=subprocess.DEVNULL,timeout=120)
                baseline=json.loads((reference/'repair_16.json').read_text())
                workplace=json.loads((directory/'repair_surfaces/frame_47.json').read_text())
                for expected, actual in zip(baseline['meshes'], workplace['meshes'], strict=True):
                    if expected['name'] != actual['name'] or expected['indices'] != actual['indices']:
                        print('REPAIR_REFERENCE topology differs', expected['name'], actual['name'], flush=True)
                        continue
                    distances = [math.dist(a, b) for a, b in zip(expected['vertices'], actual['vertices'], strict=True)]
                    print('REPAIR_REFERENCE', actual['name'], 'mean_mm', round(1000 * sum(distances) / len(distances), 3),
                          'max_mm', round(1000 * max(distances), 3), flush=True)
                source=directory/'source.blend'
                shutil.copyfile(args.repair_outfit,source)
                fitted=directory/'fitted.blend'
                fit=subprocess.run([blender,'--background','--python-exit-code','1','--python',
                                    str(ROOT/'tools/characters/transport_occupation_seated.py'),'--',
                                    str(directory/'repair_surfaces/frame_47.json'),str(fitted),
                                    str(source),str(reference/'repair_16.json')],
                                   timeout=300,capture_output=True,text=True)
                for line in fit.stdout.splitlines():
                    if line.startswith('OCCUPATION_') or 'Error' in line: print(line,flush=True)
                if fit.returncode: return fit.returncode
                revised=directory/'repair_refitted.glb'
                subprocess.run([blender,'--background','--python-exit-code','1','--python',
                                str(ROOT/'tools/characters/export_occupation_workwear.py'),'--','--source',
                                str(fitted),'--output',str(revised)],check=True,stdout=subprocess.DEVNULL,timeout=120)
                env['TLM_REPAIR_OUTFIT']=str(revised)
                shutil.rmtree(directory/'repair_surfaces')
                result=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=240)
                for line in result.stdout.splitlines():
                    if any(tag in line for tag in ('REPAIR_FIT_POSE','NPC ACTIVITIES','ERROR')): print(line,flush=True)
                failed=result.returncode!=0 or 'SCRIPT ERROR:' in result.stdout
            if (args.repair_outfit or args.repair_cycle) and not failed:
                samples=directory/'repair_surfaces'
                audit=[blender,'--background','--python-exit-code','1','--python',
                       str(ROOT/'tools/characters/audit_occupation_native_surfaces.py'),
                       '--',str(samples),'--workplace']
                if args.repair_cycle:
                    audit.append('--workplace-cycle')
                result=subprocess.run(audit, timeout=180, capture_output=True, text=True)
                prefix='OCCUPATION_NATIVE_CONTACT village_repair '
                for phase, enabled in (('entry', args.refit_entry), ('cycle', args.refit_cycle)):
                    if not enabled:
                        continue
                    frames = [int(line.split()[2]) for line in result.stdout.splitlines() if line.startswith(prefix)]
                    frames = [frame for frame in frames if (frame < 20) == (phase == 'entry')]
                    if not frames:
                        continue
                    final=directory/f'{phase}_fitted.blend'
                    fit_samples=[f'frame_{frame:02d}' for frame in frames]
                    if phase == 'cycle':
                        fit_samples.append('--merge-seated')
                    subprocess.run([blender,'--background','--python-exit-code','1','--python',
                                    str(ROOT/'tools/characters/fit_occupation_motion_keys.py'),'--',
                                    str(fitted),str(samples),str(final),*fit_samples],
                                   timeout=300, check=True)
                    fitted=final
                    final_model=directory/f'repair_{phase}.glb'
                    subprocess.run([blender,'--background','--python-exit-code','1','--python',
                                    str(ROOT/'tools/characters/export_occupation_workwear.py'),'--','--source',
                                    str(final),'--output',str(final_model)],check=True,stdout=subprocess.DEVNULL,timeout=120)
                    env['TLM_REPAIR_OUTFIT']=str(final_model)
                    shutil.rmtree(samples)
                    village=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=240)
                    for line in village.stdout.splitlines():
                        if any(tag in line for tag in ('REPAIR_FIT_POSE','NPC ACTIVITIES','ERROR')): print(line,flush=True)
                    if village.returncode or 'SCRIPT ERROR:' in village.stdout:
                        return 1
                    result=subprocess.run(audit, timeout=180, capture_output=True, text=True)
                for line in result.stdout.splitlines():
                    if line.startswith('OCCUPATION_NATIVE_CONTACT'): print(line,flush=True)
                failed=result.returncode!=0
                if args.keep_fitted_source and not failed:
                    with fitted.open('rb') as source_file, fitted_source.open('xb') as candidate_file:
                        shutil.copyfileobj(source_file, candidate_file)
                    print('EDITABLE REPAIR CANDIDATE', fitted_source, flush=True)
            if args.review_seconds and args.native:
                print('TEMP REVIEW',folder,flush=True);time.sleep(min(60,args.review_seconds))
            return int(failed)
        finally:shutil.rmtree(userdata,ignore_errors=True)
if __name__=='__main__':raise SystemExit(main())
