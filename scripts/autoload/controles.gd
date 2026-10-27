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
	{"id": "menu_interfaz", "nombre": "Usar los menús del día"},
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
		"menu_interfaz": [_tecla(KEY_TAB), _boton(JOY_BUTTON_BACK)],
		"pausa": [_tecla(KEY_ESCAPE), _boton(JOY_BUTTON_START)],
	}

# true en PC sin pantalla táctil: se apunta con el ratón y se dispara con clic
# (los joysticks de pantalla quedan para el táctil). Se puede cambiar en el menú.
var modo_raton := true
var auto_disparo_mando := true   # disparar al empujar el stick derecho a fondo

# --- Ajustes del mando (Opciones > Controles > Mando) ---
var zona_muerta := 0.2           # cuánto hay que mover el stick antes de que cuente
var umbral_disparo := 0.6        # qué tan a fondo se empuja el stick derecho para disparar
var apuntado_asistido := true    # el apuntado con stick se corrige hacia el zombie más cercano
var vibracion := true
var intensidad_vibracion := 0.7
var sticks_invertidos := false   # zurdos: mover con el derecho y apuntar con el izquierdo

# Último dispositivo usado: el mando o el resto (teclado, ratón, pantalla).
# Con mando se dibuja un marco alrededor del botón enfocado y, en el
# teléfono, se esconden los joysticks de pantalla.
var usando_mando := false
var ultimo_mando := 0

const MOVIMIENTO := ["mover_arriba", "mover_abajo", "mover_izq", "mover_der",
	"apuntar_arriba", "apuntar_abajo", "apuntar_izq", "apuntar_der"]

var _defectos: Dictionary = {}    # acción -> Array[InputEvent] (copia de fábrica)
var _marco: Control

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
	_preparar_menus()
	cargar()
	_crear_marco()

# ----------------------------------------------------------
# MANDO EN LOS MENÚS
# ----------------------------------------------------------
# Godot navega los menús con ui_up/ui_down/ui_accept/ui_cancel, pero solo si
# algún botón tiene el foco: sin eso el mando "no hace nada". Acá:
#   - el stick izquierdo también navega (de fábrica solo la cruceta);
#   - si nadie tiene el foco, el primer toque del mando enfoca un botón del
#     menú que está más adelante (la capa más alta);
#   - un marco dorado muestra dónde está el foco (muchos botones del HUD no
#     tienen estilo de foco propio).
func _preparar_menus():
	var ejes := {"ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0],
		"ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0]}
	for accion in ejes.keys():
		var e := _eje(ejes[accion][0], ejes[accion][1])
		if not InputMap.action_has_event(accion, e): InputMap.action_add_event(accion, e)
	var botones := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}
	for accion in botones.keys():
		var b := _boton(botones[accion])
		if not InputMap.action_has_event(accion, b): InputMap.action_add_event(accion, b)

func _input(event: InputEvent):
	if es_de_mando(event):
		if event is InputEventJoypadButton or absf(event.axis_value) > 0.4:
			usando_mando = true
			ultimo_mando = event.device
	elif event is InputEventMouseMotion:
		if event.relative.length() > 2.0: usando_mando = false
	elif event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton:
		usando_mando = false
	if not es_de_mando(event): return
	var navega := false
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		if event.is_action_pressed(a): navega = true
	if navega and get_viewport().gui_get_focus_owner() == null:
		if enfocar_en(null):
			get_viewport().set_input_as_handled()

# Da el foco al primer control usable dentro de `raiz` (o, si es null, del
# menú más adelante en pantalla). Devuelve true si encontró uno.
func enfocar_en(raiz: Node, solo_con_mando: bool = false) -> bool:
	if solo_con_mando and not usando_mando: return false
	var candidatos := _enfocables(raiz if raiz else get_tree().root)
	if candidatos.is_empty(): return false
	# La capa más alta manda; dentro de ella, el botón principal si hay uno.
	var mejor: Control = null
	var capa_mejor := -INF
	for c in candidatos:
		var capa := _capa(c)
		var principal: bool = c is BaseButton and String(c.theme_type_variation) == "BotonPrimario"
		var mejor_principal: bool = mejor is BaseButton and String(mejor.theme_type_variation) == "BotonPrimario"
		if capa > capa_mejor or (capa == capa_mejor and principal and not mejor_principal):
			capa_mejor = capa
			mejor = c
	mejor.grab_focus()
	return true

func _enfocables(raiz: Node) -> Array:
	var lista: Array = []
	for n in raiz.find_children("*", "Control", true, false):
		var c := n as Control
		if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree(): continue
		if not (c is BaseButton or c is Range or c is ItemList or c is LineEdit): continue
		if c is BaseButton and (c as BaseButton).disabled: continue
		if _excluido(c): continue
		lista.append(c)
	return lista

# El HUD de juego no se enfoca solo (si no, el mando saltaría a sus botones en
# plena pelea): se entra con "Usar los menús del día" (Select / Tab).
func _excluido(c: Node) -> bool:
	var n := c
	while n:
		if n.is_in_group("sin_foco_auto"): return true
		n = n.get_parent()
	return false

func _capa(c: Control) -> float:
	var n: Node = c
	while n:
		if n is CanvasLayer: return float((n as CanvasLayer).layer)
		n = n.get_parent()
	return 0.0

func _crear_marco():
	var capa := CanvasLayer.new()
	capa.layer = 128
	add_child(capa)
	_marco = Control.new()
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marco.draw.connect(_dibujar_marco)
	capa.add_child(_marco)

func _process(_delta):
	if _marco: _marco.queue_redraw()

func _dibujar_marco():
	if not usando_mando: return
	var f := get_viewport().gui_get_focus_owner()
	if not f or not f.is_visible_in_tree(): return
	var r := f.get_global_rect().grow(4)
	var pulso := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
	_marco.draw_rect(r, Color(1.0, 0.82, 0.3, pulso), false, 3.0)

# ----------------------------------------------------------
# VIBRACIÓN Y AJUSTES DEL STICK
# ----------------------------------------------------------
func vibrar(debil: float, fuerte: float, duracion: float):
	if not vibracion or not usando_mando: return
	Input.start_joy_vibration(ultimo_mando, clampf(debil * intensidad_vibracion, 0, 1), clampf(fuerte * intensidad_vibracion, 0, 1), duracion)

func aplicar_zona_muerta():
	for a in MOVIMIENTO:
		if InputMap.has_action(a): InputMap.action_set_deadzone(a, zona_muerta)

# Cambia los ejes del stick izquierdo por los del derecho (y al revés) en
# las acciones de mover y apuntar.
func invertir_sticks(valor: bool):
	if valor == sticks_invertidos: return
	sticks_invertidos = valor
	var cambio := {JOY_AXIS_LEFT_X: JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_X: JOY_AXIS_LEFT_X,
		JOY_AXIS_LEFT_Y: JOY_AXIS_RIGHT_Y, JOY_AXIS_RIGHT_Y: JOY_AXIS_LEFT_Y}
	for a in MOVIMIENTO:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadMotion and cambio.has(e.axis):
				var nuevo := _eje(cambio[e.axis], e.axis_value)
				InputMap.action_erase_event(a, e)
				InputMap.action_add_event(a, nuevo)
	guardar()

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
	zona_muerta = 0.2
	umbral_disparo = 0.6
	apuntado_asistido = true
	vibracion = true
	intensidad_vibracion = 0.7
	sticks_invertidos = false
	aplicar_zona_muerta()
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
	for clave in ["zona_muerta", "umbral_disparo", "apuntado_asistido", "vibracion", "intensidad_vibracion", "sticks_invertidos"]:
		cfg.set_value("mando", clave, get(clave))
	cfg.save(RUTA)

func cargar():
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		aplicar_zona_muerta()
		return
	for a in ACCIONES:
		var lista = cfg.get_value("acciones", a.id, null)
		if typeof(lista) != TYPE_ARRAY: continue
		InputMap.action_erase_events(a.id)
		for e in lista:
			if e is InputEvent: InputMap.action_add_event(a.id, e)
	modo_raton = bool(cfg.get_value("opciones", "modo_raton", modo_raton))
	auto_disparo_mando = bool(cfg.get_value("opciones", "auto_disparo_mando", true))
	for clave in ["zona_muerta", "umbral_disparo", "apuntado_asistido", "vibracion", "intensidad_vibracion", "sticks_invertidos"]:
		set(clave, cfg.get_value("mando", clave, get(clave)))
	aplicar_zona_muerta()

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
