extends StaticBody3D

# Identificador para la tienda y las reparaciones
var tipo_estructura: String = ""
@export var salud_maxima: int = 5 
var salud_actual: int

func _ready():
	# Ya no calculamos la llave aquí, solo iniciamos la vida
	salud_actual = salud_maxima

func recibir_dano(cantidad: int):
	salud_actual -= cantidad
	scale = scale * 0.9 
	
	if salud_actual <= 0:
		destruir()

func destruir():
	var mundo = get_parent()
	
	var pos_llave = Vector3(
		snapped(global_position.x, 0.1), 
		1.0, 
		snapped(global_position.z, 0.1)
	)
	
	if mundo:
		# 1. Liberamos la celda para poder volver a construir
		if "celdas_ocupadas" in mundo:
			mundo.celdas_ocupadas.erase(pos_llave)
			
		# 2. ¡NUEVO! Soltamos la chatarra en nuestra posición
		if mundo.has_method("generar_chatarra"):
			mundo.generar_chatarra(global_position)
		
	# 3. Nos eliminamos del juego
	queue_free()

# ¡NUEVO! Función para la Reparación Global
func reparar(porcentaje: float):
	var curacion = int(salud_maxima * porcentaje)
	salud_actual += curacion
	
	# Nunca curamos más allá del 100%
	if salud_actual > salud_maxima:
		salud_actual = salud_maxima
		
	# Efecto visual: Recuperamos su tamaño original proporcionalmente a su salud
	var proporcion_vida = float(salud_actual) / float(salud_maxima)
	scale = Vector3(1, 1, 1) * (0.7 + (0.3 * proporcion_vida))
	
	# ¡NUEVO! El mecánico evalúa cuánto cuesta reparar esta barricada específica
func obtener_costo_reparacion(precio_actual_nueva: int) -> int:
	if salud_actual >= salud_maxima:
		return 0 # Si está intacta, cuesta $0
		
	var hp_perdido = salud_maxima - salud_actual
	var proporcion_dano = float(hp_perdido) / float(salud_maxima)
	
	# Cobramos un 60% del precio de una nueva (así siempre es más rentable reparar que comprar)
	var costo = int(precio_actual_nueva * proporcion_dano * 0.6)
	
	return max(1, costo) # Mínimo cobramos $1 para que no haya arreglos gratis
	
	
# Repara la estructura al 100%
func reparar_completamente():
	salud_actual = salud_maxima
	scale = Vector3(1, 1, 1) # Restauramos su tamaño visual original
