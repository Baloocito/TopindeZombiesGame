extends Area3D

var valor_oro: int = 20
var velocidad_vuelo: float = 8.0 # Qué tan rápido vuela la moneda hacia ti
var jugador_objetivo: Node3D = null
var ya_recolectada: bool = false

func _physics_process(delta):
	# 1. Si ya estamos persiguiendo a alguien, volamos hacia él (corre de forma local en cada pantalla)
	if is_instance_valid(jugador_objetivo):
		global_position = global_position.move_toward(jugador_objetivo.global_position, velocidad_vuelo * delta)
		
		# Si ya estamos casi tocándolo (a medio metro)
		if global_position.distance_to(jugador_objetivo.global_position) < 0.5:
			# ¡EL FILTRO DE RED CRÍTICO! 
			# Solo el jugador dueño de ese personaje tiene permiso para notificar la recolección
			if jugador_objetivo.is_multiplayer_authority() and not ya_recolectada:
				ya_recolectada = true # Bloqueo local inmediato para evitar múltiples envíos
				# --- FIX (revisión de código) ---
				# Esto era ".rpc()" (broadcast a TODOS los peers) en vez de
				# ".rpc_id(1)" (solo al servidor). Como el propio comentario de
				# abajo dice, es el cliente avisándole al servidor -- nadie más
				# necesita recibir esto. Al mandarse a todos, cuando el servidor
				# ya había hecho queue_free() de la moneda, a los DEMÁS clientes
				# les llegaba esta RPC apuntando a un nodo que en su pantalla ya
				# no existía (el despawn del MultiplayerSpawner puede llegarles
				# antes por ser un mensaje distinto), y tiraban
				# "Node not found: MonedaN".
				solicitar_recolectar_servidor.rpc_id(1)
	
	# 2. Si no estamos persiguiendo a nadie, escaneamos buscando un imán
	else:
		var jugadores = get_tree().get_nodes_in_group("jugador")
		for jug in jugadores:
			if is_instance_valid(jug):
				var distancia_al_jugador = global_position.distance_to(jug.global_position)
				
				var radio_iman = 3.0
				if "stat_recoleccion" in jug:
					radio_iman = jug.stat_recoleccion
					
				# ¡ATRAPADO POR EL IMÁN!
				if distancia_al_jugador <= radio_iman:
					jugador_objetivo = jug
					break 

# El cliente le grita al servidor que quiere registrar el oro
# --- FIX (revisión de código) ---
# Faltaba "call_local". Cuando el jugador dueño era el HOST (id 1) mismo, su
# ".rpc_id(1)" apuntaba a sí mismo -- y Godot NO permite eso sin call_local
# ("RPC on yourself is not allowed by selected mode"), así que la llamada se
# bloqueaba entera y el oro nunca se sumaba para el Host. Con call_local,
# cuando el que llama Y el destino son el mismo peer, Godot lo ejecuta
# directo en vez de rechazarlo. Para un cliente normal no cambia nada (sigue
# yendo solo al servidor).
@rpc("any_peer", "call_local", "reliable")
func solicitar_recolectar_servidor():
	# Seguridad: Solo el Servidor procesa esta matemática
	if not multiplayer.is_server(): return
	
	var mundo = get_tree().current_scene
	if mundo.has_method("sincronizar_dinero_en_red"):
		# El servidor le ordena a TODOS los jugadores que sumen el oro en sus pantallas
		mundo.sincronizar_dinero_en_red.rpc(valor_oro)
	
	# Al destruirse el nodo en el Servidor, tu MultiplayerSpawner se encarga de 
	# borrar la moneda automáticamente de todas las pantallas de los clientes.
	queue_free()
