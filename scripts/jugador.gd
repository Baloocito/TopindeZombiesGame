extends CharacterBody3D

@export var speed = 5.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- SISTEMA DE VIDA E INTERFAZ ---
@export var salud_maxima: int = 5
var salud_actual: int
@onready var texto_vida = $"../InterfazUI/TextoVida"
@onready var texto_municion = $"../InterfazUI/TextoMunicion" # ¡AQUÍ ESTÁ LA VARIABLE FALTANTE!
@onready var boton_recargar = $"../InterfazUI/BotonRecargar" # ¡AQUÍ ESTÁ LA OTRA VARIABLE!

# --- SISTEMA DE ARMAS (LOADOUT 3 SLOTS) ---
@export var bala_escena: PackedScene
@onready var punto_disparo = $PuntoDisparo

const PISTOLA_INICIAL = preload("res://materials/pistola.tres") 

var armas_inventario: Array[ArmaData] = [] # La colección total de armas desbloqueadas
var armas_equipadas: Array[ArmaData] = [null, null, null] # Los 3 slots físicos (0, 1 y 2)
var cargadores_equipados: Array[int] = [0, 0, 0] # Memoria de balas para cada slot

var arma_actual: ArmaData # El arma que tienes en la mano ahora mismo
var slot_actual: int = 0 # Saber si tienes en la mano el slot 0, 1 o 2
var balas_en_cargador: int = 0
var municion_reserva: int = 60 
var esta_recargando: bool = false
var temporizador_disparo: float = 0.0

func _ready():
	salud_actual = salud_maxima
	if texto_vida: texto_vida.text = "Vida: " + str(salud_actual) + "/" + str(salud_maxima)
		
	# 1. Agregamos la pistola a la colección general
	armas_inventario.append(PISTOLA_INICIAL)
	
	# 2. La equipamos físicamente en el primer bolsillo (Slot 0)
	equipar_en_slot(PISTOLA_INICIAL, 0)
	
	# 3. La sacamos para usarla
	cambiar_arma(0)

# Sirve para asignar un arma a un bolsillo (Se usará mucho en la Fase de Preparación)
func equipar_en_slot(nueva_arma: ArmaData, slot: int):
	if slot < 0 or slot > 2: return
	armas_equipadas[slot] = nueva_arma
	cargadores_equipados[slot] = nueva_arma.tamano_cargador # Cargador lleno al equipar por primera vez
	print("Equipada ", nueva_arma.nombre, " en el slot ", slot + 1)

# Sirve para sacar el arma de un bolsillo y ponerla en tus manos
func cambiar_arma(slot: int):
	if slot < 0 or slot > 2: return
	if armas_equipadas[slot] == null: return # Si el bolsillo está vacío, no hacemos nada
	
	# 1. GUARDAR: Guardamos el progreso del cargador actual en su bolsillo antes de soltarla
	if arma_actual != null:
		cargadores_equipados[slot_actual] = balas_en_cargador
		
	# 2. CAMBIAR: Actualizamos los datos al nuevo bolsillo
	slot_actual = slot
	arma_actual = armas_equipadas[slot]
	balas_en_cargador = cargadores_equipados[slot]
	
	# 3. RESETEAR: Cancelamos recargas a medias para evitar bugs
	esta_recargando = false 
	temporizador_disparo = 1.0 # Listo para disparar inmediatamente
	
	print("Cambio rápido al Slot ", slot + 1, ": ", arma_actual.nombre)
	actualizar_ui_municion()

# ¡LA MAGIA PARA CELULARES! Rota entre las armas equipadas con un solo botón
func ciclo_arma_rapido():
	var siguiente_slot = slot_actual
	
	# Buscamos el siguiente slot válido (salta los vacíos)
	for i in range(3):
		siguiente_slot = (siguiente_slot + 1) % 3
		if armas_equipadas[siguiente_slot] != null:
			cambiar_arma(siguiente_slot)
			return
			
			
func _physics_process(delta: float) -> void:
	# 1. Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Movimiento Twin-Stick
	var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# 3. Reloj interno de disparo
	temporizador_disparo += delta

	# 4. Apuntado y Disparo
	var aim_dir := Input.get_vector("apuntar_izq", "apuntar_der", "apuntar_arriba", "apuntar_abajo")
	
	if aim_dir.length() > 0.1:
		var angulo_objetivo = atan2(aim_dir.x, aim_dir.y)		
		rotation.y = angulo_objetivo
		intentar_disparar()
			
	move_and_slide()	

# --- LÓGICA DE INTERFAZ DE ARMAS ---

func actualizar_ui_municion():
	if not texto_municion: return
		
	if not arma_actual:
		texto_municion.visible = false
		if boton_recargar: boton_recargar.visible = false
		return
		
	texto_municion.visible = true
	if boton_recargar: boton_recargar.visible = true
		
	if esta_recargando:
		texto_municion.text = "Recargando..."
	else:
		# ¡AHORA MUESTRA: Cargador / Reserva!
		texto_municion.text = arma_actual.nombre + "\n" + str(balas_en_cargador) + " / " + str(municion_reserva)
		
# --- LÓGICA DE DISPARO ---

func _on_boton_recargar_pressed():
	recargar()

func recargar():
	if not arma_actual or esta_recargando or balas_en_cargador == arma_actual.tamano_cargador:
		return
		
	# ¡NUEVO! Si no tenemos balas en la mochila, no podemos recargar
	if municion_reserva <= 0:
		print("¡SIN MUNICIÓN DE RESERVA!")
		return
		
	esta_recargando = true
	if boton_recargar: boton_recargar.disabled = true 
	actualizar_ui_municion() 
	
	await get_tree().create_timer(arma_actual.tiempo_recarga).timeout
	
	# MATEMÁTICAS DE RECARGA
	var balas_necesarias = arma_actual.tamano_cargador - balas_en_cargador
	if municion_reserva >= balas_necesarias:
		balas_en_cargador += balas_necesarias
		municion_reserva -= balas_necesarias
	else:
		balas_en_cargador += municion_reserva
		municion_reserva = 0
		
	esta_recargando = false
	if boton_recargar: boton_recargar.disabled = false
	actualizar_ui_municion()

func intentar_disparar():
	if not arma_actual or esta_recargando:
		return
		
	var tiempo_entre_balas = 1.0 / arma_actual.cadencia
	
	if temporizador_disparo >= tiempo_entre_balas:
		if balas_en_cargador > 0:
			ejecutar_disparo()
		else:
			recargar() 

func ejecutar_disparo():
	if not bala_escena: return

	temporizador_disparo = 0.0 
	balas_en_cargador -= 1 # Gastamos solo 1 cartucho del cargador
	actualizar_ui_municion() 
	
	# ¡LA MAGIA DE LA ESCOPETA! Repetimos esto por cada perdigón
	for i in range(arma_actual.balas_por_disparo):
		var nueva_bala = bala_escena.instantiate()
		get_parent().add_child(nueva_bala)
		
		# 1. Posición base
		nueva_bala.global_transform = punto_disparo.global_transform
		
		# 2. APLICAR DISPERSIÓN (Cada perdigón calcula su propio desvío al azar)
		if arma_actual.dispersion > 0.0:
			var dispersion_rad = deg_to_rad(arma_actual.dispersion)
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)
		
		# 3. Le pasamos el daño (El GDD dice que cada perdigón hace 12 de daño)
		if "dano" in nueva_bala:
			nueva_bala.dano = arma_actual.dano

# --- LÓGICA DE VIDA Y MUERTE ---

func recibir_dano(cantidad: int):
	salud_actual -= cantidad
	
	if texto_vida:
		texto_vida.text = "Vida: " + str(salud_actual) + "/" + str(salud_maxima)
		
	if salud_actual <= 0:
		morir()

func morir():
	var mundo = get_parent()
	if mundo.has_method("ejecutar_game_over"):
		mundo.ejecutar_game_over()
		
	visible = false
	set_physics_process(false)
	
	# ¡NUEVO! Función para recuperar salud
func curar(porcentaje: float):
	# Si ya estamos al máximo, no hacemos nada
	if salud_actual >= salud_maxima:
		return
		
	# Calculamos cuánto es el 25% de nuestra vida máxima
	var cantidad_curacion = int(salud_maxima * porcentaje)
	
	# Aseguramos que mínimo cure 1 punto de vida, por si las matemáticas dan 0.something
	if cantidad_curacion < 1: 
		cantidad_curacion = 1 
		
	salud_actual += cantidad_curacion
	
	# Nunca podemos curarnos más allá del 100%
	if salud_actual > salud_maxima:
		salud_actual = salud_maxima
		
	# Actualizamos la pantalla
	if texto_vida:
		texto_vida.text = "Vida: " + str(salud_actual) + "/" + str(salud_maxima)
		
	print("¡Curado! (+", cantidad_curacion, " HP) Vida actual: ", salud_actual)
	
	
# ¡NUEVO! Función para cuando recoges una caja del suelo
func recoger_municion(cantidad: int):
	municion_reserva += cantidad
	print("¡Munición recogida! +", cantidad)
	actualizar_ui_municion()


func _on_boton_cambiar_arma_pressed() -> void:
	pass # Replace with function body.
