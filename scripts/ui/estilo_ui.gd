extends RefCounted
class_name EstiloUI
# ==========================================================
# AYUDAS DE INTERFAZ (el estilo general está en res://ui/tema.tres)
# ==========================================================

# Botones del HUD que usan un dibujo propio (pausa, construir, mochila...).
# Su dibujo está solo en el estado "normal"; aquí se copia a los demás
# estados para que no aparezca la caja del tema encima, y se les da
# respuesta al toque: se oscurecen y se achican un poco al presionarlos.
static func preparar_boton_icono(boton: Button) -> void:
	if not is_instance_valid(boton): return
	var normal := boton.get_theme_stylebox("normal")
	if normal is StyleBoxTexture:
		var presionado: StyleBoxTexture = normal.duplicate()
		presionado.modulate_color = Color(0.75, 0.75, 0.75)
		var deshabilitado: StyleBoxTexture = normal.duplicate()
		deshabilitado.modulate_color = Color(0.5, 0.5, 0.5, 0.7)
		boton.add_theme_stylebox_override("hover", normal)
		boton.add_theme_stylebox_override("pressed", presionado)
		boton.add_theme_stylebox_override("hover_pressed", presionado)
		boton.add_theme_stylebox_override("disabled", deshabilitado)
		boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	boton.focus_mode = Control.FOCUS_NONE
	agregar_rebote(boton)

# Pruebas: permite simular un teléfono en el PC o en modo consola.
static var tactil_forzado := false

static func es_tactil() -> bool:
	return tactil_forzado or DisplayServer.is_touchscreen_available()

# MULTITÁCTIL: los botones de Godot solo escuchan el "ratón" que el sistema
# inventa a partir del PRIMER dedo. Si ese dedo ya está en un joystick, un
# segundo dedo sobre "Recargar" o un arma no hacía nada. Aquí cada botón
# escucha los toques directamente, sea el dedo que sea.
static func hacer_multitactil(boton: BaseButton) -> void:
	if boton.has_meta("multitactil"): return
	boton.set_meta("multitactil", true)
	boton.gui_input.connect(func(evento: InputEvent):
		if not es_tactil(): return
		if evento is InputEventScreenTouch:
			if evento.pressed:
				if not boton.disabled:
					boton.button_down.emit()
					boton.pressed.emit()
			else:
				boton.button_up.emit()
			boton.accept_event()
		elif evento is InputEventMouseButton:
			# Ratón inventado del primer dedo: ya lo atendimos como toque.
			boton.accept_event())

# Pequeño "rebote" al tocar cualquier botón (se siente físico en táctil).
# También lo deja multitáctil.
static func agregar_rebote(boton: BaseButton) -> void:
	hacer_multitactil(boton)
	if boton.has_meta("con_rebote"): return
	boton.set_meta("con_rebote", true)
	boton.resized.connect(func(): boton.pivot_offset = boton.size / 2.0)
	boton.pivot_offset = boton.size / 2.0
	boton.button_down.connect(func():
		var t := boton.create_tween()
		t.tween_property(boton, "scale", Vector2(0.93, 0.93), 0.06))
	boton.button_up.connect(func():
		var t := boton.create_tween()
		t.tween_property(boton, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

# ==========================================================
# TEXTO FLOTANTE (lo que recogiste: "+$25", "+36 Ligera"...)
# ==========================================================
# Aparece sobre el personaje, sube y se desvanece en un segundo. Va dentro de
# un nodo "Efectos" para que el MultiplayerSpawner de Mundo no lo vea.
const FUENTE := preload("res://assets/fuentes/RussoOne.woff2")

static func texto_flotante(posicion: Vector3, texto: String, color: Color) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	var mundo := arbol.current_scene if arbol else null
	if not mundo: return
	var efectos := mundo.get_node_or_null("Efectos")
	if not efectos:
		efectos = Node3D.new()
		efectos.name = "Efectos"
		mundo.add_child(efectos)
	var l := Label3D.new()
	l.text = texto
	l.font = FUENTE
	l.font_size = 72
	l.pixel_size = 0.0075
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	# Si se recogen varias cosas juntas, cada texto sale más arriba (solo cuentan los textos vivos).
	var vivos := arbol.get_nodes_in_group("texto_flotante").size()
	l.add_to_group("texto_flotante")
	efectos.add_child(l)
	l.global_position = posicion + Vector3(0, 1.9 + 0.55 * mini(vivos, 4), 0)
	l.scale = Vector3.ONE * 0.4
	var pop := l.create_tween()
	pop.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(l, "scale", Vector3.ONE, 0.1)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 1.2, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	t.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.8)
	t.chain().tween_callback(l.queue_free)
