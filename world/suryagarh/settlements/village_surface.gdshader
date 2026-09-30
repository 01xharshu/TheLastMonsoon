shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.42, 0.20, 0.11, 1.0);
// 0 clay tile, 1 straw, 2 woven fabric; all are opaque static building surfaces.
uniform int surface_kind = 0;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = abs(world_normal.x) > abs(world_normal.z) ? world_position.zx : world_position.xz;
	float variation = 1.0;
	if (surface_kind == 0) {
		float row = floor(p.y * 3.2);
		vec2 tiles = vec2(p.x * 3.0 + mod(row, 2.0) * 0.5, p.y * 3.2);
		vec2 cell = fract(tiles);
		float seam = 1.0 - smoothstep(0.018, 0.045, min(cell.x, cell.y));
		variation = 0.88 + hash(floor(tiles)) * 0.16;
		variation *= 1.0 - seam * 0.28;
		variation += sin(cell.x * 3.14159) * 0.035;
	} else if (surface_kind == 1) {
		float fibres = hash(floor(vec2(p.x * 65.0, p.y * 3.2)));
		variation = 0.85 + fibres * 0.22;
		variation *= 0.96 + 0.04 * smoothstep(0.03, 0.10, fract(p.y * 3.2));
	} else {
		vec2 weave = abs(sin(p * 160.0));
		variation = 0.93 + weave.x * weave.y * 0.065;
	}
	ALBEDO = tint.rgb * variation;
	ROUGHNESS = 0.95;
}
