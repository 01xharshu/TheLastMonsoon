extends Node
## Chase-only hit feedback and recovery; never revives a dead player.
const QUIET_SECONDS := 5.0
const RECOVERY_PER_SECOND := 6.0
var actor:CharacterBody3D
var mission:Node
var overlay:ColorRect
var shader:ShaderMaterial
var last_health:=100.0
var last_shots:=0
var quiet:=0.0
var impact:=0.0

func _ready() -> void:
 actor=get_parent();mission=actor.get_parent().get_node("ConsignmentStory")
 last_health=actor.health;last_shots=actor.get_node("RifleCombat").shots_fired
 var canvas:=CanvasLayer.new();canvas.name="ChaseDamageFeedback";canvas.layer=20;add_child(canvas)
 overlay=ColorRect.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(overlay)
 shader=ShaderMaterial.new();var effect:=Shader.new()
 effect.code="""shader_type canvas_item;
uniform float impact = 0.0;
uniform float critical = 0.0;
void fragment() {
 vec2 p = (UV - vec2(0.5)) * vec2(1.25, 1.0);
 float edge = smoothstep(0.25, 0.68, length(p));
 float alpha = clamp(edge * (impact * 0.56 + critical * 0.62) + critical * 0.13, 0.0, 0.72);
 COLOR = vec4(0.55, 0.015, 0.02, alpha);
}"""
 shader.shader=effect;overlay.material=shader;overlay.hide()

func _process(delta:float) -> void:
 if not is_instance_valid(actor) or not is_instance_valid(mission):return
 if mission.stage!="chase" or actor.health<=0:
  overlay.hide();quiet=0.0;impact=0.0;last_health=actor.health;last_shots=actor.get_node("RifleCombat").shots_fired;return
 var shots:int=actor.get_node("RifleCombat").shots_fired
 if actor.health<last_health:
  impact=1.0;quiet=0.0
 elif shots!=last_shots:quiet=0.0
 else:quiet+=delta
 if quiet>=QUIET_SECONDS and actor.health<actor.MAX_HEALTH:
  actor.health=minf(actor.MAX_HEALTH,actor.health+RECOVERY_PER_SECOND*delta)
 impact=move_toward(impact,0.0,delta*.55)
 var critical:float=1.0-smoothstep(.20,.5,actor.health/actor.MAX_HEALTH)
 shader.set_shader_parameter("impact",impact);shader.set_shader_parameter("critical",critical)
 overlay.visible=impact>.001 or critical>.001
 last_health=actor.health;last_shots=shots
