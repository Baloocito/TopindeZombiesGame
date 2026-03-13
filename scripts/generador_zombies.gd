extends Node3D

# --- PREFABS DE ENEMIGOS ---
@export var zombie_basico: PackedScene
@export var zombie_corredor: PackedScene
@export var zombie_explosivo: PackedScene # ¡AGREGADO!
@export var zombie_tanque: PackedScene 
@export var zombie_boss: PackedScene

var puntos_de_aparicion: Array = []
var cola_de_aparicion: Array = [] 
@onready var timer = $TimerSpawn

func _ready():
	for hijo in get_children():
		if hijo is Marker3D:
			puntos_de_aparicion.append(hijo)

func preparar_oleada(numero_oleada: int) -> int:
	cola_de_aparicion.clear()
	var enemigos_disponibles: Array = []
	
	# --- 1. DESBLOQUEO DE ENEMIGOS Y SUS COSTOS (GDD) ---
	enemigos_disponibles.append({"escena": zombie_basico, "costo": 10, "tipo": "basico"})
	
	if numero_oleada >= 3:
		enemigos_disponibles.append({"escena": zombie_corredor, "costo": 25, "tipo": "corredor"})
		
	if numero_oleada >= 4: # Suponiendo que el explosivo entra en la 4
		enemigos_disponibles.append({"escena": zombie_explosivo, "costo": 60, "tipo": "explosivo"})
		
	if numero_oleada >= 5:
		enemigos_disponibles.append({"escena": zombie_tanque, "costo": 80, "tipo": "tanque"})
	
	# --- 2. PRESUPUESTO DEL DIRECTOR ---
	# Escalo el presupuesto un 30% por oleada para poder pagar el costo del Boss eventualmente
	var presupuesto = int(100 * pow(1.3, numero_oleada)) 
	
	# --- 3. REGLA DEL BOSS (MOSCA TYRANT) ---
	# Aparece exactamente cada 5 oleadas (5, 10, 15...)
	if numero_oleada % 5 == 0 and zombie_boss:
		cola_de_aparicion.append({"escena": zombie_boss, "costo": 1000, "tipo": "boss"})
		presupuesto -= 1000 # El Boss se come casi todo el presupuesto de esa noche
		print("¡ALERTA! MOSCA TYRANT SE ACERCA.")
		
	print("--- NOCHE ", numero_oleada, " --- Presupuesto de infantería: ", presupuesto)
	
	# --- 4. COMPRAR LA HORDA ---
	var costo_minimo = 10 
	while presupuesto >= costo_minimo:
		var enemigo_elegido = enemigos_disponibles.pick_random()
		
		# Validamos que la escena no sea nula antes de intentar comprarlo
		if enemigo_elegido.escena != null and presupuesto >= enemigo_elegido.costo:
			cola_de_aparicion.append(enemigo_elegido)
			presupuesto -= enemigo_elegido.costo
			
	return cola_de_aparicion.size()

func iniciar_generacion():
	timer.start()

func generar_zombie():
	if cola_de_aparicion.size() == 0:
		timer.stop()
		return
		
	if puntos_de_aparicion.size() == 0: return
		
	var datos_enemigo = cola_de_aparicion.pop_back()
	var escena_a_crear = datos_enemigo.escena
	
	if not escena_a_crear: return 
	
	var punto_elegido = puntos_de_aparicion.pick_random()
	var nuevo_zombie = escena_a_crear.instantiate()
	get_parent().add_child(nuevo_zombie)
	nuevo_zombie.global_position = punto_elegido.global_position
	
	var oleada_actual = get_parent().oleada_actual
	
	# ¡LA MAGIA AQUÍ!
	nuevo_zombie.nacer(oleada_actual, datos_enemigo.costo, datos_enemigo.tipo)
