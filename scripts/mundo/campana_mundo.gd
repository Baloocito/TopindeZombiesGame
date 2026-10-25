extends Node
class_name CampanaMundo
# ==========================================================
# CAMPAÑA: títulos de cada noche, victoria y paso a Noches Eternas
# ==========================================================
# Hijo de Mundo con nombre fijo "Campana" (sus RPC necesitan la misma ruta
# en todas las pantallas).

var m: Node
var _panel: Control

func titulo_noche(n: int) -> String:
	var d := Balance.noche_campana(n)
	if Balance.es_noche_eterna(n):
		return "NOCHE ETERNA %d" % n
	return "NOCHE %d/%d · %s" % [n, Balance.noches_campana(), str(d.get("nombre", "")).to_upper()]

func lema_noche(n: int) -> String:
	return str(Balance.noche_campana(n).get("lema", ""))

# El servidor llama esto al terminar la noche 20.
func ganar_campana():
	if not multiplayer.is_server(): return
	m.get_node("GeneradorZombies/TimerSpawn").stop()
	victoria_en_red.rpc(m.zombies_asesinados_partida)

@rpc("authority", "call_local", "reliable")
func victoria_en_red(bajas: int):
	GuardadoGlobal.campanas_completadas += 1
	if Balance.noches_campana() > GuardadoGlobal.record_oleada:
		GuardadoGlobal.record_oleada = Balance.noches_campana()
	GuardadoGlobal.guardar_datos()
	# La campaña terminó: si salen al menú no hay noche 20 que continuar.
	if multiplayer.is_server(): GuardadoGlobal.borrar_partida()
	m.fase_combate = false
	m.cambiar_fase_ui(false)
	m.hud_dia_inferior.visible = false
	m.hud_dia_lateral.visible = false
	_mostrar_panel(bajas)

func _mostrar_panel(bajas: int):
	if is_instance_valid(_panel): _panel.queue_free()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.72)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var tarjeta := PanelContainer.new()
	tarjeta.theme_type_variation = "PanelVidrio"
	centro.add_child(tarjeta)
	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]: margen.add_theme_constant_override("margin_" + lado, 28)
	tarjeta.add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margen.add_child(col)
	var titulo := Label.new()
	titulo.theme_type_variation = "Titulo"
	titulo.text = "SOBREVIVISTE A LAS 20 NOCHES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color("#facc15"))
	col.add_child(titulo)
	var sub := Label.new()
	sub.text = "El Hospedero cayó. Pocos llegan hasta aquí.\nBajas de la partida: %d · Campañas completadas: %d" % [bajas, GuardadoGlobal.campanas_completadas]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 16)
	col.add_child(fila)
	if multiplayer.is_server():
		var seguir := Button.new()
		seguir.theme_type_variation = "BotonPrimario"
		seguir.text = "Seguir: Noches Eternas"
		seguir.custom_minimum_size = Vector2(260, 56)
		seguir.pressed.connect(func(): seguir_en_eternas())
		EstiloUI.agregar_rebote(seguir)
		fila.add_child(seguir)
	else:
		var espera := Label.new()
		espera.text = "El anfitrión decide si siguen en Noches Eternas…"
		fila.add_child(espera)
	var salir := Button.new()
	salir.text = "Volver al menú"
	salir.custom_minimum_size = Vector2(220, 56)
	salir.pressed.connect(_volver_al_menu)
	EstiloUI.agregar_rebote(salir)
	fila.add_child(salir)
	m.get_node("InterfazUI").add_child(fondo)
	_panel = fondo

func seguir_en_eternas():
	if not multiplayer.is_server(): return
	cerrar_panel_en_red.rpc()
	m.oleada_actual = Balance.noches_campana() + 1
	m.fase_preparacion_en_red.rpc(m.oleada_actual)

@rpc("authority", "call_local", "reliable")
func cerrar_panel_en_red():
	if is_instance_valid(_panel): _panel.queue_free()
	m.animar_fase("NOCHES ETERNAS", Color(1, 0.3, 0.3))

func _volver_al_menu():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")
