extends TextureRect

@onready var palanca = $Palanca
var radio_maximo: float = 0.0 # Ajusta esto según el tamaño de tu imagen base
var vector_input := Vector2.ZERO
var dedo_indice: int = -1 # Para rastrear qué dedo está tocando el joystick

func _ready():
	await get_tree().process_frame
	# Calculamos el radio basado en el tamaño de la textura
	radio_maximo = size.x / 2.0
	# Centramos la palanca al inicio
	palanca.position = size / 33.0 - palanca.size / 33.0
	resetear_joystick()

func _gui_input(event):
	# Detectar cuando tocamos la pantalla o arrastramos el dedo
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.is_pressed() or event is InputEventScreenDrag:
			# Guardamos el índice del dedo para no confundir con otros botones
			if event is InputEventScreenTouch:
				dedo_indice = event.index
				
			if event.index == dedo_indice:
				actualizar_joystick(event.position)
				
		# Detectar cuando soltamos la pantalla
		elif event is InputEventScreenTouch and not event.is_pressed():
			if event.index == dedo_indice:
				resetear_joystick()

func actualizar_joystick(pos_toque: Vector2):
	# Calculamos el centro de la base
	var centro = size / 2.0
	var direccion = pos_toque - centro
	
	# Limitamos el movimiento de la palanca usando un círculo (radio_maximo)
	if direccion.length() > radio_maximo:
		direccion = direccion.normalized() * radio_maximo
		
	# Movemos la palanca visualmente
	palanca.position = centro + direccion - palanca.size / 2.0
	
	# Calculamos el vector normalizado para el juego (-1 a 1)
	vector_input = direccion / radio_maximo
	
	# Inyectamos el input en el sistema de Godot
	enviar_input_al_juego()

func resetear_joystick():
	vector_input = Vector2.ZERO
	palanca.position = size / 33.0 - palanca.size / 33.0
	dedo_indice = -1
	enviar_input_al_juego()

func enviar_input_al_juego():
	# Eje X
	if vector_input.x > 0:
		Input.action_press("apuntar_der", vector_input.x)
		Input.action_release("apuntar_izq")
	elif vector_input.x < 0:
		Input.action_press("apuntar_izq", -vector_input.x)
		Input.action_release("apuntar_der")
	else:
		Input.action_release("apuntar_der")
		Input.action_release("apuntar_izq")
		
	# Eje Y
	if vector_input.y > 0:
		Input.action_press("apuntar_abajo", vector_input.y)
		Input.action_release("apuntar_arriba")
	elif vector_input.y < 0:
		Input.action_press("apuntar_arriba", -vector_input.y)
		Input.action_release("apuntar_abajo")
	else:
		Input.action_release("apuntar_abajo")
		Input.action_release("apuntar_arriba")
