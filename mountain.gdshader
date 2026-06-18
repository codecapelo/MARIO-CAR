shader_type spatial;
render_mode cull_back;

// Montanha realista: silhueta irregular (deslocamento por ruído) E iluminação do
// relevo (perturbo a NORMAL pelo gradiente do ruído -> rocha com luz e sombra).
// Cor por altura (floresta -> rocha -> neve); neve só onde é alto E pouco íngreme.

varying vec3 pos_mundo;
varying vec3 normal_mundo;

uniform vec3 cor_grama : source_color = vec3(0.16, 0.33, 0.13);
uniform vec3 cor_mato : source_color = vec3(0.28, 0.39, 0.18);
uniform vec3 cor_rocha : source_color = vec3(0.33, 0.29, 0.25);
uniform vec3 cor_rocha_clara : source_color = vec3(0.50, 0.47, 0.43);
uniform vec3 cor_neve : source_color = vec3(0.95, 0.96, 0.99);
uniform float rugosidade_geo = 16.0;
uniform float forca_bump = 26.0;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i+vec3(0,0,0)), hash(i+vec3(1,0,0)), f.x),
				   mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
			   mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x),
				   mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; } return v; }

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = fbm(wp * 0.022) - 0.5;
	vec3 radial = normalize(vec3(VERTEX.x, 0.0, VERTEX.z) + vec3(0.0001));
	VERTEX += radial * n * rugosidade_geo;
	VERTEX.y += (fbm(wp * 0.05 + 13.0) - 0.5) * rugosidade_geo * 0.5;
	vec4 wp2 = MODEL_MATRIX * vec4(VERTEX, 1.0);
	pos_mundo = wp2.xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// BUMP: perturba a normal pelo gradiente do ruído -> relevo iluminado
	float e = 2.5;
	float h0 = fbm(pos_mundo * 0.06);
	vec3 grad = vec3(
		fbm((pos_mundo + vec3(e, 0, 0)) * 0.06) - h0,
		fbm((pos_mundo + vec3(0, e, 0)) * 0.06) - h0,
		fbm((pos_mundo + vec3(0, 0, e)) * 0.06) - h0) / e;
	vec3 wn = normalize(normal_mundo - grad * forca_bump);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// cor por altura (com ruído quebrando as faixas)
	float ruido = fbm(pos_mundo * 0.05);
	float h = pos_mundo.y + (ruido - 0.5) * 36.0;
	vec3 c = mix(cor_grama, cor_mato, smoothstep(-5.0, 28.0, h));
	c = mix(c, cor_rocha, smoothstep(30.0, 60.0, h));
	c = mix(c, cor_rocha_clara, smoothstep(56.0, 94.0, h));
	// neve: alto E pouco íngreme (não gruda em parede de rocha)
	float plano = clamp(wn.y, 0.0, 1.0);
	float neve = smoothstep(96.0, 135.0, h) * smoothstep(0.4, 0.72, plano);
	c = mix(c, cor_neve, neve);
	c *= 0.80 + 0.34 * ruido;

	ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
}
