shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;
// Água estilizada: ondas no vértice, faixas de espuma animadas e brilho especular.

uniform vec4 deep_color : source_color = vec4(0.1, 0.4, 0.7, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.35, 0.8, 0.9, 1.0);
uniform float alpha = 0.82;
uniform float wave_height = 0.12;
uniform bool is_lava = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * (is_lava ? 0.25 : 0.8);
	VERTEX.y += sin(wpos.x * 0.15 + t) * wave_height + cos(wpos.z * 0.12 + t * 1.3) * wave_height;
}

void fragment() {
	float t = TIME * (is_lava ? 0.05 : 0.12);
	float n = noise(wpos.xz * 0.12 + vec2(t, t * 0.7)) * 0.6 + noise(wpos.xz * 0.35 - vec2(t * 1.4, t)) * 0.4;
	float d = clamp(length(wpos.xz) / 140.0, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, d);
	float foam = smoothstep(0.68, 0.74, n);
	if (is_lava) {
		col = mix(deep_color.rgb, shallow_color.rgb, n);
		EMISSION = col * (1.2 + foam * 2.0);
		ALBEDO = col;
		ALPHA = 1.0;
		ROUGHNESS = 0.9;
	} else {
		ALBEDO = col + vec3(foam * 0.35);
		ALPHA = alpha;
		ROUGHNESS = 0.08;
		METALLIC = 0.0;
		SPECULAR = 0.7;
		NORMAL_MAP = vec3(0.5 + (n - 0.5) * 0.3, 0.5 + (noise(wpos.xz * 0.2 + t) - 0.5) * 0.3, 1.0);
	}
}
