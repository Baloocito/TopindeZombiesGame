extends PickupBase
# Moneda de oro. Vuela hacia el jugador más cercano dentro de su radio de
# imán; el oro es del equipo, así que lo suma el servidor.

var valor_oro: int = 20
var velocidad_vuelo: float = 8.0
var jugador_objetivo: Node3D = null

func _physics_process(delta):
	if ya_recolectado: return
	if is_instance_valid(jugador_objetivo):
		global_position = global_position.move_toward(jugador_objetivo.global_position, velocidad_vuelo * delta)
		if global_position.distance_to(jugador_objetivo.global_position) < 0.5 and puede_recoger(jugador_objetivo):
			recolectar(jugador_objetivo)
		return
	for jug in get_tree().get_nodes_in_group("jugador"):
		if not is_instance_valid(jug): continue
		var radio_iman = jug.stat_recoleccion if "stat_recoleccion" in jug else 3.0
		if global_position.distance_to(jug.global_position) <= radio_iman:
			jugador_objetivo = jug
			break

func al_recoger_servidor(_id_remitente: int) -> void:
	# Antes el servidor hacía sincronizar_dinero_en_red.rpc(), que se envía a
	# los CLIENTES pero no corre en el propio servidor: el oro de las monedas
	# nunca se sumaba. Ahora el servidor lo suma directo y él lo reparte.
	var m = mundo()
	if m and m.has_method("sumar_dinero"):
		m.sumar_dinero(valor_oro)
