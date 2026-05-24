extends Area3D

# ==========================================================
# 1. ATRIBUTOS Y CONFIGURACIÓN
# ==========================================================
@export_category("Físicas de la Bala")
@export var velocidad: float = 30.0 # Ajustado a la velocidad predictiva de la torreta
@export var tiempo_vida: float = 2.0 

# Variable inyectada dinámicamente por el Jugador o la Torreta al instanciar
var dano: int = 10 
var tiempo_transcurrido: float = 0.0

# ==========================================================
# 2. INICIALIZACIÓN Y MOVIMIENTO CORREGIDO hola
# ==========================================================
func _ready():
	# Conexión blindada de señales de colisión física
	if not body_entered.is_connected(_al_chocar):
		body_entered.connect(_al_chocar)

func _physics_process(delta):
	# --- CORRECCIÓN DE DIRECCIÓN GRÁFICA ---
	# Usamos "-transform.basis.z" para que la bala viaje hacia ADELANTE (+Z en Blender es -Z en Godot)
	global_position += transform.basis.z * velocidad * delta
	
	# Colector de basura seguro (Evita usar await timers que saturan la RAM en hordas grandes)
	tiempo_transcurrido += delta
	if tiempo_transcurrido >= tiempo_vida:
		queue_free()

# ==========================================================
# 3. FILTRADO DE COLISIONES TÁCTICO (Capas lógicas)
# ==========================================================
func _al_chocar(cuerpo: Node3D):
	if not is_instance_valid(cuerpo): return

	# --- ESCUDO DE FUEGO AMIGO ---
	# La bala ignora por completo al jugador, torretas y vallas aliadas
	if cuerpo.is_in_group("jugador") or cuerpo.is_in_group("barricadas"):
		return
		
	# --- IMPACTO DE GUERRA ---
	if cuerpo.is_in_group("enemigos"):
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano)
			
	# La bala se destruye al impactar un enemigo, un muro del mapa o el suelo
	queue_free()
