shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Oceano: ondas grandes (geometria) + ripples finas de um NORMAL MAP rolando em
// duas direções (detalhe de água) + espuma esparsa + reflexo do céu (Fresnel).

uniform sampler2D normalmap;
uniform vec3 cor_funda : source_color = vec3(0.004, 0.045, 0.11);
uniform vec3 cor_rasa : source_color = vec3(0.02, 0.20, 0.34);
uniform vec3 cor_reflexo : source_color = vec3(0.30, 0.50, 0.64);
uniform vec3 cor_espuma : source_color = vec3(0.92, 0.96, 0.98);
uniform float velocidade = 0.6;
uniform float amplitude = 0.9;
uniform float nm_escala = 0.018;     // tamanho das ripples
uniform float nm_velocidade = 0.6;   // velocidade das ripples
uniform float nm_forca = 0.35;       // intensidade das ripples

const vec2 D1 = vec2(1.0, 0.25);
const vec2 D2 = vec2(-0.5, 1.0);
const vec2 D3 = vec2(0.7, -0.6);
const vec2 D4 = vec2(-0.85, -0.4);

float altura(vec2 p, float t) {
	float h = sin(dot(normalize(D1), p) * 0.030 + t * 1.00) * 1.00;
	h += sin(dot(normalize(D2), p) * 0.052 + t * 1.25) * 0.55;
	h += sin(dot(normalize(D3), p) * 0.090 + t * 0.90) * 0.30;
	h += sin(dot(normalize(D4), p) * 0.150 + t * 1.60) * 0.16;
	return h * amplitude;
}

varying float onda_altura;
varying vec3 pos_mundo;

void vertex() {
	float t = TIME * velocidade;
	vec2 p = VERTEX.xz;
	float h = altura(p, t);
	VERTEX.y += h;
	onda_altura = h;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// normal das ondas grandes (diferenças finitas)
	float t = TIME * velocidade;
	vec2 p = pos_mundo.xz;
	float e = 0.8;
	float h = altura(p, t);
	float hx = altura(p + vec2(e, 0.0), t);
	float hz = altura(p + vec2(0.0, e), t);
	vec3 n_onda = normalize(vec3(-(hx - h) / e * 2.0, 1.0, -(hz - h) / e * 2.0));

	// ripples finas: normal map rolando em 2 direções
	float tt = TIME * nm_velocidade;
	vec3 r1 = texture(normalmap, p * nm_escala + vec2(tt * 0.02, tt * 0.013)).xyz * 2.0 - 1.0;
	vec3 r2 = texture(normalmap, p * nm_escala * 2.1 + vec2(-tt * 0.017, tt * 0.011)).xyz * 2.0 - 1.0;
	vec3 ripple = (r1 + r2) * nm_forca;

	// normal final em mundo, depois converte p/ espaço de visão
	vec3 wn = normalize(n_onda + vec3(ripple.x, 0.0, ripple.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Fresnel: de cima fica azul; de raspão reflete o céu
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 5.0);
	float prof = clamp(onda_altura * 0.4 + 0.5, 0.0, 1.0);
	vec3 cor = mix(cor_funda, cor_rasa, prof);
	cor = mix(cor, cor_reflexo, fres * 0.6);

	float espuma = smoothstep(1.3 * amplitude, 1.7 * amplitude, onda_altura);
	cor = mix(cor, cor_espuma, espuma);

	ALBEDO = cor;
	METALLIC = 0.0;
	ROUGHNESS = 0.08 + espuma * 0.6;
	SPECULAR = 0.7;
}
