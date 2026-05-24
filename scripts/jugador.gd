extends CharacterBody3D

# ==========================================================
# 1. SISTEMA RPG Y ESTADÍSTICAS (GDD OFICIAL)
# ==========================================================
@export_category("Configuración RPG")
var nivel: int = 1
var experiencia_actual: int = 0
var puntos_mejora: int = 0

var stat_salud_maxima: int = 100
var salud_actual: int
var stat_agilidad: float = 4.0
var stat_destreza: float = 1.0       # Multiplicador de velocidad de recarga
var stat_ingenieria: float = 1.0     # Multiplicador de HP para estructuras/torretas
var stat_recoleccion: float = 3.0    # Radio de atracción del imán de monedas

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- REFERENCIAS UI GENERALES (Rutas Absolutas Blindadas) ---
@onready var lbl_salud_num = $"../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/FilaSalud/LblSaludNum"
@onready var barra_salud = $"../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/BarraSalud"
@onready var lbl_nivel = $"../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/LblNivel"
@onready var barra_xp = $"../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/BarraXP"
@onready var panel_nivel_up = $"../InterfazUI/ContenedorAlertas/PanelNivelUp"
@onready var lbl_puntos_mejora = $"../InterfazUI/ContenedorAlertas/PanelNivelUp/LblPuntos"

# --- REFERENCIAS UI INVENTARIO DE COMBATE (Arreglo Modular Escalable) ---
@onready var slots_ui: Array = [
	$"../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma1",
	$"../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma2",
	$"../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma3"
]

var tween_nivel: Tween

# ==========================================================
# 2. SISTEMA DE ARMAS E INVENTARIO
# ==========================================================
@export_category("Ajustes de Combate")
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

var can_fire_fase: bool = false # Bloqueo táctico de Día / Noche

var municion_reserva: Dictionary = {
	"Ligera": 90,
	"Pesada": 12,
	"Energia": 0
}

# ==========================================================
# 3. INICIALIZACIÓN Y CONFIGURACIÓN
# ==========================================================
func _ready():
	salud_actual = stat_salud_maxima
	actualizar_ui_vida()
	actualizar_ui_xp()
		
	# Inyección del equipamiento base
	armas_inventario.append(PISTOLA_INICIAL)
	equipar_en_slot(PISTOLA_INICIAL, 0)
	cambiar_arma(0)
	
	# --- BANCO DE PRUEBAS AUTOMÁTICO (Desarrollo) ---
	var escopeta = load("res://materials/escopeta.tres")
	var smg = load("res://materials/smg.tres")
	if escopeta: armas_inventario.append(escopeta)
	if smg: armas_inventario.append(smg)

# Permite al script del mundo alternar los joysticks e impedir disparos residuales
func set_can_fire(valor: bool) -> void:
	can_fire_fase = valor

# ==========================================================
# 4. LOOP DE FÍSICAS Y CONTROLES MÓVILES (Agilidad Integrada)
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Procesamiento vector de movimiento analógico
	var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * stat_agilidad
		velocity.z = direction.z * stat_agilidad
	else:
		velocity.x = move_toward(velocity.x, 0, stat_agilidad)
		velocity.z = move_toward(velocity.z, 0, stat_agilidad)

	temporizador_disparo += delta

	# Sistema Ergonómico Dual-Thumb para apuntar y abrir fuego
	var aim_dir := Input.get_vector("apuntar_izq", "apuntar_der", "apuntar_arriba", "apuntar_abajo")
	
	# Zona Muerta (10%): Evita micro-giros involuntarios involuntarios
	if aim_dir.length() > 0.1:
		var angulo_objetivo = atan2(aim_dir.x, aim_dir.y)        
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, 15.0 * delta)
		
		# Umbral de Guerra (60%): Dispara automáticamente al extender el pulgar
		if aim_dir.length() > 0.6 and can_fire_fase:
			intentar_disparar()
			
	move_and_slide()

# ==========================================================
# 5. LÓGICA CORE DE COMBATE, SLOTS Y RECARGA
# ==========================================================
func equipar_en_slot(nueva_arma: ArmaData, slot: int):
	if slot < 0 or slot > 2: return
	armas_equipadas[slot] = nueva_arma
	cargadores_equipados[slot] = nueva_arma.tamano_cargador 
	actualizar_ui_municion()

func cambiar_arma(slot: int):
	if slot < 0 or slot > 2 or armas_equipadas[slot] == null: return 
	
	# Salvaguardamos las balas del cargador saliente antes del cambio
	if arma_actual != null:
		cargadores_equipados[slot_actual] = balas_en_cargador
		
	slot_actual = slot
	arma_actual = armas_equipadas[slot]
	balas_en_cargador = cargadores_equipados[slot]
	
	esta_recargando = false 
	temporizador_disparo = 1.0 # Permite abrir fuego inmediato al cambiar de arma
	actualizar_ui_municion()

func equipar_arma_directa(indice_slot: int):
	# Ejecutado directamente desde los botones UI inferiores
	if indice_slot >= 0 and indice_slot < armas_equipadas.size():
		if armas_equipadas[indice_slot] != null:
			cambiar_arma(indice_slot)

func ciclo_arma_rapido():
	# Sistema secundario de ciclo secuencial de seguridad
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
	actualizar_ui_municion() 
	
	# Destreza reduce el tiempo total de recarga linealmente
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
	actualizar_ui_municion()

func recargar_arma_actual():
	# Inyección de señal externa para los dos botones de recarga periféricos
	recargar()

func recoger_municion(cantidad: int, tipo: String):
	if municion_reserva.has(tipo):
		municion_reserva[tipo] += cantidad
		actualizar_ui_municion()

# ==========================================================
# 6. ENLACE Y ACTUALIZACIÓN DINÁMICA DE INTERFAZ GRÁFICA
# ==========================================================
func actualizar_ui_vida():
	if lbl_salud_num and barra_salud:
		lbl_salud_num.text = "%s / %s" % [salud_actual, stat_salud_maxima]
		barra_salud.max_value = stat_salud_maxima
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
	# Sincronización robusta del HUD inferior multi-slot
	for i in range(3):
		if i >= slots_ui.size(): break
		var slot_nodo = slots_ui[i]
		if not is_instance_valid(slot_nodo): continue
		
		# Radar dinámico: No dependemos de rutas de carpetas rígidas dentro de los botones
		var lbl_nombre = slot_nodo.find_child("LblNombre*", true, false)
		var lbl_balas = slot_nodo.find_child("LblBalas*", true, false)
		
		var arma = armas_equipadas[i]
		if arma != null:
			if lbl_nombre: lbl_nombre.text = arma.nombre
			
			# Renderizado inteligente de balas locales vs balas de la reserva global
			var balas_render = balas_en_cargador if i == slot_actual else cargadores_equipados[i]
			var tipo_ammo = arma.tipo_municion
			var reserva = municion_reserva.get(tipo_ammo, 0)
			
			if lbl_balas: 
				if esta_recargando and i == slot_actual:
					lbl_balas.text = "RECARGANDO..."
				else:
					lbl_balas.text = str(balas_render) + " / " + str(reserva)
			
			# Respuesta UX: Iluminamos el slot en uso y atenuamos el resto
			if i == slot_actual:
				slot_nodo.modulate = Color(1.0, 1.0, 1.0, 1.0) # Seleccionado
			else:
				slot_nodo.modulate = Color(0.4, 0.4, 0.4, 0.7) # Guardado
		else:
			# Tratamiento estético si el slot está vacío
			if lbl_nombre: lbl_nombre.text = "---"
			if lbl_balas: lbl_balas.text = "Vacío"
			slot_nodo.modulate = Color(0.2, 0.2, 0.2, 0.4)

# ==========================================================
# 7. EVENTOS RPG, DAÑO Y PROGRESIÓN
# ==========================================================
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
		actualizar_ui_xp()

func subir_nivel():
	var xp_necesaria = 500 + (nivel * 200)
	experiencia_actual -= xp_necesaria 
	nivel += 1
	puntos_mejora += 3
	salud_actual = stat_salud_maxima 
	
	actualizar_ui_vida()
	actualizar_ui_xp() 
	
	# Animación elástica procedural para Alerta de Nivel Superior
	if panel_nivel_up and lbl_puntos_mejora:
		lbl_puntos_mejora.text = "+" + str(puntos_mejora) + " Puntos de Mejora"
		panel_nivel_up.visible = true
		panel_nivel_up.modulate.a = 0.0
		
		if tween_nivel: tween_nivel.kill()
		tween_nivel = create_tween()
		tween_nivel.tween_property(panel_nivel_up, "modulate:a", 1.0, 0.3)
		tween_nivel.tween_interval(3.0)
		tween_nivel.tween_property(panel_nivel_up, "modulate:a", 0.0, 0.5)
		tween_nivel.tween_callback(func(): panel_nivel_up.visible = false)
		
	# Verificación recursiva por si acumuló XP suficiente para subir múltiples niveles de golpe
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

# --- SEÑALES LEGACY ---
func _on_boton_cambiar_arma_pressed() -> void: ciclo_arma_rapido()
func _on_boton_recargar_pressed(): recargar()
