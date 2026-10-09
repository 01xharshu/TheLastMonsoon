extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures.append(label)
func run() -> void:
 var saved: Dictionary=root.get_node('SaveManager').options.duplicate(true)
 var manager: Node=root.get_node('SaveManager')
 var old_path: String=manager.settings_path
 var out: String=''
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--output='):out=arg.trim_prefix('--output=')
 if out=='':push_error('Caller must supply a temporary --output directory');quit(1);return
 manager.settings_path=out+'/settings.cfg'
 var menu: Control=load('res://ui/main_menu.gd').new();root.add_child(menu);current_scene=menu
 menu.show_settings();await process_frame
 var panel: Control=menu.column.find_child('SettingsPanel',true,false)
 check(panel!=null,'shared settings panel loads')
 if panel==null:quit(1);return
 check(panel.category=='' and panel.find_children('*','HSlider',true,false).is_empty(),'settings home is a short category list')
 for category in panel.CATEGORIES+['Movement','Actions']:
  panel.show_category(category);await process_frame
  check(panel.get_combined_minimum_size().y<=500,'submenu fits pause panel: '+category+' ('+str(panel.get_combined_minimum_size().y)+' px)')
  check(root.gui_get_focus_owner()!=null,'submenu receives keyboard/controller focus: '+category)
 panel.show_category('Audio');await process_frame
 var slider: HSlider=panel.find_child('ambient_slider',true,false)
 check(slider!=null,'Audio includes independent ambient slider')
 slider.value=.23
 check(absf(manager.options.ambient-.23)<.001,'ambient slider applies live')
 manager.options.ambient=.9;manager.load_options()
 check(absf(manager.options.ambient-.23)<.001,'ambient value persists across settings reload')
 manager.set_option('ambient',0)
 check(AudioServer.is_bus_mute(AudioServer.get_bus_index('Ambient')),'zero ambient mutes ambient bus')
 check(not AudioServer.is_bus_mute(AudioServer.get_bus_index('Master')),'ambient mute leaves gameplay/master available')
 var audio: Node=root.get_node('WorldAudio');audio.play_at('sparrow',Vector3.ZERO)
 check(audio.voices[0].bus=='Ambient','bird voice uses ambient bus')
 audio.voices[0].stop();audio.play_at('impact',Vector3.ZERO)
 check(audio.voices[0].bus=='Master','reused voice restores gameplay bus')
 var env: Node=audio.get_node('EnvironmentAudio')
 check(env.river_voice.bus=='Ambient' and env.shore_voice.bus=='Ambient' and env.loops[0].bus=='Ambient','all environment loops use ambient bus')
 var wind: Node=root.get_node('WindSystem')
 var stream: AudioStreamWAV=wind.ambience.stream
 check(wind.ambience.bus=='Ambient','wind uses ambient bus')
 for key in ['fire','river']:
  check(env.clips[key].format==AudioStreamWAV.FORMAT_16_BITS and env.clips[key].loop_mode==AudioStreamWAV.LOOP_FORWARD,'recorded '+key+' receives loop-seam smoothing')
 check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,'wind imports PCM and crossfades a real loop')
 check(stream.get_length()>20,'long wind texture avoids short repeating buzz')
 for i in 10:panel.show_category('Controller');panel.show_category('Audio')
 check(panel.device_callbacks.is_empty(),'submenu changes retire device callbacks')
 check(panel.handle_back() and panel.category=='','Back returns to category list')
 check(not panel.handle_back(),'category list Back exits settings')
 panel.show_category('Movement');panel.begin_binding('move_forward');panel.handle_back()
 check(panel.category=='Movement' and panel.waiting_action=='','Back cancels key capture first')
 panel.handle_back();check(panel.category=='Keyboard controls','key binding page returns to controls submenu')
 if DisplayServer.get_name()!='headless':
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720))
  for category in ['','Audio','Controller']:
   panel.show_category(category)
   for i in 8:await process_frame
   await RenderingServer.frame_post_draw
   var capture:=root.get_texture().get_image();capture.resize(1280,720)
   capture.save_png(out+'/settings_'+('home' if category=='' else category)+'.png')
 manager.options=saved;manager.settings_path=old_path;manager.apply_options()
 preload('res://tools/test_audio_cleanup.gd').stop(root);await preload('res://tools/test_audio_cleanup.gd').settle(self)
 print('AMBIENT / SETTINGS: '+('PASS' if failures.is_empty() else 'FAIL'))
 quit(0 if failures.is_empty() else 1)
