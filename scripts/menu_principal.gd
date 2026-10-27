extends Control

@onready var texto_proximamente = $TextoProximamente

func _ready():
	# Nos aseguramos de que el texto de aviso esté invisible al inicio
	texto_proximamente.modulate.a = 0.0
	texto_proximamente.visible = false
	for b in $VBoxContainer.get_children():
		if b is BaseButton: EstiloUI.agregar_rebote(b)
	# Con mando el foco arranca en "Jugar" (sin foco, el mando no hace nada).
	Controles.enfocar_en($VBoxContainer, true)

var _opciones: CanvasLayer

# B / Esc cierra Opciones.
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_opciones):
		get_viewport().set_input_as_handled()
		_cerrar_opciones()

func _cerrar_opciones():
	if is_instance_valid(_opciones): _opciones.queue_free()
	Controles.enfocar_en($VBoxContainer, true)

# ==========================================
# SEÑALES DE LOS BOTONES
# ==========================================

func _on_boton_jugar_pressed():
	# ¡Ahora pasamos a la sala de espera multijugador primero!
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn") 
	# OJO: Asegúrate de que la ruta "res://Lobby.tscn" coincida exactamente con donde tienes guardada tu escena del Lobby.

func _on_boton_ranking_pressed():
	# Leemos directamente la variable de nuestro Singleton
	var record_dia = GuardadoGlobal.record_oleada
	var total_muertes = GuardadoGlobal.zombies_totales
	
	var texto_estadisticas = "TUS RÉCORDS:\n\nMejor Día: %s\nZombies Eliminados: %s" % [record_dia, total_muertes]
	
	mostrar_aviso(texto_estadisticas)
func _on_boton_opciones_pressed():
	_abrir_opciones()

# Opciones: controles y estilo retro (lo mismo que en Pausa > Opciones).
func _abrir_opciones():
	var capa := CanvasLayer.new()
	capa.layer = 40
	add_child(capa)
	_opciones = capa
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var tarjeta := PanelContainer.new()
	tarjeta.theme_type_variation = "PanelVidrio"
	centro.add_child(tarjeta)
	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]: margen.add_theme_constant_override("margin_" + lado, 24)
	tarjeta.add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margen.add_child(col)
	var t := Label.new()
	t.theme_type_variation = "Titulo"
	t.text = "OPCIONES"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var ps1 := CheckButton.new()
	ps1.text = "Estilo retro PS1"
	ps1.button_pressed = PS1.activo
	ps1.toggled.connect(func(v): PS1.alternar(v))
	col.add_child(ps1)
	col.add_child(EstiloUI.selector_zoom())
	var controles := Button.new()
	controles.text = "Controles"
	controles.custom_minimum_size = Vector2(280, 54)
	controles.pressed.connect(func(): MenuControles.abrir(self))
	col.add_child(controles)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.theme_type_variation = "BotonPrimario"
	cerrar.custom_minimum_size = Vector2(280, 54)
	cerrar.pressed.connect(_cerrar_opciones)
	col.add_child(cerrar)
	for b in [controles, cerrar]: EstiloUI.agregar_rebote(b)
	controles.grab_focus.call_deferred()

func _on_boton_salir_pressed():
	# Cierra la aplicación/juego
	get_tree().quit()

# ==========================================
# ANIMACIÓN DEL "PRÓXIMAMENTE"
# ==========================================
func mostrar_aviso(modulo: String):
	texto_proximamente.text = modulo + "\n¡Próximamente!"
	texto_proximamente.visible = true
	
	# Reiniciamos la transparencia por si se toca muchas veces rápido
	texto_proximamente.modulate.a = 1.0 
	
	var tween = create_tween()
	# Espera 1 segundo y luego se desvanece en 0.5 segundos
	tween.tween_interval(1.0)
	tween.tween_property(texto_proximamente, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): texto_proximamente.visible = false)
