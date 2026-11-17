from pathlib import Path
import tempfile,subprocess,shutil,argparse,os
from run_performance_checks import other_native_jobs
import time
parser=argparse.ArgumentParser()
parser.add_argument("--native",action="store_true")
parser.add_argument("--review",action="store_true")
parser.add_argument("--checks",nargs="+",default=["validate_crime_perception","validate_morning_tutorial"],choices=["validate_opening_voice","validate_household_market_cart","validate_exterior_house_lanterns","validate_station_floor_navigation","validate_thana_staff","validate_dev_guard_release","validate_fort_entry","validate_arjun_walk_contact","validate_arjun_run_contact","validate_public_passenger_cart","validate_arjun_detention","validate_field_grazing","validate_rural_roads","validate_riding_view","validate_remote_mountain_world","validate_remote_mountains","validate_body_investigation","validate_kick_restore","validate_combat_motion","validate_kick_binding","validate_response_life","validate_city_route_population","validate_city_cart_retreat","validate_crime_perception","validate_morning_tutorial","validate_police_search_navigation","validate_combat_rescue","validate_attack_refinement","validate_interaction_glow","validate_weapon_inspection","validate_weapon_store","validate_chacha_house","validate_cart_rolling","validate_dev_story","validate_rebellion_story","validate_consignment_story","validate_cinematic_endpoints","validate_opening_handoff","validate_community_story","validate_consignment_continuous","validate_consignment_motion","validate_consignment_live","validate_hideout_environment","review_rebellion_world"])
args=parser.parse_args()
if args.review and not args.native:parser.error("--review requires --native")
if args.native:
 deadline=time.monotonic()+240
 while other_native_jobs():
  if time.monotonic()>deadline:raise SystemExit("Native renderer remained busy; no other job stopped")
  print("Waiting for other native renderer",flush=True);time.sleep(2)
R=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='tlm-tutorial-guard-') as d:
 p=Path(d)/'project';p.mkdir();u=Path.home()/'Library/Application Support'/Path(d).name
 try:
  for e in R.iterdir():
   if e.name not in ('.git','project.godot'):(p/e.name).symlink_to(e,target_is_directory=e.is_dir())
  (p/'project.godot').write_text((R/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+Path(d).name+'"',1))
  env=os.environ.copy()
  env["TLM_STORY_TEST_DIR"]=d
  env["TLM_SAVE_TEST_DIR"]=d
  env["TLM_CONSIGNMENT_FOCUSED"]="1"
  if args.review:
   env["TLM_TUTORIAL_OUTPUT"]=d;env["TLM_ATTACK_REVIEW"]=d;env["TLM_GLOW_REVIEW"]=d;env["TLM_RIDING_REVIEW"]=d;print("TUTORIAL REVIEW DIR",d,flush=True)
  failed=False
  for name,restore in [(name,phase) for name in args.checks for phase in ([False,True] if name=="validate_weapon_store" else [False])]:
   env["TLM_CHASE_CONTINUOUS"]="1" if name=="validate_consignment_continuous" else "0"
   env["TLM_CHASE_MOTION"]="1" if name=="validate_consignment_motion" else "0"
   if args.review:env["TLM_CONSIGNMENT_REVIEW_PATH"]=d;env["TLM_HIDEOUT_REVIEW_PATH"]=d
   if name=="validate_hideout_environment":env["TLM_HIDEOUT_REVIEW_PATH"]=d
   env["TLM_OPENING_HANDOFF_ONLY"]="1" if name=="validate_opening_handoff" else "0"
   env["TLM_OPENING_VOICE_ONLY"]="1" if name=="validate_opening_voice" else "0"
   env["TLM_CINEMATIC_ENDPOINTS"]="1" if name=="validate_cinematic_endpoints" else "0"
   env["TLM_WEAPON_RESTORE_ONLY"]="1" if restore else "0"
   log=Path(d)/(name+('_restore' if restore else '')+'.log')
   fixed_step=['--fixed-fps','60'] if name in ('validate_arjun_walk_contact','validate_arjun_run_contact') else []
   with log.open('w') as f:
    q=subprocess.Popen(['/Applications/Godot.app/Contents/MacOS/Godot']+(['--verbose'] if os.environ.get('TLM_GODOT_VERBOSE')=='1' else [])+(['--rendering-driver','metal','--resolution','1280x720'] if args.native else ['--headless'])+fixed_step+['--path',str(p),'--script','res://tools/'+('horses/' if name in ('validate_riding_view','validate_public_passenger_cart') else 'characters/' if name in ('validate_thana_staff','validate_combat_rescue','validate_arjun_detention','validate_arjun_walk_contact','validate_arjun_run_contact') else 'weapons/' if name=='validate_combat_motion' else 'world/')+('review_rebellion_story' if name=='review_rebellion_world' else 'validate_dev_story' if name=='validate_cinematic_endpoints' else 'validate_opening_integration' if name in ('validate_opening_handoff','validate_opening_voice') else 'validate_consignment_story' if name in ('validate_consignment_continuous','validate_consignment_motion') else name)+'.gd'],stdout=f,stderr=subprocess.STDOUT,env=env)
    try:
     started=time.monotonic()
     while q.poll() is None:
      if time.monotonic()-started>300 or (log.exists() and 'SCRIPT ERROR:' in log.read_text()):
       q.terminate();break
      time.sleep(.25)
     q.wait(timeout=15)
    finally:
     if q.poll() is None:q.kill();q.wait()

   txt=log.read_text();failed=failed or q.returncode!=0 or 'ERROR:' in txt
   print(name+('_fresh_continue' if restore else ''),'exit',q.returncode,flush=True)
   print('\n'.join(x for x in txt.splitlines() if any(w in x for w in ['OPENING VOICE','ARJUN RUN','PUBLIC PASSENGER CART','RURAL','RIDING','MOUNTAIN','PASS','FAIL','ERROR',' at:','SCRIPT','STATION RESPONSE','STATION FLOOR','STATION WINDOW','THANA STAFF','DEV GUARD RELEASE','STORY CONTACT','STORY CARRY CONTACT','SPEAR','FACE CACHE','CITY_POPULATION','CROSSING POSITIONS','CONSIGNMENT ROUTE','CONSIGNMENT VOICE','CONSIGNMENT CONTINUOUS','CONSIGNMENT MOVING','CONSIGNMENT CIRCUIT','CONSIGNMENT TRANSITION','CONSIGNMENT CONCEAL','CONSIGNMENT LIVE','CONSIGNMENT EARLY SKIP','HIDEOUT ENVIRONMENT','HIDEOUT MANGAL','HIDEOUT CARRIER','HIDEOUT HAND REST'])),flush=True)
  raise SystemExit(1 if failed else 0)
 finally:shutil.rmtree(u,ignore_errors=True)
