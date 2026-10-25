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

@export_category("Disparo (solo joystick derecho)")
# Fracción del radio a partir de la cual se empieza a disparar. Debe coincidir
# con el borde del AnilloFuego dibujado (ej. anillo de 60 px con radio_base 100 = 0.6).
@export var umbral_disparo: float = 0.6
# Histéresis: una vez disparando, solo se deja de disparar al bajar de este valor.
# Evita que el tiro "tartamudee" cuando el pulgar tiembla justo en el borde del anillo.
@export var umbral_soltar: float = 0.5
const ACCION_DISPARO := "disparar_tactil"
const COLOR_DISPARO := Color(1.0, 0.6, 0.25)

enum LadoPantalla { IZQUIERDA, DERECHA }
@export_category("Configuración Flotante")
@export var lado_asignado: LadoPantalla = LadoPantalla.IZQUIERDA

# VARIABLES INTERNAS
@onready var palanca = $Palanca
var vector_input := Vector2.ZERO
var dedo_indice: int = -1
var centro_real: Vector2
var disparando: bool = false

func _ready():
	centro_real = Vector2(radio_base, radio_base)
	palanca.anchors_preset = Control.PRESET_TOP_LEFT
	_aplicar_estilo()
	
	visible = false
	modulate.a = 1.0
	if not InputMap.has_action(ACCION_DISPARO):
		InputMap.add_action(ACCION_DISPARO)
	call_deferred("resetear_joystick")

# Si la app pierde el foco, se pausa el árbol o se cambia de escena con el dedo
# puesto, Godot nunca manda el "soltar": el personaje quedaría caminando o
# disparando solo. Soltamos todo por seguridad.
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		if is_node_ready():
			resetear_joystick()

func _exit_tree():
	if is_node_ready():
		resetear_joystick()

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
		# En un celular cada toque genera además un "ratón fantasma" con id 0,
		# que podía secuestrar o duplicar el dedo. Con pantalla táctil real
		# solo escuchamos los toques. (En PC el ratón ya llega como toque
		# gracias a emulate_touch_from_mouse.)
		if DisplayServer.is_touchscreen_available():
			return
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

	# Disparo por zonas: el centro solo apunta; pasar el anillo rojo dispara.
	if lado_asignado == LadoPantalla.DERECHA:
		var ratio = direccion.length() / radio_base
		if ratio >= umbral_disparo:
			disparando = true
		elif ratio < umbral_soltar:
			disparando = false
		palanca.modulate = COLOR_DISPARO if disparando else Color.WHITE
		_aplicar_disparo()
		
	palanca.position = centro_real + direccion - Vector2(radio_palanca, radio_palanca)
	
	# ¡ARREGLADO! Código limpio y sin duplicados
	if direccion.length() > zona_muerta:
		var fuerza = (direccion.length() - zona_muerta) / (radio_base - zona_muerta)
		vector_input = direccion.normalized() * fuerza
	else:
		vector_input = Vector2.ZERO
		
	enviar_input_al_juego()

func resetear_joystick():
	vector_input = Vector2.ZERO
	dedo_indice = -1
	visible = false 
	disparando = false
	palanca.modulate = Color.WHITE
	_aplicar_disparo()
	enviar_input_al_juego()

func _aplicar_disparo():
	if lado_asignado != LadoPantalla.DERECHA: return
	if disparando:
		Input.action_press(ACCION_DISPARO)
	else:
		Input.action_release(ACCION_DISPARO)

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

# ==========================================================
# 5. ESTILO: anillos finos generados por código
# ==========================================================
# Sin texturas: se dibujan con degradados, así se ven nítidos en cualquier
# pantalla. Base = anillo fino con un leve relleno; palanca = disco suave;
# anillo de disparo = anillo naranja en el umbral (solo joystick derecho).
func _aplicar_estilo():
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture = _anillo(Color(1, 1, 1, 0.5), 0.035, 0.07)
	size = Vector2.ONE * radio_base * 2.0
	palanca.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	palanca.stretch_mode = TextureRect.STRETCH_SCALE
	palanca.texture = _disco(Color(1, 1, 1, 0.85))
	palanca.scale = Vector2.ONE
	palanca.size = Vector2.ONE * radio_palanca * 2.0
	palanca.position = centro_real - Vector2(radio_palanca, radio_palanca)
	var anillo := get_node_or_null("AnilloFuego") as TextureRect
	if anillo:
		anillo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		anillo.stretch_mode = TextureRect.STRETCH_SCALE
		anillo.texture = _anillo(Color(1.0, 0.6, 0.25, 0.75), 0.05, 0.0)
		anillo.modulate = Color.WHITE
		anillo.size = Vector2.ONE * radio_base * 2.0 * umbral_disparo
		anillo.position = centro_real - anillo.size / 2.0
	# El contenedor de la escena venía semitransparente; la transparencia ya
	# está en los degradados.
	var padre := get_parent() as CanvasItem
	if padre: padre.modulate = Color(1, 1, 1, 0.9)

func _degradado(offsets: Array, colores: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colores)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t

func _anillo(color: Color, grosor: float, relleno: float) -> GradientTexture2D:
	var dentro := Color(color, relleno)
	var fuera := Color(color, 0.0)
	return _degradado([0.0, 0.97 - grosor - 0.02, 0.97 - grosor, 0.965, 0.995],
		[dentro, dentro, color, color, fuera])

func _disco(color: Color) -> GradientTexture2D:
	return _degradado([0.0, 0.8, 0.93, 1.0], [color, color, Color(color, 0.25), Color(color, 0.0)])
