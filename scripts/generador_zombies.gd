extends Node3D
# ==========================================================
# DIRECTOR DE HORDA (solo corre en el servidor)
# ==========================================================
# Arma la cola de zombies de cada noche con el presupuesto del Manual v3 §8
# (Balance.presupuesto_noche) y los suelta de a uno, sin pasar nunca del tope
# de zombies vivos a la vez (rendimiento en teléfonos).

@export_category("Catálogo de Horda")
@export var zombie_basico: PackedScene
@export var zombie_corredor: PackedScene
@export var zombie_explosivo: PackedScene
@export var zombie_tanque: PackedScene
@export var zombie_boss: PackedScene

var puntos_de_aparicion: Array[Marker3D] = []
var cola_de_aparicion: Array[Dictionary] = []
var tope_simultaneos: int = 70

@onready var timer: Timer = $TimerSpawn

func _ready():
	for hijo in get_children():
		if hijo is Marker3D:
			puntos_de_aparicion.append(hijo)
	if puntos_de_aparicion.is_empty():
		push_warning("Director IA: No hay Marker3D asignados para generar zombies.")
	if timer and not timer.timeout.is_connected(generar_zombie):
		timer.timeout.connect(generar_zombie)

func _escena_de(tipo: String) -> PackedScene:
	match tipo:
		"corredor": return zombie_corredor
		"explosivo": return zombie_explosivo
		"tanque": return zombie_tanque
		"boss": return zombie_boss
	return zombie_basico

# Devuelve cuántos zombies tendrá la noche (mundo.gd lo usa para saber
# cuándo termina).
func preparar_oleada(numero_oleada: int) -> int:
	cola_de_aparicion.clear()
	var jugadores := maxi(1, get_tree().get_nodes_in_group("jugador").size())
	tope_simultaneos = Balance.max_simultaneos(numero_oleada, jugadores)

	var disponibles: Array[Dictionary] = []
	for tipo in ["basico", "corredor", "explosivo", "tanque"]:
		var datos := Balance.zombie(tipo)
		if numero_oleada >= int(datos["desde_noche"]) and _escena_de(tipo):
			disponibles.append({"escena": _escena_de(tipo), "costo": int(datos["costo"]), "tipo": tipo})
	if disponibles.is_empty(): return 0

	var presupuesto := Balance.presupuesto_noche(numero_oleada, jugadores)
	print("--- NOCHE %d --- presupuesto %d, máximo %d a la vez" % [numero_oleada, presupuesto, tope_simultaneos])

	var costo_minimo := 1000000
	for d in disponibles: costo_minimo = mini(costo_minimo, d.costo)
	while presupuesto >= costo_minimo:
		var elegido = disponibles.pick_random()
		if presupuesto >= elegido.costo:
			cola_de_aparicion.append(elegido)
			presupuesto -= elegido.costo
	cola_de_aparicion.shuffle()

	# El jefe va aparte del presupuesto y sale al final de la cola.
	if Balance.es_noche_de_jefe(numero_oleada) and zombie_boss:
		cola_de_aparicion.push_front({"escena": zombie_boss, "costo": int(Balance.zombie("boss")["costo"]), "tipo": "boss"})
		print("¡ALERTA! Noche de jefe.")
	return cola_de_aparicion.size()

func iniciar_generacion():
	if not timer: return
	timer.wait_time = Balance.intervalo_spawn(get_parent().oleada_actual)
	timer.start()

func generar_zombie():
	if cola_de_aparicion.is_empty():
		timer.stop()
		return
	if puntos_de_aparicion.is_empty(): return
	# Respetar el tope de vivos: si está lleno, se espera al próximo tick.
	if get_tree().get_nodes_in_group("enemigos").size() >= tope_simultaneos: return

	var datos_enemigo = cola_de_aparicion.pop_back()
	var escena: PackedScene = datos_enemigo.escena
	if not escena: return
	var nuevo_zombie = escena.instantiate()
	get_parent().add_child(nuevo_zombie, true)
	nuevo_zombie.global_position = puntos_de_aparicion.pick_random().global_position
	if nuevo_zombie.has_method("nacer"):
		nuevo_zombie.nacer(get_parent().oleada_actual, datos_enemigo.costo, datos_enemigo.tipo)
