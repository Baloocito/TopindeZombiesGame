extends Camera3D
# ==========================================================
# CÁMARA 3/4 FIJA QUE SIGUE AL JUGADOR (Manual v3: sin rotación)
# ==========================================================
# Mira con un ángulo fijo hacia el norte y mantiene al jugador centrado, con
# una pequeña zona muerta para que no tiemble con cada paso. La distancia
# tiene tres niveles (Opciones > Cámara): en el celular arranca más cerca.

const INCLINACION := 50.0   # grados hacia abajo
const CAMPO_VISION := 50.0
const DISTANCIAS := {"lejos": 18.0, "normal": 14.0, "cerca": 10.5}

@export var objetivo: Node3D
@export var velocidad_suavizado: float = 5.0
@export var zona_muerta := Vector2(1.2, 0.9)   # metros en X y en Z

# Las dejamos para no romper la escena (ya no se usan).
@export var margen_izquierdo: float = 3.0
@export var margen_derecho: float = 3.0
@export var margen_arriba: float = 3.0
@export var margen_abajo: float = 1.0

var punto_enfoque: Vector3
var inicializado: bool = false
var distancia_actual := 14.0

func _ready():
	fov = CAMPO_VISION
	rotation_degrees = Vector3(-INCLINACION, 0, 0)
	distancia_actual = distancia_objetivo()

static func distancia_objetivo() -> float:
	return DISTANCIAS.get(PS1.zoom_camara, 14.0)

func _direccion_atras() -> Vector3:
	return global_basis.z.normalized()  # opuesto a hacia dónde mira

func _physics_process(delta):
	if not multiplayer.has_multiplayer_peer():
		return

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
			punto_enfoque = objetivo.global_position
			inicializado = true
			current = true
			global_position = punto_enfoque + Vector3(0, 0.9, 0) + _direccion_atras() * distancia_actual
		return

	if inicializado:
		var p := objetivo.global_position
		if p.x < punto_enfoque.x - zona_muerta.x: punto_enfoque.x = p.x + zona_muerta.x
		elif p.x > punto_enfoque.x + zona_muerta.x: punto_enfoque.x = p.x - zona_muerta.x
		if p.z < punto_enfoque.z - zona_muerta.y: punto_enfoque.z = p.z + zona_muerta.y
		elif p.z > punto_enfoque.z + zona_muerta.y: punto_enfoque.z = p.z - zona_muerta.y
		punto_enfoque.y = p.y
		# El zoom cambia suave si se modifica en Opciones.
		distancia_actual = lerpf(distancia_actual, distancia_objetivo(), minf(1.0, delta * 4.0))
		var meta := punto_enfoque + Vector3(0, 0.9, 0) + _direccion_atras() * distancia_actual
		global_position = global_position.lerp(meta, minf(1.0, velocidad_suavizado * delta))
