extends Node
# ==========================================================
# REHACE EL HUD DE mundo.tscn (estilo vidrio, íconos de línea)
# ==========================================================
# Herramienta de una sola vez, guardada como referencia de cómo está armado
# el HUD. Se ejecuta como escena (necesita los autoloads cargados):
#   godot --headless --path . res://herramientas/rehacer_hud.tscn
# Borra los nodos viejos del HUD y crea los nuevos con los mismos nombres que
# usa el código (mundo.gd, jugador.gd). Los estilos viven en ui/tema.tres.

const RUTA := "res://scenes/mundo.tscn"
const ICONOS := "res://assets/ui/iconos/"

# Nodos del HUD que se conservan (se re-estilan, no se rehacen).
const CONSERVAR := ["JoystickApuntado", "JoystickVirtual", "ContenedorAlertas", "PanelLateral", "TextoGameOver", "BotonReiniciar"]

var raiz: Node

func _ready():
	var escena: PackedScene = load(RUTA)
	raiz = escena.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var ui: CanvasLayer = raiz.get_node("InterfazUI")

	for hijo in ui.get_children():
		if not (hijo.name in CONSERVAR):
			ui.remove_child(hijo)
			hijo.free()

	_tarjeta_jugador(ui)
	_superior_derecha(ui)
	_lateral_derecho(ui)
	_inferior_centro(ui)
	_esquina_armas(ui)
	_restilar_conservados(ui)

	# Orden de dibujo: joysticks al fondo, panel lateral y fin de partida arriba.
	ui.move_child(ui.get_node("JoystickVirtual"), 0)
	ui.move_child(ui.get_node("JoystickApuntado"), 1)
	ui.move_child(ui.get_node("PanelLateral"), ui.get_child_count() - 1)
	ui.move_child(ui.get_node("TextoGameOver"), ui.get_child_count() - 1)
	ui.move_child(ui.get_node("BotonReiniciar"), ui.get_child_count() - 1)

	var nueva := PackedScene.new()
	var err := nueva.pack(raiz)
	if err != OK:
		push_error("No se pudo empaquetar: %s" % error_string(err))
	else:
		err = ResourceSaver.save(nueva, RUTA)
		print("HUD rehecho: ", RUTA, " (", error_string(err), ")")
	raiz.free()
	get_tree().quit()

# ----------------------------------------------------------
func _nuevo(clase, nombre: String, padre: Node) -> Node:
	var n = clase.new()
	n.name = nombre
	padre.add_child(n)
	n.owner = raiz
	return n

func _icono(nombre: String) -> Texture2D:
	return load(ICONOS + nombre + ".svg")

func _boton_redondo(nombre: String, padre: Node, icono: String, lado: int) -> Button:
	var b: Button = _nuevo(Button, nombre, padre)
	b.theme_type_variation = &"BotonRedondo"
	b.icon = _icono(icono)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(lado, lado)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _texto(nombre: String, padre: Node, texto: String, variante: StringName) -> Label:
	var l: Label = _nuevo(Label, nombre, padre)
	l.text = texto
	l.theme_type_variation = variante
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _anclar(c: Control, izq: float, arr: float, der: float, aba: float, o: Rect2, crecer_h: int, crecer_v: int):
	c.anchor_left = izq; c.anchor_top = arr; c.anchor_right = der; c.anchor_bottom = aba
	c.offset_left = o.position.x; c.offset_top = o.position.y
	c.offset_right = o.size.x; c.offset_bottom = o.size.y
	c.grow_horizontal = crecer_h; c.grow_vertical = crecer_v

# ----------------------------------------------------------
# Arriba a la izquierda: tarjeta del jugador
# ----------------------------------------------------------
func _tarjeta_jugador(ui: Node):
	var cont: MarginContainer = _nuevo(MarginContainer, "HudSuperiorIzquierdo", ui)
	_anclar(cont, 0, 0, 0, 0, Rect2(16, 14, 16, 14), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tarjeta: PanelContainer = _nuevo(PanelContainer, "TarjetaJugador", cont)
	tarjeta.theme_type_variation = &"PanelVidrio"
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fila: HBoxContainer = _nuevo(HBoxContainer, "Fila", tarjeta)
	fila.add_theme_constant_override("separation", 12)
	var nivel := _boton_redondo("BotonNivel", fila, "star", 52)
	nivel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var stats: VBoxContainer = _nuevo(VBoxContainer, "HudEstadisticas", fila)
	stats.custom_minimum_size = Vector2(200, 0)
	stats.add_theme_constant_override("separation", 3)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var fila_salud: HBoxContainer = _nuevo(HBoxContainer, "FilaSalud", stats)
	fila_salud.add_theme_constant_override("separation", 6)
	var corazon: TextureRect = _nuevo(TextureRect, "IconoVida", fila_salud)
	corazon.texture = _icono("heart")
	corazon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	corazon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	corazon.custom_minimum_size = Vector2(16, 16)
	corazon.modulate = Color("#4ade80")
	_texto("LblSaludText", fila_salud, "VIDA", &"TextoHudChico")
	var relleno: Control = _nuevo(Control, "Control", fila_salud)
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto("LblSaludNum", fila_salud, "100 / 100", &"TextoHud")
	var barra_vida: ProgressBar = _nuevo(ProgressBar, "BarraSalud", stats)
	barra_vida.theme_type_variation = &"BarraVida"
	barra_vida.show_percentage = false
	barra_vida.custom_minimum_size = Vector2(0, 10)
	barra_vida.value = 100
	_texto("LblNivel", stats, "NIVEL 1", &"TextoHudChico")
	var barra_xp: ProgressBar = _nuevo(ProgressBar, "BarraXP", stats)
	barra_xp.theme_type_variation = &"BarraXP"
	barra_xp.show_percentage = false
	barra_xp.custom_minimum_size = Vector2(0, 6)

# ----------------------------------------------------------
# Arriba a la derecha: oro y pausa
# ----------------------------------------------------------
func _superior_derecha(ui: Node):
	var cont: MarginContainer = _nuevo(MarginContainer, "HudSuperiorDerecho", ui)
	_anclar(cont, 1, 0, 1, 0, Rect2(-16, 14, -16, 14), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fila: HBoxContainer = _nuevo(HBoxContainer, "Fila", cont)
	fila.add_theme_constant_override("separation", 10)
	var oro: PanelContainer = _nuevo(PanelContainer, "GrupoDinero", fila)
	oro.theme_type_variation = &"ChipVidrio"
	oro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	oro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fila_oro: HBoxContainer = _nuevo(HBoxContainer, "Fila", oro)
	fila_oro.add_theme_constant_override("separation", 8)
	var moneda: TextureRect = _nuevo(TextureRect, "IconoOro", fila_oro)
	moneda.texture = _icono("coins")
	moneda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moneda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moneda.custom_minimum_size = Vector2(22, 22)
	moneda.modulate = Color("#facc15")
	var lbl: Label = _texto("LblDinero", fila_oro, "500", &"TextoHud")
	lbl.add_theme_font_size_override("font_size", 20)
	_boton_redondo("BotonPausa", fila, "pause", 52)

# ----------------------------------------------------------
# Derecha (de día): herramientas
# ----------------------------------------------------------
func _lateral_derecho(ui: Node):
	var col: VBoxContainer = _nuevo(VBoxContainer, "HudLateralDerecho", ui)
	_anclar(col, 1, 0.5, 1, 0.5, Rect2(-104, -130, -16, 130), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for datos in [["BotonConstruir", "hammer", "Construir"], ["BotonMochila", "backpack", "Armas"], ["BotonEnsamblar", "anvil", "Mesa"]]:
		var item: VBoxContainer = _nuevo(VBoxContainer, "Item" + datos[0].trim_prefix("Boton"), col)
		item.add_theme_constant_override("separation", 2)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b := _boton_redondo(datos[0], item, datos[1], 62)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var l := _texto("Etiqueta", item, datos[2], &"TextoHudChico")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ----------------------------------------------------------
# Abajo al centro (de día): iniciar la noche y reparar
# ----------------------------------------------------------
func _inferior_centro(ui: Node):
	var fila: HBoxContainer = _nuevo(HBoxContainer, "HudInferiorCentro", ui)
	_anclar(fila, 0.5, 1, 0.5, 1, Rect2(-220, -84, 220, -20), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reparar: Button = _nuevo(Button, "BotonReparar", fila)
	reparar.theme_type_variation = &"BotonPildoraVidrio"
	reparar.icon = _icono("hammer")
	reparar.text = "Base intacta"
	reparar.focus_mode = Control.FOCUS_NONE
	reparar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var iniciar: Button = _nuevo(Button, "BotonIniciar", fila)
	iniciar.theme_type_variation = &"BotonPildora"
	iniciar.icon = _icono("moon")
	iniciar.text = "Iniciar noche"
	iniciar.focus_mode = Control.FOCUS_NONE
	iniciar.custom_minimum_size = Vector2(230, 58)

# ----------------------------------------------------------
# Derecha (de noche): armas y recarga
# ----------------------------------------------------------
func _esquina_armas(ui: Node):
	var col: VBoxContainer = _nuevo(VBoxContainer, "EsquinaArmas", ui)
	_anclar(col, 1, 0.5, 1, 0.5, Rect2(-176, -150, -16, 150), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var armas: VBoxContainer = _nuevo(VBoxContainer, "ContenedorArmas", col)
	armas.add_theme_constant_override("separation", 8)
	armas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var slot: Button = _nuevo(Button, "SlotArma%d" % (i + 1), armas)
		slot.theme_type_variation = &"TarjetaArma"
		slot.custom_minimum_size = Vector2(160, 56)
		slot.focus_mode = Control.FOCUS_NONE
		var caja: VBoxContainer = _nuevo(VBoxContainer, "VBoxContainer", slot)
		caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caja.offset_left = 12; caja.offset_right = -12
		caja.alignment = BoxContainer.ALIGNMENT_CENTER
		caja.add_theme_constant_override("separation", 0)
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texto("LblNombre", caja, "Pistola 9mm", &"TextoHudChico")
		_texto("LblBalas", caja, "12 / 90", &"TextoHud")
	var recarga := _boton_redondo("BotonRecargaDerecho", col, "rotate-ccw", 60)
	recarga.size_flags_horizontal = Control.SIZE_SHRINK_END
	# El botón izquierdo de recarga se elimina (la recarga ya es automática al
	# vaciar el cargador); se deja oculto por compatibilidad con mundo.gd.
	var izq := _boton_redondo("BotonRecargaIzquierdo", ui, "rotate-ccw", 56)
	izq.visible = false

# ----------------------------------------------------------
func _restilar_conservados(ui: Node):
	var lateral: Panel = ui.get_node("PanelLateral")
	lateral.remove_theme_stylebox_override("panel")
	lateral.self_modulate = Color.WHITE
	lateral.theme_type_variation = &"PanelLateralVidrio"
	lateral.anchor_left = 1; lateral.anchor_right = 1; lateral.anchor_top = 0; lateral.anchor_bottom = 1
	lateral.offset_left = -416; lateral.offset_right = -12; lateral.offset_top = 12; lateral.offset_bottom = -12
	var cerrar: Button = lateral.get_node("BotonCerrar")
	cerrar.remove_theme_stylebox_override("normal")
	cerrar.remove_theme_font_size_override("font_size")
	cerrar.text = ""
	cerrar.theme_type_variation = &"BotonRedondo"
	cerrar.icon = _icono("x")
	cerrar.expand_icon = true
	cerrar.custom_minimum_size = Vector2(46, 46)
	cerrar.anchor_left = 1; cerrar.anchor_right = 1; cerrar.anchor_top = 0; cerrar.anchor_bottom = 0
	cerrar.offset_left = -60; cerrar.offset_right = -14; cerrar.offset_top = 14; cerrar.offset_bottom = 60

	var fase: PanelContainer = ui.get_node("ContenedorAlertas/PanelFase")
	fase.remove_theme_stylebox_override("panel")
	fase.theme_type_variation = &"PanelVidrio"
	var titulo: Label = fase.get_node("VBoxContainer/LblTituloFase")
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	var alertas: VBoxContainer = ui.get_node("ContenedorAlertas")
	alertas.anchor_left = 0.5; alertas.anchor_right = 0.5; alertas.anchor_top = 0; alertas.anchor_bottom = 0
	alertas.offset_left = -200; alertas.offset_right = 200; alertas.offset_top = 92; alertas.offset_bottom = 260
	alertas.add_theme_constant_override("separation", 14)

	var game_over: Label = ui.get_node("TextoGameOver")
	game_over.add_theme_font_size_override("font_size", 72)
	game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over.text = "TODO EL EQUIPO CAYÓ"
	game_over.anchor_left = 0.5; game_over.anchor_right = 0.5; game_over.anchor_top = 0.5; game_over.anchor_bottom = 0.5
	game_over.offset_left = -520; game_over.offset_right = 520; game_over.offset_top = -120; game_over.offset_bottom = -20
	var reiniciar: Button = ui.get_node("BotonReiniciar")
	reiniciar.theme_type_variation = &"BotonPildora"
	reiniciar.icon = _icono("rotate-ccw")
	reiniciar.text = "Reintentar"
	reiniciar.anchor_left = 0.5; reiniciar.anchor_right = 0.5; reiniciar.anchor_top = 0.5; reiniciar.anchor_bottom = 0.5
	reiniciar.offset_left = -120; reiniciar.offset_right = 120; reiniciar.offset_top = 10; reiniciar.offset_bottom = 70
