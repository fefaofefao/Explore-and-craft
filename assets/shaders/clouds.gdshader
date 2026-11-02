shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;
// Camada de nuvens numa cúpula que acompanha a câmera.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.7, 0.75, 0.85, 1.0);
uniform float coverage = 0.5;
uniform float light = 1.0;
varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	if (dir.y < 0.02) discard;
	vec2 uv = dir.xz / (dir.y + 0.25) * 0.35;
	float t = TIME * 0.006;
	float n = texture(noise_tex, uv + vec2(t, t * 0.4)).r * 0.65 + texture(noise_tex, uv * 2.3 - vec2(t * 1.7, 0.0)).g * 0.35;
	float a = smoothstep(coverage, coverage + 0.22, n);
	float horizon = smoothstep(0.02, 0.25, dir.y);
	vec3 c = mix(shade_color.rgb, cloud_color.rgb, smoothstep(coverage, coverage + 0.4, n + 0.08));
	ALBEDO = c * light;
	ALPHA = a * horizon * 0.85;
}
