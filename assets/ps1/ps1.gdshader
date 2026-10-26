// ==========================================================
// MATERIAL PS1 (Manual v3: estética low-poly entre PS1 y PS2)
// ==========================================================
// - Los vértices "saltan" a una grilla de baja resolución (ps1_resolucion):
//   el temblor típico de la PlayStation, que no tenía precisión subpíxel.
// - Texturas sin corrección de perspectiva (mapeo afín) y sin filtrado.
// - Luz calculada por vértice (Gouraud), sin brillos especulares.
// Scripts/autoload/ps1.gd convierte automáticamente los StandardMaterial3D
// opacos de la escena a este material.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

global uniform vec2 ps1_resolucion;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest, repeat_enable;
uniform bool usar_textura = false;
uniform bool usar_color_vertice = false;
uniform vec3 uv_escala = vec3(1.0);
uniform vec3 uv_desfase = vec3(0.0);
uniform vec4 emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emision_energia = 0.0;
// 0 = sin temblor, 1 = temblor completo.
uniform float fuerza_temblor = 1.0;
// Afín: 1 = como PS1 (las texturas se deforman), 0 = corregido.
uniform float fuerza_afin = 1.0;

// Tinte por instancia (los zombies se pintan según su tipo). a = intensidad.
instance uniform vec4 ps1_tinte = vec4(0.0);

varying vec3 uv_afin;
varying vec2 uv_correcto;

void vertex() {
	UV = UV * uv_escala.xy + uv_desfase.xy;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 media = max(ps1_resolucion, vec2(64.0)) * 0.5;
	vec2 ndc = clip.xy / clip.w;
	vec2 ajustado = floor(ndc * media + 0.5) / media;
	clip.xy = mix(ndc, ajustado, fuerza_temblor) * clip.w;
	POSITION = clip;
	uv_afin = vec3(UV * clip.w, clip.w);
	uv_correcto = UV;
}

void fragment() {
	vec2 uv = mix(uv_correcto, uv_afin.xy / uv_afin.z, fuerza_afin);
	vec4 c = albedo;
	if (usar_color_vertice) c *= COLOR;
	if (usar_textura) c *= texture(textura, uv);
	ALBEDO = mix(c.rgb, ps1_tinte.rgb, ps1_tinte.a);
	EMISSION = emision.rgb * emision_energia;
}
