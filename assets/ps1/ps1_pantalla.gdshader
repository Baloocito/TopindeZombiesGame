// ==========================================================
// FILTRO DE PANTALLA PS1
// ==========================================================
// Se dibuja encima del 3D y debajo de la interfaz (CanvasLayer 0):
// - Baja la imagen a `lineas` de alto con píxeles grandes y nítidos.
// - Reduce los colores a `niveles` por canal (la PS1 usaba 15 bits = 32)
//   con tramado ordenado (Bayer 4x4), que es lo que daba ese grano tan suyo.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float lineas = 270.0;
uniform float niveles = 32.0;
uniform float tramado = 1.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	float aspecto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 virtual_res = vec2(floor(lineas * aspecto), lineas);
	vec2 celda = floor(SCREEN_UV * virtual_res);
	vec2 uv = (celda + 0.5) / virtual_res;
	vec3 col = texture(pantalla, uv).rgb;
	int i = int(mod(celda.x, 4.0)) + int(mod(celda.y, 4.0)) * 4;
	float b = (BAYER[i] / 16.0 - 0.5) * tramado;
	col = floor(col * niveles + b + 0.5) / niveles;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
