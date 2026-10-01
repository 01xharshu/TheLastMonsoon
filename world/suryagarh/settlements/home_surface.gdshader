shader_type spatial;
uniform vec4 tint : source_color = vec4(0.7,0.65,0.52,1.0);
uniform int kind = 0; // lime plaster, timber, woven cloth, earth, soot
varying vec3 at;
void vertex() { at = VERTEX; }
float grain(vec3 p) { return fract(sin(dot(floor(p),vec3(12.9898,78.233,37.719)))*43758.5453); }
void fragment() {
 float shade = 0.97 + 0.06*grain(at*55.0);
 if (kind == 1) { shade = 0.88+0.1*sin(at.x*90.0+sin(at.z*8.0)*2.0)+0.05*grain(at*30.0); }
 if (kind == 2) { shade = 0.92+0.08*abs(sin(at.x*220.0)*sin((at.y+at.z)*220.0)); }
 if (kind == 3) { shade = 0.91+0.12*grain(at*7.0)+0.04*grain(at*85.0); }
 if (kind == 4) { if (length(vec2(at.x/0.56,at.y/0.83)) > 0.85+0.13*grain(at*25.0)) { discard; } shade = 0.25+0.5*smoothstep(0.0,2.0,abs(at.x))+0.09*grain(at*13.0); }
 ALBEDO = tint.rgb*shade;
 ROUGHNESS = kind == 1 ? 0.82 : 0.96;
}
