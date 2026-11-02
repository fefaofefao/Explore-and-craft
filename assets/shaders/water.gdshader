shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx, depth_draw_opaque;
// Água estilizada: profundidade lida do mapa de alturas do terreno (cor rasa/funda, transparência),
// espuma animada na costa, reflexo do céu por fresnel e ondulação. Também serve para lava.

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float map_half = 120.0;
uniform vec4 deep_color : source_color = vec4(0.05, 0.28, 0.5, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.3, 0.8, 0.85, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sky_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float wave_height = 0.1;
uniform bool is_lava = false;

varying vec3 wpos;

float terrain_h(vec2 xz) {
	vec2 uv = (xz + vec2(map_half)) / (2.0 * map_half);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return -8.0;
	return texture(height_tex, uv).r * 16.0 - 8.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * (is_lava ? 0.25 : 0.9);
	VERTEX.y += sin(wpos.x * 0.18 + t) * wave_height + cos(wpos.z * 0.15 + t * 1.3) * wave_height;
}

void fragment() {
	float spd = is_lava ? 0.012 : 0.03;
	vec4 na = texture(noise_tex, wpos.xz * 0.02 + vec2(TIME * spd, TIME * spd * 0.6));
	vec4 nb = texture(noise_tex, wpos.xz * 0.05 - vec2(TIME * spd * 1.4, -TIME * spd));
	float depth = max(0.0, -terrain_h(wpos.xz));
	float d01 = clamp(depth / 4.5, 0.0, 1.0);
	if (is_lava) {
		float hot = smoothstep(0.35, 0.75, na.g * 0.6 + nb.r * 0.4);
		vec3 c = mix(deep_color.rgb, shallow_color.rgb, hot);
		float crust = smoothstep(0.62, 0.7, nb.b);
		c = mix(c, vec3(0.12, 0.05, 0.04), crust * 0.8);
		ALBEDO = c;
		EMISSION = c * (1.4 + hot * 2.2) * (1.0 - crust * 0.8);
		ROUGHNESS = 0.8;
		ALPHA = 1.0;
	} else {
		vec3 c = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 1.0, d01));
		// cáusticas suaves no raso
		float caust = smoothstep(0.55, 0.8, na.b * 0.5 + nb.g * 0.5) * (1.0 - d01) * 0.35;
		c += vec3(caust);
		// espuma: faixa na margem + linhas que se movem em direção à praia
		float edge = 1.0 - smoothstep(0.0, 0.55, depth + (na.r - 0.5) * 0.35);
		float lines = smoothstep(0.82, 0.95, sin(depth * 5.0 - TIME * 1.6 + na.g * 4.0)) * (1.0 - smoothstep(0.3, 1.6, depth));
		float foam = clamp(edge + lines * 0.6, 0.0, 1.0);
		// reflexo do céu (fresnel)
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		c = mix(c, sky_color.rgb, fres * 0.5);
		c = mix(c, foam_color.rgb, foam * 0.9);
		// cintilação do sol nas ondas
		float glint = pow(clamp(na.g * nb.r * 1.9, 0.0, 1.0), 14.0) * (0.6 + 0.4 * sin(TIME * 3.0 + wpos.x));
		EMISSION = vec3(1.0, 0.97, 0.85) * glint * 1.6 * (1.0 - foam);
		ALBEDO = c;
		ALPHA = clamp(mix(0.45, 0.92, d01) + foam * 0.5 + fres * 0.2, 0.0, 1.0);
		ROUGHNESS = 0.06;
		SPECULAR = 0.6;
		NORMAL_MAP = normalize(vec3(0.5 + (na.r - nb.g) * 0.25, 0.5 + (nb.r - na.g) * 0.25, 1.0));
	}
}
