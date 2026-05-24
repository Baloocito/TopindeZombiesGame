extends StaticBody3D

# ==========================================================
# 1. ATRIBUTOS Y ESTADO
# ==========================================================
@export_category("Propiedades de la Estructura")
var tipo_estructura: String = ""
@export var salud_maxima: int = 500 # Default de seguridad (se sobrescribe en mundo.gd)
var salud_actual: int

var tween_dano: Tween # Controlador de animaciones elásticas

# ==========================================================
# 2. INICIALIZACIÓN
# ==========================================================
func _ready():
	salud_actual = salud_maxima
	
	# ¡BLINDAJE!: Aseguramos por código que pertenezca al grupo "barricadas"
	# para que los zombies y el sistema de reparación global la encuentren siempre.
	if not is_in_group("barricadas"):
		add_to_group("barricadas")

# ==========================================================
# 3. SISTEMA DE DAÑO Y DESTRUCCIÓN
# ==========================================================
func recibir_dano(cantidad: int):
	salud_actual -= cantidad
	
	# Efecto visual "Juicy": Animación de rebote al recibir un golpe
	if tween_dano: tween_dano.kill()
	tween_dano = create_tween()
	
	# Calculamos el tamaño basado en la vida restante (nunca menor al 40% de su tamaño original)
	var proporcion = max(0.4, float(salud_actual) / float(salud_maxima))
	var escala_base = Vector3(1, 1, 1) * (0.6 + (0.4 * proporcion))
	
	# Se aplasta un poquito por el impacto y luego rebota a su escala base
	tween_dano.tween_property(self, "scale", escala_base * 0.8, 0.05).set_trans(Tween.TRANS_SINE)
	tween_dano.tween_property(self, "scale", escala_base, 0.15).set_trans(Tween.TRANS_BOUNCE)
	
	if salud_actual <= 0:
		destruir()

func destruir():
	var mundo = get_parent()
	
	# Misma lógica exacta de tu mundo.gd para liberar la grilla magnética
	var pos_llave = Vector3(
		snapped(global_position.x, 0.1), 
		1.0, 
		snapped(global_position.z, 0.1)
	)
	
	if is_instance_valid(mundo):
		if "celdas_ocupadas" in mundo:
			mundo.celdas_ocupadas.erase(pos_llave)
			
		if mundo.has_method("generar_chatarra"):
			mundo.generar_chatarra(global_position)
		
	queue_free()

# ==========================================================
# 4. SISTEMA DE REPARACIÓN (Ingeniería)
# ==========================================================
func reparar(porcentaje: float):
	var curacion = int(salud_maxima * porcentaje)
	salud_actual += curacion
	
	if salud_actual > salud_maxima:
		salud_actual = salud_maxima
		
	var proporcion_vida = float(salud_actual) / float(salud_maxima)
	
	# Animación suave de recuperación
	if tween_dano: tween_dano.kill()
	tween_dano = create_tween()
	tween_dano.tween_property(self, "scale", Vector3(1, 1, 1) * (0.7 + (0.3 * proporcion_vida)), 0.3).set_trans(Tween.TRANS_BACK)

func obtener_costo_reparacion(precio_actual_nueva: int) -> int:
	if salud_actual >= salud_maxima:
		return 0 
		
	var hp_perdido = salud_maxima - salud_actual
	var proporcion_dano = float(hp_perdido) / float(salud_maxima)
	
	# Cobramos un 60% del precio de una nueva
	var costo = int(precio_actual_nueva * proporcion_dano * 0.6)
	return max(1, costo) # Mínimo $1
	
func reparar_completamente():
	salud_actual = salud_maxima
	
	# Restauramos su tamaño visual original con un rebote de satisfacción
	if tween_dano: tween_dano.kill()
	tween_dano = create_tween()
	tween_dano.tween_property(self, "scale", Vector3(1, 1, 1), 0.4).set_trans(Tween.TRANS_BOUNCE)
