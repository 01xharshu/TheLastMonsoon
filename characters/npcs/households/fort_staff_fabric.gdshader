shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(.56,.51,.4,1);
uniform float work_stains = .12;
uniform bool apron = false;
varying vec3 rest_position;
void vertex() { rest_position=VERTEX; }
void fragment() {
 vec2 p=vec2(rest_position.x+rest_position.z*.37,rest_position.y);
 vec2 yarn=p*720.;
 float fade=1.-smoothstep(.2,.7,max(length(dFdx(yarn)),length(dFdy(yarn))));
 float weave=(sin(yarn.x*6.283)+sin(yarn.y*6.283))*.5*fade;
 float creases=sin(p.x*132.+sin(p.y*17.)*.6)*.026;
 float wear=smoothstep(.15,.7,sin(p.x*23.+p.y*7.)*sin(p.y*31.-p.x*5.));
 float edge=apron ? 1.-smoothstep(.009,.022,min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y))) : 0.;
 ALBEDO=cloth_color.rgb*(1.+weave*.045+creases-wear*work_stains-edge*.18);
 ROUGHNESS=.92;
 SPECULAR=.18;
}
