shader_type spatial;
render_mode cull_disabled, unshaded, world_vertex_coords;
// Grama (baixa e alta) com vento global: direção que muda, rajadas que correm pelo campo como ondas
// (com o brilho prateado típico nas pontas), tremulação fina e personagens abrindo caminho.
// Sem iluminação dinâmica (barata no celular): a luz do dia vem de "light_mult".

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_str = 0.5;
uniform vec2 wind_offset = vec2(0.0);
uniform float blade_h = 0.55;
uniform float bend = 0.55;
uniform float stiffness = 1.0;
uniform float light_mult = 1.0;
uniform float fade_end = 50.0;
uniform vec4 tip_tint : source_color = vec4(1.0, 1.0, 0.85, 1.0);
uniform vec4 gust_tint : source_color = vec4(0.92, 1.0, 0.82, 1.0);
uniform vec4 pushers[4];

varying float vh;
varying float gust;
varying float shade;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float sy = length(MODEL_MATRIX[1].xyz);
	float H = blade_h * sy;
	vh = clamp((VERTEX.y - root.y) / max(H, 0.01), 0.0, 1.0);
	float vh2 = vh * vh;
	// ondas de vento: ruído em espaço de mundo deslizando na direção do vento
	vec2 uv = (root.xz - wind_offset) * 0.022;
	float n = texture(noise_tex, uv).r * 0.7 + texture(noise_tex, uv * 2.7 + 0.3).g * 0.3;
	gust = smoothstep(0.42, 0.82, n) * clamp(wind_str * 1.3, 0.0, 1.0);
	float flutter = sin(TIME * 5.3 + root.x * 1.7 + root.z * 1.3) * 0.5 + sin(TIME * 8.1 + root.z * 2.3) * 0.25;
	float b = (wind_str * 0.45 + gust * 0.9 + flutter * 0.06 * (0.4 + wind_str)) * bend / stiffness;
	vec2 off = wind_dir * b * H;
	// perpendicular: ondulação lateral leve
	off += vec2(-wind_dir.y, wind_dir.x) * flutter * 0.05 * H * (0.3 + wind_str);
	// personagens empurram (xyz = posição, w = raio)
	float down = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 p = pushers[i];
		if (p.w <= 0.0) continue;
		vec2 away = root.xz - p.xz;
		float d = length(away);
		float k = (1.0 - smoothstep(p.w * 0.35, p.w, d)) * step(abs(root.y - p.y), 2.5);
		vec2 dir = d > 0.001 ? away / d : wind_dir;
		off += dir * k * 0.85 * H;
		down = max(down, k);
	}
	// afasta das bordas da visibilidade encolhendo (sem "pipocar")
	float dist = length(root - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_end * 0.72, fade_end, dist);
	float lift = VERTEX.y - root.y;
	float L = length(off);
	// conserva o comprimento aproximado da lâmina (curva em vez de esticar)
	float drop = min(L * L / max(H, 0.01) * 0.5, H * 0.75) + down * 0.35 * H;
	VERTEX.xz += off * vh2;
	VERTEX.y = root.y + (lift - drop * vh2) * fade;
	shade = 1.0 - down * 0.25;
}

void fragment() {
	vec3 ground = COLOR.rgb;
	vec3 c = mix(ground * 0.72, ground * 1.42 * tip_tint.rgb + vec3(0.025), smoothstep(0.0, 1.0, vh));
	// brilho prateado das rajadas nas pontas
	c = mix(c, c * 1.18 + gust_tint.rgb * 0.12, gust * vh * vh);
	c += vec3(0.05, 0.06, 0.015) * vh * vh;
	ALBEDO = c * light_mult * shade;
}
