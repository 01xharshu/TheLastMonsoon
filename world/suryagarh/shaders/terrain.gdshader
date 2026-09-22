shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p = world_pos.xz;
	float slope = 1.0 - world_normal.y;
	float rock = smoothstep(0.10, 0.29, slope) * 0.85 + smoothstep(65.0, 125.0, world_pos.y) * 0.4;
	rock = clamp(rock, 0.0, 1.0);
	float rx = 60.0 + 76.0*sin(p.y*0.0045) + 22.0*sin(p.y*0.011);
	float wet = 1.0 - smoothstep(0.1, 3.8, world_pos.y);
	float road_x = -210.0 + 42.0*sin(p.y*0.005);
	float lane = abs(p.y - (160.0 + 12.0*sin(p.x*0.017)));
	float rw = 25.0 + 5.0*sin(p.y*0.008+1.0);
	if (p.x < -280.0 || p.x > rx-rw-18.0) { lane = 10000.0; }
	float road = 1.0-smoothstep(2.0, 4.8, min(abs(p.x-road_x),lane) + noise(p*0.7)*0.6);
	float fields = (1.0-smoothstep(-125.0,-80.0,p.x))*smoothstep(-730.0,-660.0,p.x)*(1.0-smoothstep(470.0,570.0,abs(p.y)));
	fields *= smoothstep(75.0,130.0,length(p-vec2(-310,230)));
	vec2 field_cell = floor((p + vec2(19,33))/vec2(66,91));
	float crop = hash(field_cell);
	vec2 border = abs(fract((p+vec2(19,33))/vec2(66,91))-0.5);
	float bund = smoothstep(0.47,0.49,max(border.x,border.y));
	vec3 soil = texture(soil_tex, p/4.0).rgb;
	vec3 grass = mix(texture(grass_tex, p/12.0).rgb, texture(grass_tex, mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p/19.0 + vec2(0.31)).rgb, 0.45);
	vec3 stone = texture(rock_tex, p/7.0).rgb * vec3(0.62,0.60,0.55);
	float greenery = clamp(0.6 + noise(p*0.018)*0.45 - wet*0.7, 0.0, 1.0);
	vec3 base = mix(soil, grass * vec3(0.66,0.89,0.48), greenery);
	vec3 cultivated = mix(soil*vec3(0.67,0.66,0.49),grass*vec3(0.73,0.9,0.45),step(0.35,crop));
	float furrow = 0.92 + 0.08*sin(p.x*5.5 + field_cell.y);
	base = mix(base, cultivated*furrow, fields*(1.0-bund)*0.78);
	base = mix(base, grass*0.72, fields*bund);
	base = mix(base, stone, rock);
	base = mix(base, soil*vec3(1.07,0.95,0.78), road);
	base *= mix(0.84,1.1,noise(p*0.007));
	base *= 1.0-wet*0.36;
	ALBEDO = base;
	ROUGHNESS = mix(0.92,0.58,wet);
	SPECULAR = 0.24;
	NORMAL_MAP = mix(mix(texture(soil_normal,p/4.0).rgb,texture(grass_normal,p/12.0).rgb,greenery*(1.0-road)),texture(rock_normal,p/7.0).rgb,rock*(1.0-road));
	NORMAL_MAP_DEPTH = 0.65;
}
