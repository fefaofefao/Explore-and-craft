shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Toon estilizado para Ecos e personagens: degrau suave de luz, sombras com tom frio,
// brilho especular "anime", luz de borda e leve degradê (mais escuro embaixo).

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade_tint : source_color = vec4(0.62, 0.6, 0.85, 1.0);
uniform float rim = 0.35;
uniform float spec = 0.35;
uniform float gradient = 0.22;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 c = albedo.rgb * mix(1.0 - gradient, 1.0, clamp(wn.y * 0.5 + 0.6, 0.0, 1.0));
	ALBEDO = c;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission.rgb * emission_energy + c * fr * rim * 0.55;
	ROUGHNESS = 0.6;
}

void light() {
	vec3 lc = LIGHT_COLOR / PI;  // LIGHT_COLOR já vem multiplicada por PI no Godot 4
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.03, 0.12, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		lit *= ATTENUATION;
		DIFFUSE_LIGHT += lc * mix(shade_tint.rgb * 0.38, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += lc * ATTENUATION * mix(shade_tint.rgb * 0.3, vec3(1.0), lit);
	}
	vec3 h = normalize(VIEW + LIGHT);
	float sp = smoothstep(0.955, 0.975, dot(NORMAL, h)) * lit * spec;
	SPECULAR_LIGHT += lc * sp;
}
