shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Grama com vento: lâminas de uma MultiMesh balançam conforme a posição no mundo.

uniform vec4 base_color : source_color = vec4(0.25, 0.45, 0.18, 1.0);
uniform vec4 tip_color : source_color = vec4(0.55, 0.8, 0.3, 1.0);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.6;
varying float vh;

void vertex() {
	vh = clamp(VERTEX.y / 0.7, 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(TIME * wind_speed + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(TIME * wind_speed * 2.3 + wp.x * 0.9);
	VERTEX.x += w * wind_strength * vh * vh;
	VERTEX.z += w * wind_strength * 0.6 * vh * vh;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 c = mix(base_color.rgb, tip_color.rgb, vh) * COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
