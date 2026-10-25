extends SceneTree
# ==========================================================
# GENERADOR DEL TEMA DE INTERFAZ  ->  res://ui/tema.tres
# ==========================================================
# Ejecutar (desde la carpeta del proyecto):
#   godot --headless -s res://herramientas/generar_tema.gd
# Todos los colores y tamaños están arriba: se cambian aquí y se vuelve a
# generar. El tema se aplica a todo el juego (Proyecto > Ajustes > GUI > Tema).
#
# Variantes de botón (propiedad theme_type_variation del Button):
#   (ninguna)        Secundario: acero oscuro con borde naranja
#   BotonPrimario    Acción principal: naranja de la marca
#   BotonPeligro     Salir, abandonar: rojo
#   BotonIcono       Botones con dibujo propio del HUD: sin caja

const NARANJA := Color("#f08a1c")
const NARANJA_CLARO := Color("#ffa940")
const NARANJA_OSCURO := Color("#b85a0e")
const CONTORNO := Color("#2a1608")
const ACERO := Color("#262b33")
const ACERO_CLARO := Color("#343b46")
const ACERO_OSCURO := Color("#1a1e24")
const ROJO := Color("#c8341f")
const ROJO_CLARO := Color("#e04a33")
const ROJO_OSCURO := Color("#8f2414")
const CREMA := Color("#fff3df")
const TEXTO_APAGADO := Color("#8a8f98")
const PANEL := Color("#16191eeb")

const TAM_TEXTO := 22
const RADIO := 10

func _init():
	var tema := Theme.new()
	var fuente: FontFile = load("res://assets/fuentes/RussoOne.woff2")
	tema.default_font = fuente
	tema.default_font_size = TAM_TEXTO

	_boton(tema, "Button", ACERO, ACERO_CLARO, ACERO_OSCURO, NARANJA, CREMA)
	_variante(tema, "BotonPrimario", NARANJA, NARANJA_CLARO, NARANJA_OSCURO, CONTORNO, CREMA)
	_variante(tema, "BotonPeligro", ROJO, ROJO_CLARO, ROJO_OSCURO, CONTORNO, CREMA)

	# Botones con dibujo propio: sin caja, solo el arte (que trae cada uno).
	tema.set_type_variation("BotonIcono", "Button")
	for estado in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		tema.set_stylebox(estado, "BotonIcono", StyleBoxEmpty.new())

	# Textos
	tema.set_color("font_color", "Label", CREMA)
	tema.set_color("font_outline_color", "Label", CONTORNO)
	tema.set_constant("outline_size", "Label", 0)
	tema.set_type_variation("Titulo", "Label")
	tema.set_font_size("font_size", "Titulo", 44)
	tema.set_color("font_color", "Titulo", NARANJA)
	tema.set_color("font_outline_color", "Titulo", CONTORNO)
	tema.set_constant("outline_size", "Titulo", 12)

	# Campos de texto
	var campo := _caja(ACERO_OSCURO, ACERO_CLARO, 2, 8)
	campo.content_margin_left = 14; campo.content_margin_right = 14
	var campo_foco := _caja(ACERO_OSCURO, NARANJA, 3, 8)
	campo_foco.content_margin_left = 14; campo_foco.content_margin_right = 14
	tema.set_stylebox("normal", "LineEdit", campo)
	tema.set_stylebox("focus", "LineEdit", campo_foco)
	tema.set_stylebox("read_only", "LineEdit", campo)
	tema.set_color("font_color", "LineEdit", CREMA)
	tema.set_color("font_placeholder_color", "LineEdit", TEXTO_APAGADO)
	tema.set_color("caret_color", "LineEdit", NARANJA)
	tema.set_color("selection_color", "LineEdit", NARANJA_OSCURO)
	tema.set_constant("minimum_character_width", "LineEdit", 4)

	# Paneles y listas
	var panel := _caja(PANEL, NARANJA_OSCURO, 3, 14)
	panel.content_margin_left = 22; panel.content_margin_right = 22
	panel.content_margin_top = 18; panel.content_margin_bottom = 18
	panel.shadow_color = Color(0, 0, 0, 0.45); panel.shadow_size = 12
	tema.set_stylebox("panel", "PanelContainer", panel)
	tema.set_stylebox("panel", "Panel", panel)
	var lista := _caja(ACERO_OSCURO, ACERO_CLARO, 2, 8)
	lista.content_margin_left = 10; lista.content_margin_top = 8
	tema.set_stylebox("panel", "ItemList", lista)
	tema.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	tema.set_color("font_color", "ItemList", CREMA)
	tema.set_constant("v_separation", "ItemList", 10)

	var linea := StyleBoxLine.new()
	linea.color = NARANJA_OSCURO; linea.thickness = 2
	tema.set_stylebox("separator", "HSeparator", linea)

	_hud(tema)

	var err := ResourceSaver.save(tema, "res://ui/tema.tres")
	print("Tema generado: res://ui/tema.tres (", error_string(err), ")")
	quit()

# ----------------------------------------------------------
# HUD de juego: estilo "vidrio" (oscuro, translúcido, bordes finos)
# ----------------------------------------------------------
const VIDRIO := Color(0.06, 0.07, 0.09, 0.58)
const VIDRIO_CLARO := Color(0.16, 0.18, 0.22, 0.72)
const BORDE_VIDRIO := Color(1, 1, 1, 0.14)
const VERDE_VIDA := Color("#4ade80")
const CELESTE_XP := Color("#38bdf8")
const ORO := Color("#facc15")

func _hud(tema: Theme):
	# Panel y chip de vidrio
	var panel := _caja(VIDRIO, BORDE_VIDRIO, 1, 16)
	_margen_todo(panel, 12, 8)
	tema.set_type_variation("PanelVidrio", "PanelContainer")
	tema.set_stylebox("panel", "PanelVidrio", panel)
	var chip := _caja(VIDRIO, BORDE_VIDRIO, 1, 999)
	_margen_todo(chip, 16, 6)
	tema.set_type_variation("ChipVidrio", "PanelContainer")
	tema.set_stylebox("panel", "ChipVidrio", chip)
	var lateral := _caja(Color(0.05, 0.06, 0.08, 0.9), BORDE_VIDRIO, 1, 20)
	_margen_todo(lateral, 18, 18)
	tema.set_type_variation("PanelLateralVidrio", "Panel")
	tema.set_stylebox("panel", "PanelLateralVidrio", lateral)

	# Botón redondo de ícono
	tema.set_type_variation("BotonRedondo", "Button")
	var r_normal := _caja(VIDRIO, BORDE_VIDRIO, 1, 999)
	_margen_todo(r_normal, 12, 12)
	var r_hover := r_normal.duplicate(); r_hover.bg_color = VIDRIO_CLARO
	var r_press := r_normal.duplicate(); r_press.bg_color = Color(NARANJA, 0.9); r_press.border_color = Color(NARANJA_CLARO, 0.9)
	var r_off := r_normal.duplicate(); r_off.bg_color = Color(VIDRIO, 0.3)
	for par in [["normal", r_normal], ["hover", r_hover], ["pressed", r_press], ["hover_pressed", r_press], ["disabled", r_off], ["focus", StyleBoxEmpty.new()]]:
		tema.set_stylebox(par[0], "BotonRedondo", par[1])
	tema.set_color("icon_normal_color", "BotonRedondo", Color.WHITE)
	tema.set_color("icon_hover_color", "BotonRedondo", Color.WHITE)
	tema.set_color("icon_pressed_color", "BotonRedondo", Color.WHITE)
	tema.set_color("icon_disabled_color", "BotonRedondo", Color(1, 1, 1, 0.35))
	tema.set_constant("icon_max_width", "BotonRedondo", 30)
	tema.set_color("font_outline_color", "BotonRedondo", Color(0, 0, 0, 0))
	tema.set_constant("outline_size", "BotonRedondo", 0)

	# Píldora principal del HUD (Iniciar noche)
	tema.set_type_variation("BotonPildora", "Button")
	var p_normal := _caja(Color(NARANJA, 0.95), Color(NARANJA_CLARO, 0.9), 1, 999)
	_margen_todo(p_normal, 26, 12)
	var p_hover := p_normal.duplicate(); p_hover.bg_color = NARANJA_CLARO
	var p_press := p_normal.duplicate(); p_press.bg_color = NARANJA_OSCURO
	var p_off := p_normal.duplicate(); p_off.bg_color = Color(0.35, 0.3, 0.25, 0.7); p_off.border_color = BORDE_VIDRIO
	for par in [["normal", p_normal], ["hover", p_hover], ["pressed", p_press], ["hover_pressed", p_press], ["disabled", p_off], ["focus", StyleBoxEmpty.new()]]:
		tema.set_stylebox(par[0], "BotonPildora", par[1])
	tema.set_color("font_color", "BotonPildora", Color.WHITE)
	tema.set_color("font_disabled_color", "BotonPildora", Color(1, 1, 1, 0.8))
	tema.set_color("icon_normal_color", "BotonPildora", Color.WHITE)
	tema.set_color("icon_disabled_color", "BotonPildora", Color(1, 1, 1, 0.8))
	tema.set_constant("icon_max_width", "BotonPildora", 24)
	tema.set_constant("outline_size", "BotonPildora", 0)
	tema.set_constant("h_separation", "BotonPildora", 10)

	# Píldora de vidrio (Reparar y acciones secundarias del HUD)
	tema.set_type_variation("BotonPildoraVidrio", "Button")
	var v_normal := _caja(VIDRIO, BORDE_VIDRIO, 1, 999)
	_margen_todo(v_normal, 20, 10)
	var v_hover := v_normal.duplicate(); v_hover.bg_color = VIDRIO_CLARO
	var v_press := v_normal.duplicate(); v_press.bg_color = Color(NARANJA, 0.85)
	var v_off := v_normal.duplicate(); v_off.bg_color = Color(VIDRIO, 0.3)
	for par in [["normal", v_normal], ["hover", v_hover], ["pressed", v_press], ["hover_pressed", v_press], ["disabled", v_off], ["focus", StyleBoxEmpty.new()]]:
		tema.set_stylebox(par[0], "BotonPildoraVidrio", par[1])
	tema.set_color("font_color", "BotonPildoraVidrio", Color.WHITE)
	tema.set_color("font_disabled_color", "BotonPildoraVidrio", Color(1, 1, 1, 0.45))
	tema.set_constant("outline_size", "BotonPildoraVidrio", 0)
	tema.set_font_size("font_size", "BotonPildoraVidrio", 18)
	tema.set_color("icon_normal_color", "BotonPildoraVidrio", Color.WHITE)
	tema.set_constant("icon_max_width", "BotonPildoraVidrio", 20)

	# Tarjeta de arma (combate)
	tema.set_type_variation("TarjetaArma", "Button")
	var a_normal := _caja(VIDRIO, BORDE_VIDRIO, 1, 14)
	_margen_todo(a_normal, 12, 6)
	var a_press := a_normal.duplicate(); a_press.bg_color = VIDRIO_CLARO
	for par in [["normal", a_normal], ["hover", a_normal], ["pressed", a_press], ["hover_pressed", a_press], ["disabled", a_normal], ["focus", StyleBoxEmpty.new()]]:
		tema.set_stylebox(par[0], "TarjetaArma", par[1])
	tema.set_type_variation("TarjetaArmaActiva", "Button")
	var act := _caja(Color(0.1, 0.08, 0.05, 0.72), NARANJA, 2, 14)
	_margen_todo(act, 12, 6)
	for par in [["normal", act], ["hover", act], ["pressed", act], ["hover_pressed", act], ["disabled", act], ["focus", StyleBoxEmpty.new()]]:
		tema.set_stylebox(par[0], "TarjetaArmaActiva", par[1])

	# Opciones del panel lateral (listas de construcción, armas, mesa...)
	_opcion(tema, "OpcionVidrio", Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), Color(NARANJA, 0.85), BORDE_VIDRIO)
	_opcion(tema, "OpcionPrimaria", Color(NARANJA, 0.92), NARANJA_CLARO, NARANJA_OSCURO, Color(NARANJA_CLARO, 0.6))

	# Textos pequeños del HUD (con sombra para leerse sobre el escenario)
	tema.set_type_variation("TextoHud", "Label")
	tema.set_font_size("font_size", "TextoHud", 16)
	tema.set_color("font_color", "TextoHud", Color.WHITE)
	tema.set_color("font_shadow_color", "TextoHud", Color(0, 0, 0, 0.6))
	tema.set_constant("shadow_offset_x", "TextoHud", 0)
	tema.set_constant("shadow_offset_y", "TextoHud", 1)
	tema.set_type_variation("TextoHudChico", "Label")
	tema.set_font_size("font_size", "TextoHudChico", 13)
	tema.set_color("font_color", "TextoHudChico", Color(1, 1, 1, 0.75))
	tema.set_color("font_shadow_color", "TextoHudChico", Color(0, 0, 0, 0.6))
	tema.set_constant("shadow_offset_y", "TextoHudChico", 1)

	# Barras finas y redondeadas
	_barra(tema, "BarraVida", VERDE_VIDA, 10)
	_barra(tema, "BarraXP", CELESTE_XP, 6)

func _opcion(tema: Theme, nombre: String, fondo: Color, claro: Color, presionado: Color, borde: Color):
	tema.set_type_variation(nombre, "Button")
	var n := _caja(fondo, borde, 1, 12)
	_margen_todo(n, 16, 10)
	var h := n.duplicate(); h.bg_color = claro
	var p := n.duplicate(); p.bg_color = presionado
	var d := n.duplicate(); d.bg_color = Color(fondo, fondo.a * 0.4); d.border_color = Color(borde, borde.a * 0.5)
	for par in [["normal", n], ["hover", h], ["pressed", p], ["hover_pressed", p], ["disabled", d], ["focus", StyleBoxEmpty.new()]]:
		tema.set_stylebox(par[0], nombre, par[1])
	tema.set_color("font_color", nombre, Color.WHITE)
	tema.set_color("font_hover_color", nombre, Color.WHITE)
	tema.set_color("font_pressed_color", nombre, Color.WHITE)
	tema.set_color("font_disabled_color", nombre, Color(1, 1, 1, 0.35))
	tema.set_constant("outline_size", nombre, 0)
	tema.set_font_size("font_size", nombre, 18)

func _barra(tema: Theme, nombre: String, color: Color, alto: int):
	tema.set_type_variation(nombre, "ProgressBar")
	var fondo := _caja(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.08), 1, 999)
	fondo.content_margin_top = alto / 2.0; fondo.content_margin_bottom = alto / 2.0
	var relleno := _caja(color, color, 0, 999)
	tema.set_stylebox("background", nombre, fondo)
	tema.set_stylebox("fill", nombre, relleno)
	tema.set_font_size("font_size", nombre, 1)
	tema.set_color("font_color", nombre, Color(0, 0, 0, 0))

func _margen_todo(c: StyleBox, h: float, v: float):
	c.content_margin_left = h; c.content_margin_right = h
	c.content_margin_top = v; c.content_margin_bottom = v

func _caja(fondo: Color, borde: Color, grosor: int, radio: int) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fondo
	c.border_color = borde
	c.set_border_width_all(grosor)
	c.set_corner_radius_all(radio)
	c.anti_aliasing = true
	return c

# Botón con efecto de "tecla": sombra debajo que desaparece al presionarlo,
# y el texto baja 3 px. Se siente físico en una pantalla táctil.
func _estilos_boton(fondo: Color, claro: Color, oscuro: Color, borde: Color) -> Dictionary:
	var normal := _caja(fondo, borde, 3, RADIO)
	normal.shadow_color = Color(0, 0, 0, 0.55); normal.shadow_size = 0; normal.shadow_offset = Vector2(0, 4)
	normal.expand_margin_bottom = 0
	normal.border_width_bottom = 6
	_margenes(normal, 0)
	var hover := normal.duplicate(); hover.bg_color = claro
	var presionado := normal.duplicate()
	presionado.bg_color = oscuro
	presionado.border_width_bottom = 3
	_margenes(presionado, 3)
	var deshabilitado := normal.duplicate()
	deshabilitado.bg_color = Color(fondo.darkened(0.45), 0.85)
	deshabilitado.border_color = Color(borde.darkened(0.4), 0.85)
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.border_color = CREMA
	foco.set_border_width_all(2)
	foco.set_corner_radius_all(RADIO + 2)
	foco.expand_margin_left = 3; foco.expand_margin_right = 3
	foco.expand_margin_top = 3; foco.expand_margin_bottom = 3
	return {"normal": normal, "hover": hover, "pressed": presionado, "hover_pressed": presionado,
		"disabled": deshabilitado, "focus": foco}

func _margenes(c: StyleBoxFlat, bajada: int):
	c.content_margin_left = 22; c.content_margin_right = 22
	c.content_margin_top = 10 + bajada; c.content_margin_bottom = 10 - bajada

func _boton(tema: Theme, tipo: String, fondo: Color, claro: Color, oscuro: Color, borde: Color, texto: Color):
	var estilos := _estilos_boton(fondo, claro, oscuro, borde)
	for estado in estilos.keys(): tema.set_stylebox(estado, tipo, estilos[estado])
	tema.set_color("font_color", tipo, texto)
	tema.set_color("font_hover_color", tipo, texto)
	tema.set_color("font_pressed_color", tipo, texto.darkened(0.1))
	tema.set_color("font_hover_pressed_color", tipo, texto.darkened(0.1))
	tema.set_color("font_focus_color", tipo, texto)
	tema.set_color("font_disabled_color", tipo, TEXTO_APAGADO)
	tema.set_color("font_outline_color", tipo, CONTORNO)
	tema.set_constant("outline_size", tipo, 6)
	tema.set_constant("h_separation", tipo, 10)

func _variante(tema: Theme, nombre: String, fondo: Color, claro: Color, oscuro: Color, borde: Color, texto: Color):
	tema.set_type_variation(nombre, "Button")
	_boton(tema, nombre, fondo, claro, oscuro, borde, texto)
