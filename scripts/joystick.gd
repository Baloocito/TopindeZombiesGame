extends TextureRect

# Variables que configuraremos en el Inspector de Godot
@export var accion_izq: String = "mover_izq"
@export var accion_der: String = "mover_der"
@export var accion_arriba: String = "mover_arriba"
@export var accion_abajo: String = "mover_abajo"

@onready var palanca = $Palanca

var vector_input := Vector2.ZERO
var dedo_indice: int = -1
var tween_actual: Tween # Para evitar que las animaciones peleen entre sí

func _ready():
	# 1. Aseguramos que los anclajes de la palanca no arruinen las matemáticas
	palanca.anchors_preset = Control.PRESET_TOP_LEFT
	
	# 2. Esperamos a que Godot dibuje la UI completamente y luego lo centramos
	call_deferred("resetear_joystick")

func _gui_input(event):
	# Determinamos si es un dedo (index) o el ratón (0)
	var toque_id = -1
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		toque_id = event.index
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		toque_id = 0 
		
	# Detectar cuando APRETAMOS o SOLTAMOS
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed() and dedo_indice == -1:
			dedo_indice = toque_id
			# Detenemos cualquier animación de regreso si lo volvemos a tocar
			if tween_actual: tween_actual.kill() 
			actualizar_joystick(event.position)
			
		elif not event.is_pressed() and toque_id == dedo_indice:
			resetear_joystick()
			
	# Detectar cuando ARRASTRAMOS
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if toque_id == dedo_indice and dedo_indice != -1:
			actualizar_joystick(event.position)
			
func actualizar_joystick(pos_toque: Vector2):
	# ¡MAGIA EN TIEMPO REAL! Siempre usamos el tamaño actual
	var centro = size / 2.0
	var radio = size.x / 2.0
	
	var direccion = pos_toque - centro
	
	# Limitar el radio visual para que la bolita no se salga del círculo
	if direccion.length() > radio:
		direccion = direccion.normalized() * radio
		
	# Movemos la palanca visualmente
	palanca.position = centro + direccion - (palanca.size / 2.0)
	
	# Calculamos el vector exacto (-1.0 a 1.0)
	if radio > 0:
		vector_input = direccion / radio
	else:
		vector_input = Vector2.ZERO
		
	enviar_input_al_juego()

func resetear_joystick():
	vector_input = Vector2.ZERO
	dedo_indice = -1
	
	var centro = size / 2.0
	var posicion_objetivo = centro - (palanca.size / 2.0)
	
	# ¡EL DETECTOR DE MENTIRAS!
	print("Base mide: ", size, " | Palanca mide: ", palanca.size, " | Va a la posición: ", posicion_objetivo)
	
	if tween_actual: tween_actual.kill()
	tween_actual = create_tween()
	tween_actual.tween_property(palanca, "position", posicion_objetivo, 0.1).set_trans(Tween.TRANS_SINE)
	
	enviar_input_al_juego()

# ==========================================
# INYECCIÓN DE CONTROLES AL MOTOR
# ==========================================
func enviar_input_al_juego():
	_procesar_eje(accion_der, accion_izq, vector_input.x)
	_procesar_eje(accion_abajo, accion_arriba, vector_input.y)

func _procesar_eje(accion_positiva: String, accion_negativa: String, valor: float):
	if valor > 0:
		Input.action_press(accion_positiva, valor) 
		Input.action_release(accion_negativa)
	elif valor < 0:
		Input.action_press(accion_negativa, -valor)
		Input.action_release(accion_positiva)
	else:
		Input.action_release(accion_positiva)
		Input.action_release(accion_negativa)
