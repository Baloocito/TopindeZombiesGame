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

# --- REFERENCIAS UI GENERALES ---
# --- REFERENCIAS UI GENERALES ---
@onready var lbl_salud_num = $"../../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/FilaSalud/LblSaludNum"
@onready var barra_salud = $"../../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/BarraSalud"
@onready var lbl_nivel = $"../../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/LblNivel"
@onready var barra_xp = $"../../InterfazUI/HudSuperiorIzquierdo/HudEstadisticas/BarraXP"
@onready var panel_nivel_up = $"../../InterfazUI/ContenedorAlertas/PanelNivelUp"
@onready var lbl_puntos_mejora = $"../../InterfazUI/ContenedorAlertas/PanelNivelUp/LblPuntos"

# --- REFERENCIAS UI INVENTARIO DE COMBATE ---
@onready var slots_ui: Array = [
	$"../../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma1",
	$"../../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma2",
	$"../../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma3"
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

var can_fire_fase: bool = false 

var municion_reserva: Dictionary = {
	"Ligera": 90,
	"Pesada": 12,
	"Energia": 0
}

# ==========================================================
# 3. INICIALIZACIÓN (¡BLINDADA PARA MULTIJUGADOR!)
# ==========================================================
func _enter_tree():
	# ¡Aquí es donde Godot nos pide que definamos la autoridad!
	set_multiplayer_authority(name.to_int())
	
func _ready():	
	# Si tú eres el dueño absoluto de este clon específico:
	if is_multiplayer_authority():
		salud_actual = stat_salud_maxima
		actualizar_ui_vida()
		actualizar_ui_xp()
			
		armas_inventario.append(PISTOLA_INICIAL)
		equipar_en_slot(PISTOLA_INICIAL, 0)
		cambiar_arma(0)
		
		var escopeta = load("res://materials/escopeta.tres")
		var smg = load("res://materials/smg.tres")
		if escopeta: armas_inventario.append(escopeta)
		if smg: armas_inventario.append(smg)
		

func set_can_fire(valor: bool) -> void:
	can_fire_fase = valor

# ==========================================================
# 4. LOOP DE FÍSICAS Y CONTROLES (¡SOLO PARA EL DUEÑO!)
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# ¡AQUÍ ESTÁ LA MAGIA! Ignoramos los joysticks si no somos el dueño
	if is_multiplayer_authority():
		var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
		var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
		
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
			rotation.y = lerp_angle(rotation.y, angulo_objetivo, 15.0 * delta)
			
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
	
	if arma_actual != null:
		cargadores_equipados[slot_actual] = balas_en_cargador
		
	slot_actual = slot
	arma_actual = armas_equipadas[slot]
	balas_en_cargador = cargadores_equipados[slot]
	
	esta_recargando = false 
	temporizador_disparo = 1.0
	actualizar_ui_municion()

func equipar_arma_directa(indice_slot: int):
	if indice_slot >= 0 and indice_slot < armas_equipadas.size():
		if armas_equipadas[indice_slot] != null:
			cambiar_arma(indice_slot)

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
			# 1. Lógica LOCAL: Gastamos la bala de tu cargador (Solo ocurre en tu pantalla)
			temporizador_disparo = 0.0
			balas_en_cargador -= 1
			actualizar_ui_municion()
			
			# 2. Lógica de RED: Le gritamos a todos que generen la bala, pasándole los datos exactos
			ejecutar_disparo_en_red.rpc(arma_actual.dano, arma_actual.dispersion, arma_actual.balas_por_disparo)
		else:
			recargar() 

# ¡MAGIA RPC! Recibimos los datos del arma directamente en los parámetros
@rpc("call_local", "any_peer", "reliable")
func ejecutar_disparo_en_red(dano_arma: int, dispersion_arma: float, cantidad_balas: int):
	if not bala_escena: return

	# Calculamos la dispersión usando el dato que llegó por la red
	var dispersion_rad = deg_to_rad(dispersion_arma) if dispersion_arma > 0.0 else 0.0
	
	for i in range(cantidad_balas):
		var nueva_bala = bala_escena.instantiate()
		get_tree().current_scene.add_child(nueva_bala)
		nueva_bala.global_transform = punto_disparo.global_transform
		
		if dispersion_rad > 0.0:
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)
		
		# Le inyectamos el daño que llegó por la red
		if "dano" in nueva_bala:
			nueva_bala.dano = dano_arma

func recargar():
	if not arma_actual or esta_recargando or balas_en_cargador == arma_actual.tamano_cargador: return
		
	var tipo = arma_actual.tipo_municion
	if municion_reserva[tipo] <= 0: return
		
	esta_recargando = true
	actualizar_ui_municion() 
	
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
	recargar()

func recoger_municion(cantidad: int, tipo: String):
	if municion_reserva.has(tipo):
		municion_reserva[tipo] += cantidad
		actualizar_ui_municion()

# ==========================================================
# 6. ENLACE DE UI (¡BLOQUEADO SOLO PARA EL JUGADOR LOCAL!)
# ==========================================================
func actualizar_ui_vida():
	if not is_multiplayer_authority(): return # El clon no debe tocar mi pantalla
	
	if lbl_salud_num and barra_salud:
		lbl_salud_num.text = "%s / %s" % [salud_actual, stat_salud_maxima]
		barra_salud.max_value = stat_salud_maxima
		var tween = create_tween()
		tween.tween_property(barra_salud, "value", float(salud_actual), 0.2).set_trans(Tween.TRANS_SINE)

func actualizar_ui_xp():
	if not is_multiplayer_authority(): return
	
	if lbl_nivel and barra_xp:
		var xp_necesaria = 500 + (nivel * 200)
		lbl_nivel.text = "NIVEL %s" % nivel
		barra_xp.max_value = xp_necesaria
		var tween = create_tween()
		tween.tween_property(barra_xp, "value", float(experiencia_actual), 0.2).set_trans(Tween.TRANS_SINE)

func actualizar_ui_municion():
	if not is_multiplayer_authority(): return
	
	for i in range(3):
		if i >= slots_ui.size(): break
		var slot_nodo = slots_ui[i]
		if not is_instance_valid(slot_nodo): continue
		
		var lbl_nombre = slot_nodo.find_child("LblNombre*", true, false)
		var lbl_balas = slot_nodo.find_child("LblBalas*", true, false)
		
		var arma = armas_equipadas[i]
		if arma != null:
			if lbl_nombre: lbl_nombre.text = arma.nombre
			
			var balas_render = balas_en_cargador if i == slot_actual else cargadores_equipados[i]
			var tipo_ammo = arma.tipo_municion
			var reserva = municion_reserva.get(tipo_ammo, 0)
			
			if lbl_balas: 
				if esta_recargando and i == slot_actual:
					lbl_balas.text = "RECARGANDO..."
				else:
					lbl_balas.text = str(balas_render) + " / " + str(reserva)
			
			if i == slot_actual:
				slot_nodo.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				slot_nodo.modulate = Color(0.4, 0.4, 0.4, 0.7)
		else:
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
	# Si este jugador muere y es su autoridad, dispara el Game Over para su cliente
	if is_multiplayer_authority():
		var mundo = get_parent().get_parent() # Ajustado para subir desde ContenedorJugadores
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
	
	if not is_multiplayer_authority(): return
	
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
