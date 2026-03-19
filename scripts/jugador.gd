extends CharacterBody3D

# ==========================================================
# 1. SISTEMA RPG Y ESTADÍSTICAS (GDD)
# ==========================================================
var nivel: int = 1
var experiencia_actual: int = 0
var puntos_mejora: int = 0

var stat_salud_maxima: int = 100
var salud_actual: int
var stat_agilidad: float = 4.0
var stat_destreza: float = 1.0 # 1.0 = 100% velocidad de recarga
var stat_ingenieria: float = 1.0 # Multiplicador de vida para torretas/muros
var stat_recoleccion: float = 3.0 # Metros de radio del imán de oro

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- REFERENCIAS UI ---
@onready var lbl_salud_num = $"../InterfazUI/HudEstadisticas/FilaSalud/LblSaludNum"
@onready var barra_salud = $"../InterfazUI/HudEstadisticas/BarraSalud"
@onready var lbl_nivel = $"../InterfazUI/HudEstadisticas/LblNivel"
@onready var barra_xp = $"../InterfazUI/HudEstadisticas/BarraXP"
@onready var panel_nivel_up = $"../InterfazUI/ContenedorAlertas/PanelNivelUp"
@onready var lbl_puntos_mejora = $"../InterfazUI/ContenedorAlertas/PanelNivelUp/LblPuntos"
# --- NUEVAS REFERENCIAS ARMAS (HUD Inferior Derecho) ---
@onready var contenedor_armas = $"../InterfazUI/EsquinaArmas"
@onready var lbl_nombre_arma = $"../InterfazUI/EsquinaArmas/HBoxContainer/PanelMunicion/VBoxContainer/LblNombreArma"
@onready var lbl_balas = $"../InterfazUI/EsquinaArmas/HBoxContainer/PanelMunicion/VBoxContainer/LblBalas"
@onready var boton_recargar = $"../InterfazUI/EsquinaArmas/HBoxContainer/CajaBotonesArma/BotonRecargar"
var tween_nivel: Tween

# ==========================================================
# 2. SISTEMA DE ARMAS E INVENTARIO
# ==========================================================
@export var bala_escena: PackedScene
@onready var punto_disparo = $PuntoDisparo
const PISTOLA_INICIAL = preload("res://materials/pistola.tres") 

var armas_inventario: Array[ArmaData] = [] 
var armas_equipadas: Array[ArmaData] = [null, null, null] 
var cargadores_equipados: Array[int] = [0, 0, 0] 

var arma_actual: ArmaData 
var slot_actual: int = 0 
var balas_en_cargador: int = 0
var esta_recargando: bool = false
var temporizador_disparo: float = 0.0

var municion_reserva: Dictionary = {
	"Ligera": 90,
	"Pesada": 12,
	"Energia": 0
}

# ==========================================================
# 3. INICIALIZACIÓN
# ==========================================================
func _ready():
	salud_actual = stat_salud_maxima
	actualizar_ui_vida()
	actualizar_ui_xp()
		
	armas_inventario.append(PISTOLA_INICIAL)
	equipar_en_slot(PISTOLA_INICIAL, 0)
	cambiar_arma(0)
	
	# --- TRUCO DE PRUEBA (Borrar en versión final) ---
	var escopeta = load("res://materials/escopeta.tres")
	var smg = load("res://materials/smg.tres")
	if escopeta: armas_inventario.append(escopeta)
	if smg: armas_inventario.append(smg)
	# ------------------------------------------------
	

# ==========================================================
# 4. MOVIMIENTO Y FÍSICAS (Afectado por Agilidad)
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# ¡CONECTADO AL RPG! Usamos stat_agilidad en lugar de speed
	if direction:
		velocity.x = direction.x * stat_agilidad
		velocity.z = direction.z * stat_agilidad
	else:
		velocity.x = move_toward(velocity.x, 0, stat_agilidad)
		velocity.z = move_toward(velocity.z, 0, stat_agilidad)

	temporizador_disparo += delta

	var aim_dir := Input.get_vector("apuntar_izq", "apuntar_der", "apuntar_arriba", "apuntar_abajo")
	if aim_dir.length() > 0.1:
		var angulo_objetivo = atan2(aim_dir.x, aim_dir.y)		
		rotation.y = angulo_objetivo
		intentar_disparar()
			
	move_and_slide()	

# ==========================================================
# 5. GESTIÓN DE ARMAS Y DISPARO
# ==========================================================
func equipar_en_slot(nueva_arma: ArmaData, slot: int):
	if slot < 0 or slot > 2: return
	armas_equipadas[slot] = nueva_arma
	cargadores_equipados[slot] = nueva_arma.tamano_cargador 
	print("Equipada ", nueva_arma.nombre, " en el slot ", slot + 1)

func cambiar_arma(slot: int):
	if slot < 0 or slot > 2 or armas_equipadas[slot] == null: return 
	
	if arma_actual != null:
		cargadores_equipados[slot_actual] = balas_en_cargador
		
	slot_actual = slot
	arma_actual = armas_equipadas[slot]
	balas_en_cargador = cargadores_equipados[slot]
	
	esta_recargando = false 
	temporizador_disparo = 1.0 
	actualizar_ui_municion()

func ciclo_arma_rapido():
	var siguiente_slot = slot_actual
	for i in range(3):
		siguiente_slot = (siguiente_slot + 1) % 3
		if armas_equipadas[siguiente_slot] != null:
			cambiar_arma(siguiente_slot)
			return

func intentar_disparar():
	if not arma_actual or esta_recargando: return
		
	var tiempo_entre_balas = 1.0 / arma_actual.cadencia
	if temporizador_disparo >= tiempo_entre_balas:
		if balas_en_cargador > 0:
			ejecutar_disparo()
		else:
			recargar() 

func ejecutar_disparo():
	if not bala_escena: return

	temporizador_disparo = 0.0 
	balas_en_cargador -= 1 
	actualizar_ui_municion() 
	
	var dispersion_rad = deg_to_rad(arma_actual.dispersion) if arma_actual.dispersion > 0.0 else 0.0
	
	for i in range(arma_actual.balas_por_disparo):
		var nueva_bala = bala_escena.instantiate()
		get_parent().add_child(nueva_bala)
		nueva_bala.global_transform = punto_disparo.global_transform
		
		if dispersion_rad > 0.0:
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)
		
		if "dano" in nueva_bala:
			nueva_bala.dano = arma_actual.dano

func recargar():
	if not arma_actual or esta_recargando or balas_en_cargador == arma_actual.tamano_cargador: return
		
	var tipo = arma_actual.tipo_municion
	if municion_reserva[tipo] <= 0: return
		
	esta_recargando = true
	if boton_recargar: boton_recargar.disabled = true 
	actualizar_ui_municion() 
	
	# ¡CONECTADO AL RPG! Destreza reduce el tiempo de recarga
	var tiempo_real = arma_actual.tiempo_recarga / stat_destreza
	await get_tree().create_timer(tiempo_real).timeout
	
	var balas_necesarias = arma_actual.tamano_cargador - balas_en_cargador
	if municion_reserva[tipo] >= balas_necesarias:
		balas_en_cargador += balas_necesarias
		municion_reserva[tipo] -= balas_necesarias
	else:
		balas_en_cargador += municion_reserva[tipo]
		municion_reserva[tipo] = 0
		
	esta_recargando = false
	if boton_recargar: boton_recargar.disabled = false
	actualizar_ui_municion()

func recoger_municion(cantidad: int, tipo: String):
	if municion_reserva.has(tipo):
		municion_reserva[tipo] += cantidad
		actualizar_ui_municion()

# ==========================================================
# 6. SISTEMA DE SALUD, DAÑO Y SUBIDA DE NIVEL
# ==========================================================
func actualizar_ui_vida():
	if lbl_salud_num and barra_salud:
		lbl_salud_num.text = "%s / %s" % [salud_actual, stat_salud_maxima]
		barra_salud.max_value = stat_salud_maxima
		
		# Animación fluida para la barra de vida (¡Toque profesional!)
		var tween = create_tween()
		tween.tween_property(barra_salud, "value", float(salud_actual), 0.2).set_trans(Tween.TRANS_SINE)

func actualizar_ui_xp():
	if lbl_nivel and barra_xp:
		var xp_necesaria = 500 + (nivel * 200)
		lbl_nivel.text = "NIVEL %s" % nivel
		barra_xp.max_value = xp_necesaria
		
		var tween = create_tween()
		tween.tween_property(barra_xp, "value", float(experiencia_actual), 0.2).set_trans(Tween.TRANS_SINE)


func actualizar_ui_municion():
	# Medida de seguridad por si el nodo aún no carga
	if not contenedor_armas: return
	
	# Si el jugador no tiene arma en la mano, ocultamos todo el panel
	if not arma_actual:
		contenedor_armas.visible = false
		return
		
	# Si tiene arma, mostramos el panel
	contenedor_armas.visible = true
		
	if esta_recargando:
		lbl_nombre_arma.text = arma_actual.nombre
		lbl_balas.text = "Recargando..."
		lbl_balas.modulate = Color(1, 0.8, 0.2) # Color Amarillo/Naranja
	else:
		var tipo = arma_actual.tipo_municion
		lbl_nombre_arma.text = arma_actual.nombre
		lbl_balas.text = "%s / %s" % [balas_en_cargador, municion_reserva[tipo]]
		
		# Efecto visual: Si nos quedamos sin balas en el cargador, el texto se pone rojo
		if balas_en_cargador == 0:
			lbl_balas.modulate = Color(1, 0.2, 0.2)
		else:
			lbl_balas.modulate = Color.WHITE
func recibir_dano(cantidad: int):
	salud_actual -= cantidad
	actualizar_ui_vida()
	if salud_actual <= 0: morir()

func morir():
	var mundo = get_parent()
	if mundo.has_method("ejecutar_game_over"): mundo.ejecutar_game_over()
	visible = false
	set_physics_process(false)
	
func curar(porcentaje: float):
	if salud_actual >= stat_salud_maxima: return
	var cantidad_curacion = max(1, int(stat_salud_maxima * porcentaje)) 
	salud_actual = min(salud_actual + cantidad_curacion, stat_salud_maxima)
	actualizar_ui_vida()

func ganar_experiencia(cantidad: int):
	experiencia_actual += cantidad
	var xp_necesaria = 500 + (nivel * 200)
	
	if experiencia_actual >= xp_necesaria:
		subir_nivel()
	else:
		actualizar_ui_xp() # Actualiza la barra si no subió de nivel

func subir_nivel():
	var xp_necesaria = 500 + (nivel * 200)
	experiencia_actual -= xp_necesaria 
	nivel += 1
	puntos_mejora += 3
	salud_actual = stat_salud_maxima 
	
	actualizar_ui_vida()
	actualizar_ui_xp() 
	
		
	# ==========================================
	# ¡NUEVO! ANIMACIÓN DE ALERTA DE NIVEL UP
	# ==========================================
	if panel_nivel_up and lbl_puntos_mejora:
		lbl_puntos_mejora.text = "+" + str(puntos_mejora) + " Puntos de Mejora"
		panel_nivel_up.visible = true
		panel_nivel_up.modulate.a = 0.0 # Transparente al inicio
		
		if tween_nivel: tween_nivel.kill()
		tween_nivel = create_tween()
		# Aparece suavemente
		tween_nivel.tween_property(panel_nivel_up, "modulate:a", 1.0, 0.3)
		# Se queda visible 3 segundos
		tween_nivel.tween_interval(3.0)
		# Se desvanece
		tween_nivel.tween_property(panel_nivel_up, "modulate:a", 0.0, 0.5)
		# Lo apagamos para ahorrar memoria
		tween_nivel.tween_callback(func(): panel_nivel_up.visible = false)
		
	if experiencia_actual >= (500 + (nivel * 200)):
		subir_nivel()

func mejorar_estadistica(estadistica: String):
	if puntos_mejora <= 0: return
	
	match estadistica:
		"salud":
			stat_salud_maxima += 10
			salud_actual += 10 
			actualizar_ui_vida()
		"agilidad": stat_agilidad += 0.2
		"destreza": stat_destreza += 0.05
		"ingenieria": stat_ingenieria += 0.1
		"recoleccion": stat_recoleccion += 0.5
			
	puntos_mejora -= 1

# --- SEÑALES DE BOTONES UI ---
func _on_boton_cambiar_arma_pressed() -> void: ciclo_arma_rapido()
func _on_boton_recargar_pressed(): recargar()
