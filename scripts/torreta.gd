extends StaticBody3D

# ==========================================================
# 1. ESTADÍSTICAS Y ESTADO
# ==========================================================
@export_category("Configuración")
var salud_maxima: int = 100
var salud_actual: int
var tipo_estructura: String = ""

# --- SISTEMA DE COMBATE ---
var arma_equipada: ArmaData = null
var balas_cargadas: int = 0
var objetivo_actual: Node3D = null
var temporizador_disparo: float = 0.0
var enemigos_en_rango: Array[Node3D] = []

# --- INTELIGENCIA DE APUNTADO ---
var velocidad_giro: float = 12.0 # Qué tan rápido gira el "cuello" de la torreta
var velocidad_bala_estimada: float = 30.0 # ¡NUEVO! Ajusta esto a la velocidad real de tu bala
var alineado_para_disparar: bool = false

# --- REFERENCIAS ---
@onready var cabezal = $Cabezal
@onready var punto_disparo = $Cabezal/PuntoDisparo
@export var bala_escena: PackedScene

# ==========================================================
# 2. INICIALIZACIÓN Y LOOP PRINCIPAL
# ==========================================================
func _ready():
	salud_actual = salud_maxima

func _physics_process(delta):
	# --- FIX (revisión de código) ---
	# Antes esta función corría en TODOS los peers por igual: cada cliente
	# calculaba su propia puntería y disparaba sus propias balas locales,
	# que nunca hacían daño real (zombie.gd solo acepta daño del servidor).
	# Con el MultiplayerSynchronizer nuevo, el servidor es la autoridad y
	# replica salud_actual / balas_cargadas / Cabezal.rotation a todos.
	# Los clientes ahora solo VEN el resultado, no simulan la torreta.
	if not multiplayer.is_server(): return

	# 1. Mantenimiento del radar
	enemigos_en_rango = enemigos_en_rango.filter(func(enemigo): return is_instance_valid(enemigo) and enemigo.salud_actual > 0)

	# 2. Búsqueda inteligente
	if not is_instance_valid(objetivo_actual) or objetivo_actual.salud_actual <= 0:
		buscar_nuevo_objetivo()

	# 3. Lógica de Apuntado y Disparo Disciplinado
	if is_instance_valid(objetivo_actual) and arma_equipada and balas_cargadas > 0:
		apuntar_a_objetivo(delta)

		# ¡EL TRUCO MILITAR!: Solo dispara si el cañón ya está alineado con el zombie
		if alineado_para_disparar:
			temporizador_disparo += delta
			var tiempo_entre_balas = 1.0 / arma_equipada.cadencia
			if temporizador_disparo >= tiempo_entre_balas:
				disparar()
	else:
		temporizador_disparo = 0.0 # No guardamos la "carga" del disparo si perdemos el objetivo

# ==========================================================
# 3. CEREBRO DE PUNTERÍA (PREDICCIÓN)
# ==========================================================
func apuntar_a_objetivo(delta):
	# A. Puntería Predictiva (Leading)
	var distancia = global_position.distance_to(objetivo_actual.global_position)
	var tiempo_vuelo = distancia / velocidad_bala_estimada

	var pos_futura = objetivo_actual.global_position
	# Si el zombie se está moviendo, calculamos dónde estará cuando llegue la bala
	if "velocity" in objetivo_actual:
		pos_futura += (objetivo_actual.velocity * tiempo_vuelo)

	var pos_mirar = Vector3(pos_futura.x, cabezal.global_position.y, pos_futura.z)

	# B. Rotación suave y controlada
	var rotacion_actual = cabezal.rotation.y

	# Usamos un look_at instantáneo falso para saber a qué ángulo debemos llegar
	cabezal.look_at(pos_mirar, Vector3.UP)
	cabezal.rotate_y(PI) # Tu corrección de 180 grados
	var rotacion_deseada = cabezal.rotation.y

	# Restauramos el cabezal a donde estaba y lo movemos suavemente (lerp)
	cabezal.rotation.y = rotacion_actual
	cabezal.rotation.y = lerp_angle(cabezal.rotation.y, rotacion_deseada, velocidad_giro * delta)

	# C. Disciplina de gatillo: ¿Estamos apuntando directamente a la posición futura?
	# Permitimos un margen de error de 8 grados para empezar a soltar balas.
	var diferencia_angulo = abs(angle_difference(cabezal.rotation.y, rotacion_deseada))
	alineado_para_disparar = diferencia_angulo < deg_to_rad(8.0)

func disparar():
	temporizador_disparo = 0.0
	balas_cargadas -= 1

	if not bala_escena: return

	var dispersion_rad = deg_to_rad(arma_equipada.dispersion) if arma_equipada.dispersion > 0.0 else 0.0

	for i in range(arma_equipada.balas_por_disparo):
		var nueva_bala = bala_escena.instantiate()
		get_tree().current_scene.add_child(nueva_bala)
		nueva_bala.global_transform = punto_disparo.global_transform

		if dispersion_rad > 0.0:
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)

		if "dano" in nueva_bala:
			nueva_bala.dano = arma_equipada.dano

# ==========================================================
# 4. SISTEMA DE RADAR Y SELECCIÓN DE OBJETIVOS
# ==========================================================
func _on_area_deteccion_body_entered(body):
	if body.is_in_group("enemigos"):
		enemigos_en_rango.append(body)

func _on_area_deteccion_body_exited(body):
	if body in enemigos_en_rango:
		enemigos_en_rango.erase(body)
		if objetivo_actual == body:
			objetivo_actual = null

func buscar_nuevo_objetivo():
	if enemigos_en_rango.is_empty():
		objetivo_actual = null
		return

	# ¡NUEVO! Escáner láser: Elegimos siempre al zombie que esté físicamente más cerca
	var mas_cercano = null
	var distancia_minima = INF

	for enemigo in enemigos_en_rango:
		# distance_squared_to es matemáticamente más rápido para procesadores de celulares
		var dist = global_position.distance_squared_to(enemigo.global_position)
		if dist < distancia_minima:
			distancia_minima = dist
			mas_cercano = enemigo

	objetivo_actual = mas_cercano

# ==========================================================
# 5. SISTEMA DE DAÑO Y REPARACIÓN
# ==========================================================
func recibir_dano(cantidad: int):
	# --- FIX (revisión de código) ---
	# Igual que barricada.gd, esto debe correr solo en el servidor: si no,
	# cada cliente descuenta vida de su copia local de forma independiente
	# y podría hacer que la torreta se destruya (queue_free) en un cliente
	# sin que el servidor (el que realmente importa) se entere.
	if not multiplayer.is_server(): return

	salud_actual -= cantidad
	if salud_actual <= 0:
		var mundo = get_parent()
		if mundo.has_method("generar_chatarra"):
			mundo.generar_chatarra(global_position)
		queue_free()

func obtener_costo_reparacion(precio_base_nuevo: int) -> int:
	if salud_actual >= salud_maxima: return 0
	var porcentaje_dano = 1.0 - (float(salud_actual) / float(salud_maxima))
	return int((precio_base_nuevo * 0.5) * porcentaje_dano)

func reparar_completamente():
	if not multiplayer.is_server(): return
	salud_actual = salud_maxima

# --- INTERACCIÓN TÁCTIL ---
func _input_event(camera, event, position, normal, shape_idx):
	var es_clic = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var es_toque = event is InputEventScreenTouch and event.pressed

	if es_clic or es_toque:
		var mundo = get_tree().current_scene
		if mundo.has_method("abrir_menu_inspector"):
			mundo.abrir_menu_inspector(self)
