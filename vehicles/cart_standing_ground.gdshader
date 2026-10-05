shader_type spatial;
render_mode cull_back;
varying vec3 world_at;
varying vec2 standing_at;
void vertex() {
 world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 standing_at = VERTEX.xz;
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 cell = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
 float grit = noise(world_at.xz*37.0);
 float wear = noise(world_at.xz*2.3);
 float border = min(3.0-abs(standing_at.x),6.0-abs(standing_at.y));
 float edge = smoothstep(0.04,0.55,border+noise(world_at.xz*4.0)*0.13-0.1);
 ALBEDO = mix(vec3(.060,.040,.018),vec3(.11,.075,.032),wear)*(.82+grit*.30);
 ROUGHNESS = .98;
 ALPHA = edge;
}
