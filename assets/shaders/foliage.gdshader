shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_back;
// Vegetação e objetos com cor por vértice. O alfa da cor é o "peso do vento" (0 = parado).

uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform float rim_amount = 0.18;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = COLOR.a;
	float ph = TIME * wind_speed + wp.x * 0.13 + wp.z * 0.11;
	VERTEX.x += sin(ph) * wind_strength * w * VERTEX.y * 0.25;
	VERTEX.z += cos(ph * 0.8 + 1.3) * wind_strength * 0.7 * w * VERTEX.y * 0.25;
	VERTEX += NORMAL * sin(TIME * 3.0 + VERTEX.y * 2.0 + wp.x) * 0.015 * w;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * rim * rim_amount * COLOR.a;
	ROUGHNESS = 1.0;
}
