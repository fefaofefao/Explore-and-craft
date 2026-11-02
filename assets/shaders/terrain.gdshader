shader_type spatial;
render_mode specular_disabled;
// Terreno pintado (inspirado em mundos abertos com visual de aquarela): grama com pinceladas e
// degradê quente/frio, trilhas de terra, areia molhada na costa, penhascos de rocha com estratos
// projetados nos três eixos (sem esticar), bordas de grama no topo dos penhascos, micro relevo,
// sombra de vales, sombras de nuvens, luz em degraus suaves com sombras azuladas e névoa de distância.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float map_half = 120.0;
uniform vec4 deep_tint : source_color = vec4(0.12, 0.32, 0.38, 1.0);
uniform vec4 grass_a : source_color = vec4(0.31, 0.56, 0.23, 1.0);
uniform vec4 grass_b : source_color = vec4(0.53, 0.76, 0.35, 1.0);
uniform vec4 grass_c : source_color = vec4(0.42, 0.67, 0.27, 1.0);
uniform vec4 dirt : source_color = vec4(0.55, 0.42, 0.28, 1.0);
uniform vec4 sand : source_color = vec4(0.9, 0.83, 0.6, 1.0);
uniform vec4 rock : source_color = vec4(0.49, 0.48, 0.45, 1.0);
uniform vec4 high : source_color = vec4(0.6, 0.64, 0.54, 1.0);
uniform vec4 haze : source_color = vec4(0.62, 0.78, 0.9, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.62, 0.95, 1.0);
uniform float haze_amount = 0.45;
uniform float water_level = 0.0;
uniform float high_line = 20.0;
uniform float dirt_amount = 0.35;
uniform float rock_slope = 0.42;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 n, float s, int ch) {
	// amostra triplanar de um canal do ruído
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec4 x = texture(noise_tex, p.zy * s);
	vec4 y = texture(noise_tex, p.xz * s);
	vec4 z = texture(noise_tex, p.xy * s);
	vec4 r = x * b.x + y * b.y + z * b.z;
	return ch == 0 ? r.r : (ch == 1 ? r.g : (ch == 2 ? r.b : r.a));
}

void fragment() {
	vec4 n1 = texture(noise_tex, wpos.xz * 0.006);
	vec4 n2 = texture(noise_tex, wpos.xz * 0.03);
	vec4 n3 = texture(noise_tex, wpos.xz * 0.21);
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float h = wpos.y;
	// --- grama: manchas grandes + pinceladas alongadas (direção varia devagar pelo mapa)
	// duas direções fixas misturadas devagar (girar o UV pela posição criaria saltos em blocos)
	float st_a = texture(noise_tex, wpos.xz * vec2(0.16, 0.035)).r;
	float st_b = texture(noise_tex, wpos.zx * vec2(0.16, 0.035) + 0.37).r;
	float stroke = mix(st_a, st_b, smoothstep(0.35, 0.65, n1.g));
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.7, n1.r));
	g = mix(g, grass_c.rgb, smoothstep(0.45, 0.75, n2.g) * 0.6);
	g *= 0.9 + stroke * 0.2;
	// pontinhos claros (flores/trevos distantes) e tons amarelados no alto das colinas
	g = mix(g, g * vec3(1.12, 1.1, 0.82), smoothstep(0.55, 0.85, n2.a) * 0.35);
	// --- terra/trilhas
	float dm = smoothstep(0.62, 0.72, n2.r * 0.55 + n1.g * 0.45 + dirt_amount * 0.2 - 0.05);
	vec3 dirtc = dirt.rgb * (0.82 + n3.b * 0.3) * (0.92 + stroke * 0.16);
	vec3 col = mix(g, dirtc, dm * dirt_amount * 2.0);
	// borda da trilha levemente mais escura (pisada)
	float edge = smoothstep(0.55, 0.62, n2.r * 0.55 + n1.g * 0.45 + dirt_amount * 0.2 - 0.05) * (1.0 - dm);
	col *= 1.0 - edge * 0.08 * dirt_amount * 2.0;
	// pedrinhas
	float pebble = 1.0 - smoothstep(0.0, 0.08, n3.a);
	col = mix(col, rock.rgb * 1.15, pebble * 0.3 * (1.0 - dm * 0.5));
	// --- areia na costa com areia molhada e espuma seca
	float shore = 1.0 - smoothstep(water_level + 0.9, water_level + 1.8, h + (n2.b - 0.5) * 0.9);
	vec3 sandc = sand.rgb * (0.92 + n3.r * 0.16) * (0.95 + stroke * 0.1);
	sandc *= mix(0.68, 1.0, smoothstep(water_level - 0.2, water_level + 0.45, h));
	col = mix(col, sandc, shore);
	// --- topo (neve, rocha clara...)
	float hi = smoothstep(high_line - 1.5, high_line + 1.5, h + (n2.r - 0.5) * 4.0);
	col = mix(col, high.rgb * (0.93 + n3.g * 0.14), hi);
	// --- penhascos: rocha triplanar com estratos horizontais, fendas verticais e topo mais claro
	float rs = smoothstep(rock_slope - 0.06, rock_slope + 0.06, slope + (n2.g - 0.5) * 0.14);
	// relevo fino da grama: ruído suave em escala média (sem serrilhado)
	float d0 = texture(noise_tex, wpos.xz * 0.09).b;
	float bx = texture(noise_tex, (wpos.xz + vec2(0.35, 0.0)) * 0.09).b - d0;
	float bz = texture(noise_tex, (wpos.xz + vec2(0.0, 0.35)) * 0.09).b - d0;
	float bump_k = 0.9;
	if (rs > 0.01) {
		// só paga a projeção triplanar onde há rocha
		float strata = 0.5 + 0.5 * sin(h * 3.1 + tri(wpos, wnorm, 0.05, 0) * 7.0);
		float cracks = smoothstep(0.62, 0.7, tri(wpos * vec3(1.0, 0.25, 1.0), wnorm, 0.12, 1));
		float rgrain = tri(wpos, wnorm, 0.35, 2);
		vec3 rc = rock.rgb * (0.78 + 0.22 * strata) * (0.88 + rgrain * 0.24);
		rc = mix(rc, rc * vec3(1.06, 1.02, 0.92), smoothstep(0.6, 0.9, tri(wpos, wnorm, 0.02, 3)) * 0.6);
		rc *= 1.0 - cracks * 0.28;
		col = mix(col, rc, rs);
		// grama "derrama" na borda superior dos penhascos
		float lip = rs * (1.0 - smoothstep(0.25, 0.55, slope)) * (1.0 - hi) * (1.0 - shore);
		col = mix(col, g * 0.95, lip * 0.55);
		float rx = tri(wpos + vec3(0.12, 0.0, 0.0), wnorm, 0.35, 2) - rgrain;
		float ry = tri(wpos + vec3(0.0, 0.12, 0.0), wnorm, 0.35, 2) - rgrain;
		bx = mix(bx, rx, rs);
		bz = mix(bz, ry, rs);
		bump_k += rs * 1.6;
	}
	vec3 bump = vec3(-bx, 0.0, -bz) * bump_k;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	// --- oclusão de vales: altura local x média ao redor
	vec2 huv = (wpos.xz + vec2(map_half)) / (2.0 * map_half);
	float px = 3.0 / 129.0;
	float avg = (texture(height_tex, huv + vec2(px, 0.0)).r + texture(height_tex, huv - vec2(px, 0.0)).r
		+ texture(height_tex, huv + vec2(0.0, px)).r + texture(height_tex, huv - vec2(0.0, px)).r) * 0.25;
	float cavity = clamp((avg - texture(height_tex, huv).r) * 16.0 * 0.55, 0.0, 0.38);
	col *= 1.0 - cavity;
	col *= mix(0.84, 1.0, clamp(wnorm.y * 1.3, 0.0, 1.0));
	// manchas grandes de luz (pintura) e sombras de nuvens passando
	col *= 0.94 + n1.b * 0.12;
	float cloud = smoothstep(0.52, 0.78, texture(noise_tex, wpos.xz * 0.0035 + vec2(TIME * 0.004, TIME * 0.0025)).r);
	col *= 1.0 - cloud * 0.22;
	// fundo submerso
	float under = clamp((water_level - 0.15 - h) / 4.0, 0.0, 1.0);
	col = mix(col, deep_tint.rgb * (0.6 + n2.r * 0.3), under * 0.85);
	// névoa de distância (perspectiva aérea): dessatura e puxa para o azul do céu
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float aer = smoothstep(25.0, 170.0, dist) * haze_amount;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, mix(vec3(lum), haze.rgb, 0.65), aer);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	// degrau suave (meio pintado) com sombras de tom frio
	vec3 lc = LIGHT_COLOR / PI;
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.3) / 1.3, 0.0, 1.0);
	float lit = smoothstep(0.12, 0.62, wrap);
	if (LIGHT_IS_DIRECTIONAL) {
		lit *= smoothstep(0.15, 0.85, ATTENUATION);
		DIFFUSE_LIGHT += lc * mix(shadow_tint.rgb * 0.3, vec3(0.94, 0.9, 0.84), lit) * (0.5 + 0.5 * wrap);
	} else {
		DIFFUSE_LIGHT += lc * ATTENUATION * wrap;
	}
}
