extends Node
# ==========================================================
# CONTROLES (autoload "Controles")
# ==========================================================
# Acciones del juego, sus teclas por defecto y la reasignación que hace el
# jugador desde Opciones > Controles (se guarda en user://controles.cfg).
# Cada acción tiene dos grupos de entradas independientes:
#   "teclado": teclas y botones del ratón
#   "mando":   botones y ejes del mando
# El táctil no se reasigna (usa los joysticks en pantalla).

const RUTA := "user://controles.cfg"

# Orden y nombre que se muestra en el menú. "solo" limita a un grupo.
const ACCIONES := [
	{"id": "mover_arriba", "nombre": "Mover arriba"},
	{"id": "mover_abajo", "nombre": "Mover abajo"},
	{"id": "mover_izq", "nombre": "Mover a la izquierda"},
	{"id": "mover_der", "nombre": "Mover a la derecha"},
	{"id": "apuntar_arriba", "nombre": "Apuntar arriba", "solo": "mando"},
	{"id": "apuntar_abajo", "nombre": "Apuntar abajo", "solo": "mando"},
	{"id": "apuntar_izq", "nombre": "Apuntar a la izquierda", "solo": "mando"},
	{"id": "apuntar_der", "nombre": "Apuntar a la derecha", "solo": "mando"},
	{"id": "disparar", "nombre": "Disparar"},
	{"id": "recargar", "nombre": "Recargar"},
	{"id": "arma_siguiente", "nombre": "Arma siguiente"},
	{"id": "arma_anterior", "nombre": "Arma anterior"},
	{"id": "arma_1", "nombre": "Arma 1", "solo": "teclado"},
	{"id": "arma_2", "nombre": "Arma 2", "solo": "teclado"},
	{"id": "arma_3", "nombre": "Arma 3", "solo": "teclado"},
	{"id": "iniciar_noche", "nombre": "Listo / iniciar noche"},
	{"id": "pausa", "nombre": "Pausa"},
]

# Entradas por defecto de las acciones que no están en project.godot.
func _por_defecto() -> Dictionary:
	return {
		"disparar": [_raton(MOUSE_BUTTON_LEFT), _eje(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"recargar": [_tecla(KEY_R), _boton(JOY_BUTTON_X)],
		"arma_siguiente": [_tecla(KEY_E), _raton(MOUSE_BUTTON_WHEEL_DOWN), _boton(JOY_BUTTON_RIGHT_SHOULDER)],
		"arma_anterior": [_tecla(KEY_Q), _raton(MOUSE_BUTTON_WHEEL_UP), _boton(JOY_BUTTON_LEFT_SHOULDER)],
		"arma_1": [_tecla(KEY_1)],
		"arma_2": [_tecla(KEY_2)],
		"arma_3": [_tecla(KEY_3)],
		"iniciar_noche": [_tecla(KEY_ENTER), _boton(JOY_BUTTON_Y)],
		"pausa": [_tecla(KEY_ESCAPE), _boton(JOY_BUTTON_START)],
	}

# true en PC sin pantalla táctil: se apunta con el ratón y se dispara con clic
# (los joysticks de pantalla quedan para el táctil). Se puede cambiar en el menú.
var modo_raton := true
var auto_disparo_mando := true   # disparar al empujar el stick derecho a fondo

var _defectos: Dictionary = {}    # acción -> Array[InputEvent] (copia de fábrica)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	modo_raton = not DisplayServer.is_touchscreen_available()
	for accion in _por_defecto().keys():
		if not InputMap.has_action(accion):
			InputMap.add_action(accion, 0.5)
		for e in _por_defecto()[accion]:
			InputMap.action_add_event(accion, e)
	for a in ACCIONES:
		_defectos[a.id] = InputMap.action_get_events(a.id).duplicate()
	cargar()

# ----------------------------------------------------------
func es_de_mando(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion

func eventos(accion: String, grupo: String) -> Array:
	return InputMap.action_get_events(accion).filter(func(e): return es_de_mando(e) == (grupo == "mando"))

# Reemplaza la entrada principal del grupo. Si otra acción ya la usaba,
# intercambian (así nunca quedan dos acciones con la misma tecla).
func reasignar(accion: String, grupo: String, nuevo: InputEvent):
	var viejo: InputEvent = null
	var actuales := eventos(accion, grupo)
	if not actuales.is_empty(): viejo = actuales[0]
	for a in ACCIONES:
		if a.id == accion: continue
		for e in eventos(a.id, grupo):
			if _iguales(e, nuevo):
				InputMap.action_erase_event(a.id, e)
				if viejo: InputMap.action_add_event(a.id, viejo)
	if viejo: InputMap.action_erase_event(accion, viejo)
	InputMap.action_add_event(accion, nuevo)
	guardar()

func restablecer():
	for a in ACCIONES:
		InputMap.action_erase_events(a.id)
		for e in _defectos[a.id]: InputMap.action_add_event(a.id, e)
	modo_raton = not DisplayServer.is_touchscreen_available()
	auto_disparo_mando = true
	guardar()

func _iguales(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and (a.physical_keycode != 0 or a.keycode == b.keycode)
	if a is InputEventMouseButton and b is InputEventMouseButton: return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton: return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false

# ----------------------------------------------------------
func guardar():
	var cfg := ConfigFile.new()
	for a in ACCIONES:
		cfg.set_value("acciones", a.id, InputMap.action_get_events(a.id))
	cfg.set_value("opciones", "modo_raton", modo_raton)
	cfg.set_value("opciones", "auto_disparo_mando", auto_disparo_mando)
	cfg.save(RUTA)

func cargar():
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK: return
	for a in ACCIONES:
		var lista = cfg.get_value("acciones", a.id, null)
		if typeof(lista) != TYPE_ARRAY: continue
		InputMap.action_erase_events(a.id)
		for e in lista:
			if e is InputEvent: InputMap.action_add_event(a.id, e)
	modo_raton = bool(cfg.get_value("opciones", "modo_raton", modo_raton))
	auto_disparo_mando = bool(cfg.get_value("opciones", "auto_disparo_mando", true))

# ----------------------------------------------------------
# NOMBRES PARA MOSTRAR
# ----------------------------------------------------------
const NOMBRES_BOTON := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Guía",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruceta ↑", JOY_BUTTON_DPAD_DOWN: "Cruceta ↓",
	JOY_BUTTON_DPAD_LEFT: "Cruceta ←", JOY_BUTTON_DPAD_RIGHT: "Cruceta →",
}

func nombre_evento(e: InputEvent) -> String:
	if e is InputEventKey:
		var k: Key = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(k) if e.physical_keycode != 0 else k)
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT: return "Clic izquierdo"
			MOUSE_BUTTON_RIGHT: return "Clic derecho"
			MOUSE_BUTTON_MIDDLE: return "Clic central"
			MOUSE_BUTTON_WHEEL_UP: return "Rueda ↑"
			MOUSE_BUTTON_WHEEL_DOWN: return "Rueda ↓"
		return "Ratón %d" % e.button_index
	if e is InputEventJoypadButton:
		return NOMBRES_BOTON.get(e.button_index, "Botón %d" % e.button_index)
	if e is InputEventJoypadMotion:
		var pos: bool = e.axis_value > 0
		match e.axis:
			JOY_AXIS_LEFT_X: return "Stick izq. " + ("→" if pos else "←")
			JOY_AXIS_LEFT_Y: return "Stick izq. " + ("↓" if pos else "↑")
			JOY_AXIS_RIGHT_X: return "Stick der. " + ("→" if pos else "←")
			JOY_AXIS_RIGHT_Y: return "Stick der. " + ("↓" if pos else "↑")
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
		return "Eje %d %s" % [e.axis, "+" if pos else "−"]
	return "?"

func texto_accion(accion: String, grupo: String) -> String:
	var lista := eventos(accion, grupo)
	if lista.is_empty(): return "—"
	return " / ".join(lista.map(func(e): return nombre_evento(e)))

# ----------------------------------------------------------
static func _tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e

static func _raton(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e

static func _boton(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

static func _eje(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e
