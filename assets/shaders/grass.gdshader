shader_type spatial;
render_mode cull_disabled, unshaded;
// Grama com vento (sem iluminação dinâmica: barata no celular). A cor de cada tufo vem do chão (instância);
// a luz do dia vem de "light_mult". Pontas mais claras dão leitura de volume.

uniform float wind_strength = 0.16;
uniform float wind_speed = 1.6;
uniform float light_mult = 1.0;
uniform vec4 tip_tint : source_color = vec4(1.0, 1.0, 0.85, 1.0);
varying float vh;

void vertex() {
	vh = clamp(VERTEX.y / 0.55, 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(TIME * wind_speed + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(TIME * wind_speed * 2.3 + wp.x * 0.9);
	VERTEX.x += w * wind_strength * vh * vh;
	VERTEX.z += w * wind_strength * 0.6 * vh * vh;
}

void fragment() {
	vec3 ground = COLOR.rgb;
	vec3 c = mix(ground * 0.95, ground * 1.45 * tip_tint.rgb + vec3(0.03), vh);
	ALBEDO = c * light_mult;
}
