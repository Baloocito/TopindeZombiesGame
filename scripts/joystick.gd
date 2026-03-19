extends TextureRect

# ==========================================================
# 1. CONFIGURACIÓN DEL JOYSTICK
# ==========================================================
@export_category("Mapeo de Acciones")
@export var accion_izq: String = "mover_izq"
@export var accion_der: String = "mover_der"
@export var accion_arriba: String = "mover_arriba"
@export var accion_abajo: String = "mover_abajo"

@export_category("Comportamiento Moderno")
@export_range(0, 50, 1) var zona_muerta: float = 10.0
enum ModoJoystick { FIJO, DINAMICO, PERSECUCION }
@export var modo_joystick: ModoJoystick = ModoJoystick.FIJO
enum ModoVisibilidad { SIEMPRE, SOLO_PANTALLA_TACTIL }
@export var visibilidad: ModoVisibilidad = ModoVisibilidad.SIEMPRE

# ==========================================================
# ¡TU IDEA! LE DICTAMOS EL TAMAÑO AL CÓDIGO
# ==========================================================
@export_category("Diseño Visual (Radios Reales)")
## Si tu base mide 150x150, pon 75 aquí.
@export var radio_base: float = 75.0 
## Si tu bolita mide 80x80, pon 40 aquí.
@export var radio_palanca: float = 40.0

# VARIABLES INTERNAS
@onready var palanca = $Palanca
var vector_input := Vector2.ZERO
var dedo_indice: int = -1
var tween_actual: Tween
var posicion_base_original: Vector2

func _ready():
	if visibilidad == ModoVisibilidad.SOLO_PANTALLA_TACTIL and not DisplayServer.is_touchscreen_available():
		hide()
		set_process_input(false)
		return

	posicion_base_original = position
	# Desconectamos a la palanca del sistema de anclas caprichoso de Godot
	palanca.anchors_preset = Control.PRESET_TOP_LEFT
	
	call_deferred("resetear_joystick")

func _gui_input(event):
	var toque_id = -1
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		toque_id = event.index
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		toque_id = 0 

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed() and dedo_indice == -1:
			dedo_indice = toque_id
			if tween_actual: tween_actual.kill() 
			
			var pos_local_actual = event.position
			
			if modo_joystick == ModoJoystick.DINAMICO or modo_joystick == ModoJoystick.PERSECUCION:
				# Usamos nuestras dimensiones fijas
				var tamaño_base_fijo = Vector2(radio_base * 2, radio_base * 1)
				global_position = get_global_mouse_position() - (tamaño_base_fijo / 2.0)
				pos_local_actual = Vector2(radio_base, radio_base)
			
			actualizar_joystick(pos_local_actual)
			
		elif not event.is_pressed() and toque_id == dedo_indice:
			resetear_joystick()
			
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if toque_id == dedo_indice and dedo_indice != -1:
			actualizar_joystick(event.position) 
			
func actualizar_joystick(pos_toque_local: Vector2):
	# =========================================================
	# USAMOS TUS DIMENSIONES FIJAS Y BLINDAMOS LA MATEMÁTICA
	# =========================================================
	var centro_real = Vector2(radio_base, radio_base)
	var direccion = pos_toque_local - centro_real
	
	if direccion.length() > radio_base:
		if modo_joystick == ModoJoystick.PERSECUCION:
			var exceso = direccion.length() - radio_base
			global_position += direccion.normalized() * exceso
			
		direccion = direccion.normalized() * radio_base
		
	# Mueve la bolita ignorando los tamaños de las imágenes de Godot
	palanca.position = centro_real + direccion - Vector2(radio_palanca, radio_palanca)
	
	if direccion.length() > zona_muerta:
		var fuerza = (direccion.length() - zona_muerta) / (radio_base - zona_muerta)
		vector_input = direccion.normalized() * fuerza
	else:
		vector_input = Vector2.ZERO 
		
	enviar_input_al_juego()

func resetear_joystick():
	vector_input = Vector2.ZERO
	dedo_indice = -1
	
	if modo_joystick != ModoJoystick.FIJO:
		position = posicion_base_original
		
	# Animación usando tus tamaños fijos
	var centro_real = Vector2(radio_base, radio_base)
	var posicion_objetivo = centro_real - Vector2(radio_palanca, radio_palanca)
	
	if tween_actual: tween_actual.kill()
	tween_actual = create_tween()
	tween_actual.tween_property(palanca, "position", posicion_objetivo, 0.1).set_trans(Tween.TRANS_SINE)
	
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
