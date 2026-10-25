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

	var err := ResourceSaver.save(tema, "res://ui/tema.tres")
	print("Tema generado: res://ui/tema.tres (", error_string(err), ")")
	quit()

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
