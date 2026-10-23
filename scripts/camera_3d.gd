extends Camera3D

@export var objetivo: Node3D
@export var velocidad_suavizado: float = 5.0

# 📦 Márgenes asimétricos para la "Caja Invisible"
@export var margen_izquierdo: float = 3.0
@export var margen_derecho: float = 3.0
@export var margen_arriba: float = 3.0  # Movimiento hacia el "norte" (-Z)
@export var margen_abajo: float = 1.0   # Movimiento hacia el "sur" (+Z). ¡MÁS PEQUEÑO!

var offset: Vector3
var punto_enfoque: Vector3
var inicializado: bool = false

func _physics_process(delta):
	# --- FIX (revisión de código) ---
	# Si el peer de red se cerró (el otro jugador se desconectó, o el juego
	# está terminando), multiplayer.get_unique_id() tira un error de motor
	# ("The multiplayer instance isn't currently active") en cada frame.
	# Con este chequeo, simplemente dejamos de intentar buscar al jugador
	# en vez de spamear el log.
	if not multiplayer.has_multiplayer_peer():
		return

	# 1. Si la cámara no tiene un objetivo asignado, lo buscamos dinámicamente
	if not objetivo:
		# --- FIX (revisión de código, Fase 1.C: Reconexión) ---
		# Antes usaba multiplayer.get_unique_id() directo. Eso deja de servir
		# apenas hay reconexión: tu id de red cambia cada vez que te
		# reconectás, pero tu personaje sigue siendo el mismo nodo (con el
		# nombre viejo). EstadoPartida.mi_id_logico es el que el servidor te
		# informa como "tu nodo real" y no cambia aunque tu id de red sí.
		var mi_id = str(EstadoPartida.mi_id_logico) # Nombre real de tu nodo de jugador
		var contenedor = get_node_or_null("../ContenedorJugadores") # Buscamos la carpeta de clones

		# Si la carpeta existe y tu clon ya fue generado...
		if contenedor and EstadoPartida.mi_id_logico != -1 and contenedor.has_node(mi_id):
			objetivo = contenedor.get_node(mi_id) # ¡Enganchamos el objetivo!

			# Calculamos las matemáticas iniciales (solo se hace una vez)
			offset = global_position - objetivo.global_position
			punto_enfoque = objetivo.global_position
			inicializado = true
			current = true # Encendemos esta cámara

		return # Pausamos la cámara hasta que encuentre al jugador

	# 2. Si ya encontramos al jugador, ejecutamos tu excelente lógica de seguimiento
	if inicializado:
		var pos_jugador = objetivo.global_position

		# Eje X (Izquierda / Derecha)
		if pos_jugador.x < punto_enfoque.x - margen_izquierdo:
			punto_enfoque.x = pos_jugador.x + margen_izquierdo
		elif pos_jugador.x > punto_enfoque.x + margen_derecho:
			punto_enfoque.x = pos_jugador.x - margen_derecho

		# Eje Z (Arriba / Abajo)
		if pos_jugador.z < punto_enfoque.z - margen_arriba:
			punto_enfoque.z = pos_jugador.z + margen_arriba
		elif pos_jugador.z > punto_enfoque.z + margen_abajo:
			punto_enfoque.z = pos_jugador.z - margen_abajo

		# Interpolar la cámara hacia el nuevo punto de enfoque
		var posicion_final = punto_enfoque + offset
		global_position = global_position.lerp(posicion_final, velocidad_suavizado * delta)
