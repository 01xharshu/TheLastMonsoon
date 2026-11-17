shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_mask_tex : filter_linear_mipmap;
uniform sampler2D density_mask_tex : hint_default_black, filter_linear_mipmap;
uniform vec4 urban_bounds = vec4(0.0);
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
// Widths in metres. Wheel lines wander and overlap on the busier market street.
float wheel_pair(float across, float gauge, float width) {
 return 1.0-smoothstep(width*.32,width,abs(abs(across)-gauge));
}
void fragment() {
	vec2 p = world_pos.xz;
	float slope = 1.0 - world_normal.y;
	float rock = smoothstep(0.10, 0.29, slope) * 0.85 + smoothstep(65.0, 125.0, world_pos.y) * 0.4;
	rock = clamp(rock, 0.0, 1.0);
	float wet = 1.0 - smoothstep(0.1, 3.8, world_pos.y);
	float core_mask = 1.0-step(864.0,max(abs(p.x),abs(p.y)));
	float road = texture(road_mask_tex, (p + vec2(864.0)) / 1728.0).r*core_mask;
	float urban_edge = max(max(urban_bounds.x-p.x,p.x-urban_bounds.z),max(urban_bounds.y-p.y,p.y-urban_bounds.w));
	float urban = (urban_bounds.z>urban_bounds.x) ? 1.0-smoothstep(0.0,12.0,urban_edge) : 0.0;
	float fields = (1.0-smoothstep(-125.0,-80.0,p.x))*smoothstep(-730.0,-660.0,p.x)*(1.0-smoothstep(470.0,570.0,abs(p.y)));
	fields *= 1.0-urban;
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
	base = mix(base,soil*vec3(0.68,0.62,0.52),urban*0.92);
	vec2 authored_land = texture(density_mask_tex, (p + vec2(864.0)) / 1728.0).rg*core_mask;
	float authored_field = authored_land.r;
	base = mix(base, soil * vec3(0.68,0.58,0.43) * (0.94+0.06*sin(p.x*6.283)), authored_field);
	base = mix(base, soil * vec3(0.78,0.67,0.50), authored_land.g);
	vec3 road_earth = soil*vec3(1.07,0.95,0.78);
	// Straight sections of village_spine and city_market_street in LandscapeLayout.
	float village = smoothstep(-422.0,-411.0,p.x)*(1.0-smoothstep(-316.0,-301.0,p.x));
	village *= 1.0-smoothstep(2.8,5.0,abs(p.y-230.0));
	float market = smoothstep(-440.0,-425.0,p.x)*(1.0-smoothstep(-265.0,-250.0,p.x));
	market *= 1.0-smoothstep(4.4,6.5,abs(p.y+310.0));
	float mud = 0.0;
	if (village+market > 0.0 && road > 0.01) {
		float drift = (noise(vec2(p.x*.24,9.1))-.5)*.34;
		float wear = noise(p*.83);
		float village_cross = p.y-230.0+drift;
		float village_ruts = wheel_pair(village_cross,1.08,.37);
		float crown = (1.0-smoothstep(.20,.71,abs(village_cross)))*smoothstep(.26,.67,wear);
		road_earth = mix(road_earth,grass*vec3(.60,.74,.39),village*crown*.78);
		float market_cross = p.y+310.0+drift;
		float market_ruts = max(wheel_pair(market_cross,1.08,.22),
			max(wheel_pair(market_cross-2.30+sin(p.x*.16)*.42,1.08,.19),
			wheel_pair(market_cross+2.05+sin(p.x*.19)*.58,1.08,.24)));
		float basin = smoothstep(.38,.78,noise(p*.28));
		float tracks = max(village*village_ruts,market*market_ruts);
		road_earth = mix(road_earth,road_earth*vec3(.58,.50,.41),tracks*mix(.57,.92,wear));
		mud = market*basin*(.22+.78*market_ruts)*road;
	}
	base = mix(base,road_earth,road);
	base *= mix(vec3(1.0),vec3(.73,.65,.55),mud);
	base *= mix(0.84,1.1,noise(p*0.007));
	base *= 1.0-wet*0.36;
	ALBEDO = base;
	ROUGHNESS = mix(mix(0.92,0.58,wet),0.37,mud);
	SPECULAR = mix(0.24,0.42,mud);
	NORMAL_MAP = mix(mix(texture(soil_normal,p/4.0).rgb,texture(grass_normal,p/12.0).rgb,greenery*(1.0-road)),texture(rock_normal,p/7.0).rgb,rock*(1.0-road));
	NORMAL_MAP_DEPTH = 0.65;
}
