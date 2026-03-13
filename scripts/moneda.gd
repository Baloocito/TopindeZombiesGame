extends Area3D

var valor_oro: int = 20
var velocidad_vuelo: float = 8.0 # Qué tan rápido vuela la moneda hacia ti
var jugador_objetivo: Node3D = null

func _physics_process(delta):
	# 1. Si ya estamos persiguiendo a alguien, volamos hacia él
	if is_instance_valid(jugador_objetivo):
		# Mueve suavemente la moneda hacia el centro del jugador
		global_position = global_position.move_toward(jugador_objetivo.global_position, velocidad_vuelo * delta)
		
		# Si ya estamos casi tocándolo (a medio metro), nos lo guardamos
		if global_position.distance_to(jugador_objetivo.global_position) < 0.5:
			recolectar()
	
	# 2. Si no estamos persiguiendo a nadie, escaneamos buscando un imán
	else:
		var jugadores = get_tree().get_nodes_in_group("jugador")
		for jug in jugadores:
			if is_instance_valid(jug):
				var distancia_al_jugador = global_position.distance_to(jug.global_position)
				
				# Leemos su estadística de recolección (por defecto es 3.0 metros)
				var radio_iman = 3.0
				if "stat_recoleccion" in jug:
					radio_iman = jug.stat_recoleccion
					
				# ¡ATRAPADO POR EL IMÁN!
				if distancia_al_jugador <= radio_iman:
					jugador_objetivo = jug
					break # Dejamos de buscar, ya encontramos a nuestro dueño

func recolectar():
	var mundo = get_tree().current_scene
	if mundo.has_method("sumar_dinero"):
		mundo.sumar_dinero(valor_oro)
		# print("¡+", valor_oro, " Oro recogido magnéticamente!")
	
	queue_free() # Destruimos la moneda
