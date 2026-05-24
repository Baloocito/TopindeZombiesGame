shader_type spatial;
render_mode unshaded, blend_add; // unshaded le quita las sombras, blend_add lo hace brillar como neón

uniform vec3 color_linea : source_color = vec3(0.0, 0.8, 1.0); // Azul neón por defecto
uniform float subdivisiones = 25.0; // Si tu mapa mide 50 y la grilla es 2.0 (50 / 2 = 25)
uniform float grosor_linea = 0.04; // Ajusta qué tan gruesas quieres las líneas
uniform float opacidad = 0.6; // Qué tan fuerte brilla el neón

void fragment() {
    // Escalar la grilla a las medidas de tu mapa
    vec2 uv_escalado = UV * subdivisiones;
    vec2 grilla = fract(uv_escalado);
    
    // Matemática pura: dibuja la línea solo en los bordes de la celda
    float valor_linea = step(grilla.x, grosor_linea) + step(grilla.y, grosor_linea);
    
    ALBEDO = color_linea;
    
    // Si es una línea, usa la opacidad. Si es el centro del cuadro, transparencia total (0.0)
    ALPHA = clamp(valor_linea, 0.0, 1.0) * opacidad;
}