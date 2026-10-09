shader_type canvas_item;
uniform float phase = 0.0;
uniform float visibility = 1.0;
uniform vec2 canvas_size = vec2(1280.0, 720.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.39)) * canvas_size / min(canvas_size.x, canvas_size.y);
	float reveal = smoothstep(0.1, 2.2, phase);
	float impact = exp(-pow((phase - 2.35) * 3.2, 2.0));
	float haze = exp(-length(p * vec2(1.0, 1.7)) * 3.5);
	float beam = exp(-abs(p.y + p.x * 0.35 - sin(phase * 0.3) * 0.03) * 50.0);
	beam *= exp(-abs(p.x) * 2.8) * (0.35 + impact);
	float ring = exp(-abs(length(p) - max(phase - 2.25, 0.0) * 0.6) * 110.0);
	ring *= exp(-max(phase - 2.25, 0.0) * 3.5) * step(2.25, phase);
	float grain = hash(FRAGCOORD.xy + floor(phase * 24.0)) * 0.005;
	vec3 ink = vec3(0.012, 0.017, 0.023);
	vec3 light = vec3(0.54, 0.34, 0.14) * (haze * 0.085 + beam * 0.10 + ring * 0.20);
	COLOR = vec4(ink + (light * reveal + grain) * visibility, 1.0);
}
