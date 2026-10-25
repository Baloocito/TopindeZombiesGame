extends Node3D
# ==========================================================
# DIRECTOR DE HORDA (solo corre en el servidor)
# ==========================================================
# Cada noche sale de data/campana.json (Balance.noche_campana): presupuesto,
# mezcla de enemigos, pulsos y jefe. La noche se divide en pulsos: se suelta
# uno, y el siguiente llega cuando el anterior se fue apagando (o tras un
# respiro). Nunca hay más zombies vivos que el tope (rendimiento en teléfonos).

@export_category("Catálogo de Horda")
@export var zombie_basico: PackedScene
@export var zombie_corredor: PackedScene
@export var zombie_explosivo: PackedScene
@export var zombie_tanque: PackedScene
@export var zombie_boss: PackedScene

const TIPOS_HORDA := ["basico", "corredor", "explosivo", "tanque"]

var puntos_de_aparicion: Array[Marker3D] = []
var pulsos: Array = []                     # Array de Array[Dictionary]
var cola_de_aparicion: Array[Dictionary] = []  # el pulso que está saliendo ahora
var tope_simultaneos: int = 70
var _espera_respiro: float = 0.0
var _pulso_numero: int = 0

@onready var timer: Timer = $TimerSpawn

func _ready():
	for hijo in get_children():
		if hijo is Marker3D:
			puntos_de_aparicion.append(hijo)
	if puntos_de_aparicion.is_empty():
		push_warning("Director IA: No hay Marker3D asignados para generar zombies.")
	if timer and not timer.timeout.is_connected(generar_zombie):
		timer.timeout.connect(generar_zombie)

func escena_zombie() -> PackedScene:
	return zombie_basico

func _jugadores() -> int:
	return maxi(1, get_tree().get_nodes_in_group("jugador").size())

# Devuelve cuántos enemigos tendrá la noche (mundo.gd lo usa para saber
# cuándo termina). Los que invocan los jefes se suman después.
func preparar_oleada(numero_oleada: int) -> int:
	pulsos.clear()
	cola_de_aparicion.clear()
	_pulso_numero = 0
	_espera_respiro = 0.0
	var jugadores := _jugadores()
	var noche := Balance.noche_campana(numero_oleada)
	tope_simultaneos = Balance.max_simultaneos(numero_oleada, jugadores)

	# Pesos de la mezcla de esta noche.
	var mezcla: Dictionary = noche.get("mezcla", {"basico": 1})
	var opciones: Array = []
	var peso_total := 0.0
	for tipo in TIPOS_HORDA:
		var peso := float(mezcla.get(tipo, 0))
		if peso > 0.0:
			opciones.append({"tipo": tipo, "peso": peso, "costo": int(Balance.zombie(tipo)["costo"])})
			peso_total += peso
	var presupuesto := Balance.presupuesto_noche(numero_oleada, jugadores)
	var n_pulsos := maxi(1, int(noche.get("pulsos", 1)))
	print("--- NOCHE %d (%s) --- presupuesto %d, %d pulsos, máximo %d a la vez" % [numero_oleada, noche.get("nombre", ""), presupuesto, n_pulsos, tope_simultaneos])

	# Cada pulso pesa un poco más que el anterior: la noche va en subida.
	var pesos_pulso: Array = []
	var suma_pulsos := 0.0
	for i in n_pulsos:
		var w := 1.0 + 0.25 * i
		pesos_pulso.append(w)
		suma_pulsos += w
	var total := 0
	for i in n_pulsos:
		var resto := int(presupuesto * pesos_pulso[i] / suma_pulsos)
		var pulso: Array[Dictionary] = []
		var intentos := 0
		while resto > 0 and intentos < 2000 and not opciones.is_empty():
			intentos += 1
			var elegido = _elegir_ponderado(opciones, peso_total)
			if elegido.costo <= resto:
				pulso.append({"tipo": elegido.tipo, "costo": elegido.costo})
				resto -= elegido.costo
			elif resto < 10:
				break
		pulso.shuffle()
		pulsos.append(pulso)
		total += pulso.size()

	# Jefe: entra como un pulso propio antes del pulso indicado.
	if noche.has("jefe"):
		var jefe_pulso: Array[Dictionary] = []
		if noche["jefe"] == "enjambre":
			jefe_pulso.append({"tipo": "guardian", "costo": 0})
			for i in 3: jefe_pulso.append({"tipo": "acechador", "costo": 0})
		else:
			jefe_pulso.append({"tipo": str(noche["jefe"]), "costo": 0})
		var en := clampi(int(noche.get("jefe_en_pulso", 0)), 0, pulsos.size())
		pulsos.insert(en, jefe_pulso)
		total += jefe_pulso.size()
		print("¡ALERTA! Noche de jefe: %s (antes del pulso %d)." % [noche["jefe"], en])
	return total

func _elegir_ponderado(opciones: Array, peso_total: float) -> Dictionary:
	var r := randf() * peso_total
	for o in opciones:
		r -= o.peso
		if r <= 0.0: return o
	return opciones[opciones.size() - 1]

func iniciar_generacion():
	if not timer: return
	timer.wait_time = Balance.intervalo_spawn(get_parent().oleada_actual)
	_siguiente_pulso()
	timer.start()

func quedan_por_salir() -> bool:
	return not cola_de_aparicion.is_empty() or not pulsos.is_empty()

func _siguiente_pulso():
	if pulsos.is_empty(): return
	cola_de_aparicion.clear()
	var p: Array = pulsos.pop_front()
	for e in p: cola_de_aparicion.append(e)
	cola_de_aparicion.reverse()  # se sacan con pop_back
	_pulso_numero += 1
	_espera_respiro = 0.0
	var mundo = get_parent()
	var es_jefe := not p.is_empty() and Balance.es_jefe(str(p[0].tipo))
	if es_jefe:
		if mundo.has_method("anunciar_jefe"): mundo.anunciar_jefe(str(p[0].tipo))
	elif _pulso_numero > 1 and mundo.has_method("mostrar_aviso"):
		mundo.mostrar_aviso.rpc("¡Se acerca otra horda!")

func generar_zombie():
	if cola_de_aparicion.is_empty():
		if pulsos.is_empty():
			timer.stop()
			return
		# Respiro: el próximo pulso llega cuando el actual se fue apagando,
		# o cuando se acaba el respiro, lo que pase primero.
		_espera_respiro += timer.wait_time
		var vivos := get_tree().get_nodes_in_group("enemigos").size()
		var respiro := float(Balance.campana.get("respiro_entre_pulsos", 7.0))
		if vivos <= maxi(2, int(tope_simultaneos * 0.3)) or _espera_respiro >= respiro:
			_siguiente_pulso()
		return
	if puntos_de_aparicion.is_empty(): return
	# Respetar el tope de vivos: si está lleno, se espera al próximo tick.
	if get_tree().get_nodes_in_group("enemigos").size() >= tope_simultaneos: return

	var datos_enemigo: Dictionary = cola_de_aparicion.pop_back()
	crear_enemigo(str(datos_enemigo.tipo), puntos_de_aparicion.pick_random().global_position, int(datos_enemigo.costo))

# Crea un enemigo de cualquier tipo (también lo usan los jefes para invocar).
# El tipo se fija ANTES de entrar al árbol para que viaje en el spawn y cada
# pantalla lo pinte bien.
func crear_enemigo(tipo: String, posicion: Vector3, costo: int = 0) -> Node:
	var escena := escena_zombie()
	if not escena: return null
	var nuevo = escena.instantiate()
	nuevo.tipo_zombie = tipo
	get_parent().add_child(nuevo, true)
	nuevo.global_position = posicion
	if nuevo.has_method("nacer"):
		nuevo.nacer(get_parent().oleada_actual, costo, tipo)
	return nuevo

func punto_aleatorio() -> Vector3:
	if puntos_de_aparicion.is_empty(): return Vector3.ZERO
	return puntos_de_aparicion.pick_random().global_position
