extends VBoxContainer
class_name SelectorPersonaje
# ==========================================================
# SELECTOR DE PERSONAJE (lobby)
# ==========================================================
# Vista 3D del protagonista girando con su animación de espera, su nombre y
# su rol, y flechas ◀ ▶ (táctil, ratón, cruceta o stick del mando).
# Los protagonistas salen de data/personajes.json -> "protagonistas".

signal cambiado(id: String)

var _indice := 0
var _vista: SubViewport
var _pedestal: Node3D
var _modelo: Node3D
var _nombre: Label
var _lema: Label
var _anterior: Button
var _siguiente: Button

func _ready():
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER

	var marco := SubViewportContainer.new()
	marco.stretch = true
	marco.custom_minimum_size = Vector2(260, 300)
	marco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marco)
	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.transparent_bg = true
	_vista.msaa_3d = Viewport.MSAA_DISABLED
	marco.add_child(_vista)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 25, 0)
	luz.light_energy = 1.2
	_vista.add_child(luz)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_CLEAR_COLOR
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.9, 0.9, 1.0)
	amb.environment.ambient_light_energy = 0.7
	_vista.add_child(amb)
	var cam := Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(0, 1.05, 4.4)
	cam.rotation_degrees.x = -4
	_vista.add_child(cam)
	_pedestal = Node3D.new()
	_vista.add_child(_pedestal)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	add_child(fila)
	_anterior = _flecha("◀", -1)
	fila.add_child(_anterior)
	var textos := VBoxContainer.new()
	textos.custom_minimum_size = Vector2(190, 0)
	fila.add_child(textos)
	_nombre = Label.new()
	_nombre.theme_type_variation = &"Titulo"
	_nombre.add_theme_font_size_override("font_size", 26)
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	textos.add_child(_nombre)
	_lema = Label.new()
	_lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	textos.add_child(_lema)
	_siguiente = _flecha("▶", 1)
	fila.add_child(_siguiente)

	var lista := EstadoPartida.protagonistas()
	var inicial := EstadoPartida.cargar_personaje_local()
	for i in lista.size():
		if lista[i].id == inicial: _indice = i
	_mostrar()

func _flecha(texto: String, paso: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(56, 56)
	b.pressed.connect(func(): cambiar(paso))
	EstiloUI.agregar_rebote(b)
	return b

# Con el foco en cualquiera de las flechas, izquierda/derecha cambian de
# personaje directamente (no hace falta apretar A en cada una).
func _input(event: InputEvent):
	if not is_visible_in_tree(): return
	var f := get_viewport().gui_get_focus_owner()
	if f != _anterior and f != _siguiente: return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		cambiar(-1)
		_anterior.grab_focus()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		cambiar(1)
		_siguiente.grab_focus()

# Hacia dónde sale el foco con arriba/abajo (izquierda/derecha cambian de personaje).
func conectar_foco(arriba: Control, abajo: Control):
	for b in [_anterior, _siguiente]:
		b.focus_neighbor_top = b.get_path_to(arriba)
		b.focus_neighbor_bottom = b.get_path_to(abajo)

func flecha() -> Control:
	return _siguiente

func cambiar(paso: int):
	var lista := EstadoPartida.protagonistas()
	if lista.is_empty(): return
	_indice = posmod(_indice + paso, lista.size())
	_mostrar()
	cambiado.emit(lista[_indice].id)

func id_actual() -> String:
	var lista := EstadoPartida.protagonistas()
	return lista[_indice].id if not lista.is_empty() else ""

# Muestra un personaje sin avisar (lo usa el lobby cuando el anfitrión
# asigna otro porque el elegido ya estaba tomado).
func mostrar(id: String):
	var lista := EstadoPartida.protagonistas()
	for i in lista.size():
		if lista[i].id == id and i != _indice:
			_indice = i
			_mostrar()

func _mostrar():
	var lista := EstadoPartida.protagonistas()
	if lista.is_empty(): return
	var p: Dictionary = lista[_indice]
	_nombre.text = p.get("nombre", p.id)
	_lema.text = p.get("lema", "")
	var color := Color(p.get("color", "#ffffff"))
	_nombre.add_theme_color_override("font_color", color.lightened(0.15))
	if _modelo: _modelo.queue_free()
	_modelo = ModelosPSX.personaje(p.modelo)
	_pedestal.add_child(_modelo)
	var a := Animador.para(_modelo.get_child(0), "prota")
	a.poner("rifle_reposo")

func _process(delta: float):
	if _pedestal: _pedestal.rotation.y += delta * 0.6
