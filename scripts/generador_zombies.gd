extends Node3D
# ==========================================================
# 1. PREFABS DE ENEMIGOS (GDD)
# ==========================================================
@export_category("Catálogo de Horda")
@export var zombie_basico: PackedScene
@export var zombie_corredor: PackedScene
@export var zombie_explosivo: PackedScene 
@export var zombie_tanque: PackedScene 
@export var zombie_boss: PackedScene

# ==========================================================
# 2. ESTADO DEL DIRECTOR
# ==========================================================
var puntos_de_aparicion: Array[Marker3D] = []
var cola_de_aparicion: Array[Dictionary] = [] 

@onready var timer: Timer = $TimerSpawn

# ==========================================================
# 3. INICIALIZACIÓN
# ==========================================================
func _ready():
	# Recolectar dinámicamente todos los Marker3D hijos como puntos de spawn
	for hijo in get_children():
		if hijo is Marker3D:
			puntos_de_aparicion.append(hijo)
			
	if puntos_de_aparicion.is_empty():
		push_warning("Director IA: No hay Marker3D asignados para generar zombies.")

	# Conexión blindada de la señal (Evita errores del editor)
	if timer and not timer.timeout.is_connected(generar_zombie):
		timer.timeout.connect(generar_zombie)

# ==========================================================
# 4. PREPARACIÓN Y CÁLCULO DE LA OLEADA
# ==========================================================
func preparar_oleada(numero_oleada: int) -> int:
	cola_de_aparicion.clear()
	var enemigos_disponibles: Array[Dictionary] = []
	
	# --- A. DESBLOQUEO DE CATÁLOGO ---
	if zombie_basico: enemigos_disponibles.append({"escena": zombie_basico, "costo": 10, "tipo": "basico"})
	if numero_oleada >= 3 and zombie_corredor: enemigos_disponibles.append({"escena": zombie_corredor, "costo": 25, "tipo": "corredor"})
	if numero_oleada >= 4 and zombie_explosivo: enemigos_disponibles.append({"escena": zombie_explosivo, "costo": 60, "tipo": "explosivo"})
	if numero_oleada >= 5 and zombie_tanque: enemigos_disponibles.append({"escena": zombie_tanque, "costo": 80, "tipo": "tanque"})
	
	if enemigos_disponibles.is_empty(): return 0
	
	# --- B. PRESUPUESTO DEL DIRECTOR ---
	# Escala el presupuesto un 30% por oleada
	var presupuesto = int(100 * pow(1.3, numero_oleada)) 
	
	# --- C. REGLA DEL JEFE (MOSCA TYRANT) ---
	var jefe_en_espera = null
	if numero_oleada % 5 == 0 and zombie_boss:
		jefe_en_espera = {"escena": zombie_boss, "costo": 1000, "tipo": "boss"}
		presupuesto -= 1000 # Reserva el presupuesto del jefe
		print("¡ALERTA! EL DIRECTOR HA DESPLEGADO A LA MOSCA TYRANT.")
		
	print("--- NOCHE ", numero_oleada, " --- Presupuesto de infantería: ", presupuesto)
	
	# --- D. COMPRA DE INFANTERÍA ---
	var costo_minimo = 10 
	while presupuesto >= costo_minimo:
		var enemigo_elegido = enemigos_disponibles.pick_random()
		if presupuesto >= enemigo_elegido.costo:
			cola_de_aparicion.append(enemigo_elegido)
			presupuesto -= enemigo_elegido.costo
			
	# Mezclamos la cola para que la horda sea impredecible y variada
	cola_de_aparicion.shuffle()
	
	# Si hay un jefe, lo metemos al principio de la cola (se saca al final con pop_back)
	# para que el jefe aparezca en el clímax de la ronda.
	if jefe_en_espera != null:
		cola_de_aparicion.push_front(jefe_en_espera)
			
	return cola_de_aparicion.size()

# ==========================================================
# 5. CONTROL DE ENGAGEMENT (APARICIÓN)
# ==========================================================
func iniciar_generacion():
	if not timer: return
	
	# ¡NUEVO! Pacing dinámico: A mayor oleada, más rápido spawnean (límite de 0.2s)
	var oleada = get_parent().oleada_actual
	var velocidad_spawn = max(0.2, 2.0 - (oleada * 0.1))
	
	timer.wait_time = velocidad_spawn
	timer.start()
	print("Director IA: Iniciando asalto. Ritmo de spawn: ", velocidad_spawn, "s")

func generar_zombie():
	if cola_de_aparicion.is_empty():
		timer.stop()
		return
		
	if puntos_de_aparicion.is_empty(): return
		
	# Extraemos el siguiente zombie de la lista
	var datos_enemigo = cola_de_aparicion.pop_back()
	var escena_a_crear = datos_enemigo.escena
	
	if not is_instance_valid(escena_a_crear): return 
	
	# Posicionamiento e Instanciación
	var punto_elegido = puntos_de_aparicion.pick_random()
	var nuevo_zombie = escena_a_crear.instantiate()
	
	get_parent().add_child(nuevo_zombie)
	nuevo_zombie.global_position = punto_elegido.global_position
	
	# Inicialización de Stats (El Cerebro del Zombie)
	var oleada_actual = get_parent().oleada_actual
	if nuevo_zombie.has_method("nacer"):
		nuevo_zombie.nacer(oleada_actual, datos_enemigo.costo, datos_enemigo.tipo)
