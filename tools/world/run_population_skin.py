"""Run population skin fixture with private settings and disposable captures."""
from pathlib import Path
import argparse, os, shutil, subprocess, tempfile, time
from run_performance_checks import other_native_jobs
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
parser=argparse.ArgumentParser()
parser.add_argument('--native',action='store_true')
parser.add_argument('--review',action='store_true')
parser.add_argument('--world',action='store_true')
args=parser.parse_args()
if args.review and not args.native:parser.error('--review requires --native')
if args.world and not args.native:parser.error('--world requires --native')
if args.native:
 deadline=time.monotonic()+120
 while other_native_jobs():
  if time.monotonic()>deadline:raise SystemExit('Native renderer busy; fixture not launched')
  time.sleep(2)
with tempfile.TemporaryDirectory(prefix='tlm-population-skin-') as folder:
 p=Path(folder);project=p/'project';project.mkdir();userdata=Path.home()/'Library/Application Support'/p.name
 try:
  for item in ROOT.iterdir():
   if item.name not in ('.git','project.godot'):(project/item.name).symlink_to(item,target_is_directory=item.is_dir())
  config=(ROOT/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+p.name+'"',1)
  (project/'project.godot').write_text(config)
  env=dict(os.environ,TLM_SKIN_REVIEW=folder if args.review else '')
  command=[GODOT,'--path',str(project)]+(['--rendering-driver','metal','--resolution','1280x720'] if args.native else ['--headless'])+['--script','res://tools/world/'+('profile_population_skin.gd' if args.world else 'validate_population_skin_variation.gd')]
  run=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,env=env,timeout=600 if args.world else 180)
  print('\n'.join(line for line in run.stdout.splitlines() if any(x in line for x in ('POPULATION_SKIN','ERROR','SCRIPT','SHADER','at:'))),flush=True)
  failed=run.returncode!=0 or '"passed":true' not in run.stdout or any(x in run.stdout for x in ('SCRIPT ERROR:','SHADER ERROR:','\nERROR:'))
  if args.review and not failed:print('SKIN_REVIEW_DIR',folder,flush=True);time.sleep(60)
  raise SystemExit(int(failed))
 finally:shutil.rmtree(userdata,ignore_errors=True)
