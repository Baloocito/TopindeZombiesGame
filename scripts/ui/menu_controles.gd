extends CanvasLayer
class_name MenuControles
# ==========================================================
# MENÚ DE CONTROLES (Opciones > Controles)
# ==========================================================
# Dos pestañas, Teclado y ratón / Mando. Tocar una acción y luego presionar
# la tecla o botón nuevo. Esc (o B en el mando) cancela. Se abre desde el
# menú principal y desde la pausa con MenuControles.abrir(self).

signal cerrado

var _grupo := "teclado"
var _esperando: Dictionary = {}   # {accion, boton} mientras se espera una entrada
var _lista: VBoxContainer
var _tab_teclado: Button
var _tab_mando: Button
var _ayuda: Label
var _opciones: VBoxContainer

static func abrir(padre: Node) -> MenuControles:
	var m := MenuControles.new()
	padre.add_child(m)
	return m

func _ready():
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var tarjeta := PanelContainer.new()
	tarjeta.theme_type_variation = "PanelVidrio"
	tarjeta.custom_minimum_size = Vector2(620, 0)
	centro.add_child(tarjeta)
	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]: margen.add_theme_constant_override("margin_" + lado, 20)
	tarjeta.add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margen.add_child(col)

	var titulo := Label.new()
	titulo.theme_type_variation = "Titulo"
	titulo.text = "CONTROLES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titulo)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	_tab_teclado = _boton_tab("Teclado y ratón", "teclado")
	_tab_mando = _boton_tab("Mando", "mando")
	tabs.add_child(_tab_teclado)
	tabs.add_child(_tab_mando)
	col.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true   # con el mando, la lista baja sola hasta el botón enfocado
	col.add_child(scroll)
	var contenido := VBoxContainer.new()
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 8)
	scroll.add_child(contenido)
	_opciones = VBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 4)
	contenido.add_child(_opciones)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	contenido.add_child(_lista)

	_ayuda = Label.new()
	_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ayuda.modulate = Color(1, 0.85, 0.4)
	col.add_child(_ayuda)

	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_CENTER
	pie.add_theme_constant_override("separation", 14)
	var restablecer := Button.new()
	restablecer.text = "Restablecer"
	restablecer.custom_minimum_size = Vector2(200, 52)
	restablecer.pressed.connect(func():
		Controles.restablecer()
		_refrescar())
	var listo := Button.new()
	listo.text = "Listo"
	listo.theme_type_variation = "BotonPrimario"
	listo.custom_minimum_size = Vector2(200, 52)
	listo.pressed.connect(_cerrar)
	pie.add_child(restablecer)
	pie.add_child(listo)
	col.add_child(pie)
	for b in [restablecer, listo, _tab_teclado, _tab_mando]: EstiloUI.agregar_rebote(b)
	_refrescar()
	listo.grab_focus.call_deferred()

func _boton_tab(texto: String, grupo: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.set_meta("id_control", "tab_" + grupo)
	b.custom_minimum_size = Vector2(200, 46)
	b.pressed.connect(func():
		_grupo = grupo
		_esperando = {}
		_refrescar())
	return b

func _refrescar():
	# Al rehacer la lista se pierde el foco: lo devolvemos a la misma fila
	# (si no, quien usa el mando queda "perdido" después de cada cambio).
	var enfocado := get_viewport().gui_get_focus_owner()
	var volver_a := ""
	if enfocado and enfocado.has_meta("id_control"): volver_a = enfocado.get_meta("id_control")
	_tab_teclado.theme_type_variation = "OpcionPrimaria" if _grupo == "teclado" else "OpcionVidrio"
	_tab_mando.theme_type_variation = "OpcionPrimaria" if _grupo == "mando" else "OpcionVidrio"
	for h in _lista.get_children(): h.queue_free()
	for h in _opciones.get_children(): h.queue_free()
	# Opciones de cada pestaña.
	if _grupo == "teclado":
		_casilla("Apuntar con el ratón (desactiva los joysticks en pantalla)", Controles.modo_raton, _set_modo_raton)
	else:
		_titulo_seccion("Ajustes del mando")
		_casilla("Disparar al empujar el stick derecho a fondo", Controles.auto_disparo_mando, _set_auto_disparo)
		_deslizador("Qué tan a fondo para disparar", Controles.umbral_disparo, 0.3, 0.95, 0.05, _set_umbral)
		_deslizador("Zona muerta de los sticks", Controles.zona_muerta, 0.05, 0.5, 0.05, _set_zona)
		_casilla("Apuntado asistido (corrige la mira hacia el zombie más cercano)", Controles.apuntado_asistido, _set_asistido)
		_casilla("Vibración", Controles.vibracion, _set_vibracion)
		_deslizador("Fuerza de la vibración", Controles.intensidad_vibracion, 0.1, 1.0, 0.1, _set_intensidad)
		_casilla("Modo zurdo (mover con el stick derecho, apuntar con el izquierdo)", Controles.sticks_invertidos, _set_zurdo)
		_titulo_seccion("Botones")
	for a in Controles.ACCIONES:
		if a.has("solo") and a.solo != _grupo: continue
		var fila := HBoxContainer.new()
		var nombre := Label.new()
		nombre.text = a.nombre
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nombre)
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 44)
		b.text = Controles.texto_accion(a.id, _grupo)
		var id: String = a.id
		b.set_meta("id_control", "accion_" + id)
		b.pressed.connect(func(): _empezar_espera(id, b))
		fila.add_child(b)
		_lista.add_child(fila)
	_ayuda.text = "Toca una acción y presiona la tecla nueva." if _grupo == "teclado" else "Elige una acción (A) y presiona el botón o mueve el stick."
	if volver_a != "": _reenfocar.call_deferred(volver_a)

func _reenfocar(id: String):
	for c in find_children("*", "Control", true, false):
		if c.has_meta("id_control") and c.get_meta("id_control") == id and c.is_visible_in_tree():
			(c as Control).grab_focus()
			return

func _set_modo_raton(v): Controles.modo_raton = v
func _set_auto_disparo(v): Controles.auto_disparo_mando = v
func _set_umbral(v): Controles.umbral_disparo = v
func _set_zona(v):
	Controles.zona_muerta = v
	Controles.aplicar_zona_muerta()
func _set_asistido(v): Controles.apuntado_asistido = v
func _set_vibracion(v):
	Controles.vibracion = v
	if v: Controles.vibrar(0.5, 0.5, 0.2)
func _set_intensidad(v):
	Controles.intensidad_vibracion = v
	Controles.vibrar(0.6, 0.6, 0.15)
func _set_zurdo(v):
	Controles.invertir_sticks(v)
	_refrescar.call_deferred()

func _titulo_seccion(texto: String):
	var l := Label.new()
	l.text = texto
	l.modulate = Color(1, 0.85, 0.4)
	_opciones.add_child(l)

func _casilla(texto: String, valor: bool, al_cambiar: Callable):
	var op := CheckButton.new()
	op.text = texto
	op.button_pressed = valor
	op.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	op.set_meta("id_control", "op_" + texto)
	op.toggled.connect(func(v):
		al_cambiar.call(v)
		Controles.guardar())
	_opciones.add_child(op)

func _deslizador(texto: String, valor: float, minimo: float, maximo: float, paso: float, al_cambiar: Callable):
	var formato := "%d %%"
	var factor := 100.0
	var fila := HBoxContainer.new()
	var l := Label.new()
	l.text = texto
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(l)
	var v := Label.new()
	v.custom_minimum_size = Vector2(60, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = formato % int(round(valor * factor))
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = paso
	s.value = valor
	s.custom_minimum_size = Vector2(200, 30)
	s.set_meta("id_control", "op_" + texto)
	s.value_changed.connect(func(x):
		v.text = formato % int(round(x * factor))
		al_cambiar.call(x))
	s.drag_ended.connect(func(_c): Controles.guardar())
	s.focus_exited.connect(Controles.guardar)
	fila.add_child(s)
	fila.add_child(v)
	_opciones.add_child(fila)

func _empezar_espera(accion: String, b: Button):
	_esperando = {"accion": accion, "boton": b}
	b.text = "… presiona …"
	_ayuda.text = "Esperando entrada (Esc para cancelar)" if _grupo == "teclado" else "Esperando entrada (B para cancelar)"

func _input(event: InputEvent):
	if _esperando.is_empty():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_cerrar()
		return
	var nuevo: InputEvent = null
	if _grupo == "teclado":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_cancelar()
				get_viewport().set_input_as_handled()
				return
			nuevo = InputEventKey.new()
			nuevo.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		elif event is InputEventMouseButton and event.pressed:
			nuevo = InputEventMouseButton.new()
			nuevo.button_index = event.button_index
	else:
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_cancelar()
				get_viewport().set_input_as_handled()
				return
			nuevo = InputEventJoypadButton.new()
			nuevo.button_index = event.button_index
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
			nuevo = InputEventJoypadMotion.new()
			nuevo.axis = event.axis
			nuevo.axis_value = signf(event.axis_value)
		elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_cancelar()
			get_viewport().set_input_as_handled()
			return
	if nuevo:
		get_viewport().set_input_as_handled()
		Controles.reasignar(_esperando.accion, _grupo, nuevo)
		_esperando = {}
		_refrescar()

func _cancelar():
	_esperando = {}
	_refrescar()

func _cerrar():
	cerrado.emit()
	queue_free()
