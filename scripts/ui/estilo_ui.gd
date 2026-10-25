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

# Pequeño "rebote" al tocar cualquier botón (se siente físico en táctil).
static func agregar_rebote(boton: BaseButton) -> void:
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
