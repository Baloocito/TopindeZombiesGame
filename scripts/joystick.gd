extends TextureRect

# ==========================================================
# 1. CONFIGURACIÓN DEL JOYSTICK
# ==========================================================
@export_category("Mapeo de Acciones")
@export var accion_izq: String = "mover_izq"
@export var accion_der: String = "mover_der"
@export var accion_arriba: String = "mover_arriba"
@export var accion_abajo: String = "mover_abajo"

@export_category("Diseño Visual (Radios Reales)")
@export var radio_base: float = 75.0 
@export var radio_palanca: float = 40.0
@export var zona_muerta: float = 10.0

enum LadoPantalla { IZQUIERDA, DERECHA }
@export_category("Configuración Flotante")
@export var lado_asignado: LadoPantalla = LadoPantalla.IZQUIERDA

# VARIABLES INTERNAS
@onready var palanca = $Palanca
var vector_input := Vector2.ZERO
var dedo_indice: int = -1
var centro_real: Vector2

func _ready():
	centro_real = Vector2(radio_base, radio_base)
	palanca.anchors_preset = Control.PRESET_TOP_LEFT
	
	visible = false
	modulate.a = 0.6 
	call_deferred("resetear_joystick")

# ==========================================================
# 2. EL CEREBRO FLOTANTE
# ==========================================================
func _unhandled_input(event):
	
	# =========================================================
	# ¡ARREGLADO! Ahora se evalúa antes de procesar el toque
	# =========================================================
	var mundo = get_tree().current_scene
	if mundo and "modo_construccion" in mundo and mundo.modo_construccion:
		if lado_asignado == LadoPantalla.DERECHA:
			resetear_joystick() 
			return 
	# =========================================================

	var toque_id = -1
	var pos_toque = Vector2.ZERO
	
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		toque_id = event.index
		pos_toque = event.position
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		toque_id = 0
		pos_toque = event.position
	else:
		return

	var ancho_pantalla = get_viewport().get_visible_rect().size.x

	# --- A. CUANDO PONEMOS EL DEDO ---
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.is_pressed()):
		if dedo_indice == -1:
			var toco_izquierda = pos_toque.x < (ancho_pantalla / 2.0)
			var es_mi_lado = (lado_asignado == LadoPantalla.IZQUIERDA and toco_izquierda) or (lado_asignado == LadoPantalla.DERECHA and not toco_izquierda)
			
			if es_mi_lado:
				dedo_indice = toque_id
				global_position = pos_toque - centro_real
				visible = true
				palanca.position = centro_real - Vector2(radio_palanca, radio_palanca)
				actualizar_joystick(pos_toque)

	# --- B. CUANDO ARRASTRAMOS EL DEDO ---
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if toque_id == dedo_indice and dedo_indice != -1:
			actualizar_joystick(pos_toque)

	# --- C. CUANDO SOLTAMOS EL DEDO ---
	elif (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.is_pressed()):
		if toque_id == dedo_indice:
			resetear_joystick()

# ==========================================================
# 3. LÓGICA DE MOVIMIENTO
# ==========================================================
func actualizar_joystick(pos_global_dedo: Vector2):
	var pos_local = pos_global_dedo - global_position
	var direccion = pos_local - centro_real
	
	if direccion.length() > radio_base:
		direccion = direccion.normalized() * radio_base
		
	palanca.position = centro_real + direccion - Vector2(radio_palanca, radio_palanca)
	
	# ¡ARREGLADO! Código limpio y sin duplicados
	if direccion.length() > zona_muerta:
		var fuerza = (direccion.length() - zona_muerta) / (radio_base - zona_muerta)
		vector_input = direccion.normalized() * fuerza
		
		# --- EFECTO GATILLO VISUAL ---
		if lado_asignado == LadoPantalla.DERECHA:
			if vector_input.length() > 0.6:
				palanca.modulate = Color(1, 0.2, 0.2) 
			else:
				palanca.modulate = Color.WHITE 
	else:
		vector_input = Vector2.ZERO 
		if lado_asignado == LadoPantalla.DERECHA: 
			palanca.modulate = Color.WHITE
		
	enviar_input_al_juego()

func resetear_joystick():
	vector_input = Vector2.ZERO
	dedo_indice = -1
	visible = false 
	palanca.modulate = Color.WHITE
	enviar_input_al_juego()

# ==========================================================
# 4. INYECCIÓN DE CONTROLES AL MOTOR
# ==========================================================
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
