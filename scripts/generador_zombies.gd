extends Node3D

# --- PREFABS DE ENEMIGOS ---
@export var zombie_basico: PackedScene
@export var zombie_corredor: PackedScene
@export var zombie_tanque: PackedScene # ¡NUEVO!
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
	
	# El básico siempre está disponible
	enemigos_disponibles.append({"escena": zombie_basico, "costo": 10, "tipo": "basico"})
	
	if numero_oleada >= 3: # En la noche 3 llegan los corredores
		enemigos_disponibles.append({"escena": zombie_corredor, "costo": 25, "tipo": "corredor"})
		
	if numero_oleada >= 5: # ¡NUEVO! En la noche 5 llegan los Tanques
		enemigos_disponibles.append({"escena": zombie_tanque, "costo": 50, "tipo": "tanque"})
		
	if numero_oleada >= 7: # En la noche 7 los Bosses se vuelven enemigos comunes
		enemigos_disponibles.append({"escena": zombie_boss, "costo": 100, "tipo": "boss"}) 
	
	var presupuesto = int(100 * pow(1.2, numero_oleada))
	print("--- NOCHE ", numero_oleada, " --- Presupuesto: ", presupuesto)
	
	var costo_minimo = 10 
	while presupuesto >= costo_minimo:
		var enemigo_elegido = enemigos_disponibles.pick_random()
		
		if presupuesto >= enemigo_elegido.costo:
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
	
	# ¡LA MAGIA AQUÍ! Le pasamos el 'tipo' para que el zombie sepa cómo configurarse
	nuevo_zombie.nacer(oleada_actual, datos_enemigo.costo, datos_enemigo.tipo)
