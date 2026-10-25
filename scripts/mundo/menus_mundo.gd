extends Node
class_name MenusMundo
# ==========================================================
# MENÚS DEL PANEL LATERAL (Armería, Construcción, Torreta, Nivel, Mesa)
# ==========================================================
# Separado de mundo.gd. Solo arma la interfaz de ESTE jugador; todo lo que
# cuesta oro o cambia algo del equipo se le pide al servidor a través de
# mundo.gd (nunca se modifica el dinero o los planos aquí directamente).

var m: Node  # el nodo Mundo (se asigna en mundo.gd al crear este nodo)
var arma_inspeccionada: ArmaData = null

func _titulo(contenedor: Control, texto: String):
	var titulo = Label.new()
	titulo.text = texto
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	contenedor.add_child(titulo)
	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15)
	contenedor.add_child(separador)

func _limpiar(contenedor: Control):
	for hijo in contenedor.get_children(): hijo.queue_free()

func _espacio(contenedor: Control, alto: int):
	var espacio = Control.new()
	espacio.custom_minimum_size = Vector2(0, alto)
	contenedor.add_child(espacio)

# ----------------------------------------------------------
# ARMERÍA (inventario y slots)
# ----------------------------------------------------------
func actualizar_lista_armeria():
	var menu: Control = m.menu_armeria
	_limpiar(menu)
	var jugador = m.obtener_jugador_local()
	if not jugador: return
	_titulo(menu, "ARMARIO TÁCTICO")

	for arma in jugador.armas_inventario:
		var fila = HBoxContainer.new()
		var btn_nombre = Button.new()
		btn_nombre.text = ("▼ " if arma_inspeccionada == arma else "▶ ") + arma.nombre
		btn_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_nombre.add_theme_font_size_override("font_size", 18)
		btn_nombre.pressed.connect(func():
			arma_inspeccionada = null if arma_inspeccionada == arma else arma
			actualizar_lista_armeria()
		)
		fila.add_child(btn_nombre)

		var caja_slots = HBoxContainer.new()
		for i in range(3):
			var btn_slot = Button.new()
			btn_slot.text = str(i + 1)
			btn_slot.custom_minimum_size = Vector2(45, 45)
			if jugador.armas_equipadas[i] == arma:
				btn_slot.modulate = Color(0.2, 1, 0.2)
			btn_slot.pressed.connect(func():
				jugador.equipar_en_slot(arma, i)
				if jugador.slot_actual == i: jugador.cambiar_arma(i)
				actualizar_lista_armeria()
			)
			caja_slots.add_child(btn_slot)
		fila.add_child(caja_slots)
		menu.add_child(fila)

		if arma_inspeccionada == arma:
			var lbl_datos = Label.new()
			lbl_datos.text = "Daño: %d\nCadencia: %.1f bps\nCargador: %d balas\nRecarga: %.2f s\nMunición: %s" % [arma.dano, arma.cadencia, arma.tamano_cargador, arma.tiempo_recarga, arma.tipo_municion]
			lbl_datos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_datos.modulate = Color(0.7, 1.0, 1.0)
			menu.add_child(lbl_datos)
		_espacio(menu, 10)

# ----------------------------------------------------------
# CONSTRUCCIÓN
# ----------------------------------------------------------
func actualizar_lista_construccion():
	var menu: Control = m.menu_construccion
	_limpiar(menu)
	_titulo(menu, "--- INGENIERÍA ---")
	for clave in Balance.estructuras.keys():
		var datos: Dictionary = Balance.estructura(clave)
		var costo_actual: int = m.obtener_precio_estructura(clave)
		var btn = Button.new()
		btn.text = "%s ($%d) | HP: %d" % [datos["nombre"], costo_actual, int(datos["hp"])]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if m.dinero_global < costo_actual:
			btn.disabled = true
			btn.modulate = Color(1, 0.5, 0.5)
		btn.pressed.connect(func():
			m.iniciar_colocacion_objeto(clave)
			m.cerrar_menu_lateral()
		)
		menu.add_child(btn)

# ----------------------------------------------------------
# INSPECTOR DE TORRETA
# ----------------------------------------------------------
func actualizar_lista_inspector():
	var menu: Control = m.menu_inspector
	_limpiar(menu)
	var torreta = m.torreta_seleccionada
	if not is_instance_valid(torreta):
		m.cerrar_menu_lateral()
		return
	var jugador = m.obtener_jugador_local()
	if not jugador: return
	_titulo(menu, "CENTINELA")

	var nombre_arma = torreta.arma_equipada.nombre if torreta.arma_equipada else "Ninguna"
	var lbl_estado = Label.new()
	lbl_estado.text = "Salud: %s\nArma: %s\nBalas: %s" % [torreta.salud_actual, nombre_arma, torreta.balas_cargadas]
	lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(lbl_estado)

	if torreta.arma_equipada != null:
		var tipo_municion: String = torreta.arma_equipada.tipo_municion
		var reserva: int = jugador.municion_reserva.get(tipo_municion, 0)
		var btn_recargar = Button.new()
		btn_recargar.text = "Dar 30 Balas %s\n(Tu reserva: %s)" % [tipo_municion, reserva]
		btn_recargar.custom_minimum_size = Vector2(0, 50)
		btn_recargar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_recargar.disabled = reserva < 30
		btn_recargar.pressed.connect(func():
			jugador.municion_reserva[tipo_municion] -= 30
			torreta.agregar_balas_en_red.rpc_id(1, 30)
			jugador.actualizar_ui_municion()
			_refrescar_inspector_pronto()
		)
		menu.add_child(btn_recargar)

		var btn_recuperar = Button.new()
		btn_recuperar.text = "Desinstalar " + torreta.arma_equipada.nombre
		btn_recuperar.custom_minimum_size = Vector2(0, 40)
		btn_recuperar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_recuperar.pressed.connect(func():
			var arma_devuelta: ArmaData = torreta.arma_equipada
			if torreta.balas_cargadas > 0:
				jugador.municion_reserva[arma_devuelta.tipo_municion] += torreta.balas_cargadas
				jugador.actualizar_ui_municion()
			if arma_devuelta.id != Balance.progresion["arma_inicial"]:
				jugador.armas_inventario.append(arma_devuelta)
			torreta.instalar_arma_en_red.rpc({})
			_refrescar_inspector_pronto()
		)
		menu.add_child(btn_recuperar)
	else:
		var lbl_aviso = Label.new()
		lbl_aviso.text = "\n-- INSTALAR ARMA --"
		lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(lbl_aviso)
		for arma in jugador.armas_inventario:
			var btn_arma = Button.new()
			btn_arma.text = "Instalar " + arma.nombre
			btn_arma.custom_minimum_size = Vector2(0, 40)
			btn_arma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_arma.pressed.connect(func():
				torreta.instalar_arma_en_red.rpc(arma.a_diccionario())
				# El arma inicial se copia; las demás pasan a la torreta.
				if arma.id != Balance.progresion["arma_inicial"]:
					_quitar_arma_del_jugador(jugador, arma)
				_refrescar_inspector_pronto()
			)
			menu.add_child(btn_arma)

func _quitar_arma_del_jugador(jugador, arma: ArmaData):
	jugador.armas_inventario.erase(arma)
	for i in range(3):
		if jugador.armas_equipadas[i] == arma:
			jugador.armas_equipadas[i] = null
			if jugador.slot_actual == i:
				jugador.arma_actual = null
				jugador.ciclo_arma_rapido()
	jugador.actualizar_ui_municion()

# Las balas de la torreta las cuenta el servidor y llegan por el
# sincronizador; esperamos un instante antes de redibujar.
func _refrescar_inspector_pronto():
	await get_tree().create_timer(0.2).timeout
	if m.menu_inspector.visible:
		actualizar_lista_inspector()

# ----------------------------------------------------------
# NIVEL Y ATRIBUTOS
# ----------------------------------------------------------
func actualizar_lista_nivel():
	var menu: Control = m.menu_nivel
	_limpiar(menu)
	var jugador = m.obtener_jugador_local()
	if not jugador: return
	_titulo(menu, "ATRIBUTOS")

	var lbl_puntos = Label.new()
	lbl_puntos.text = "Puntos Disponibles: " + str(jugador.puntos_mejora)
	lbl_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if jugador.puntos_mejora > 0: lbl_puntos.modulate = Color(1, 1, 0)
	menu.add_child(lbl_puntos)

	var stats_ui = [
		{"id": "salud", "nombre": "Salud Máxima", "valor": str(jugador.stat_salud_maxima) + " HP"},
		{"id": "agilidad", "nombre": "Agilidad", "valor": str(jugador.stat_agilidad).pad_decimals(1) + " m/s"},
		{"id": "destreza", "nombre": "Destreza", "valor": str(int(round(jugador.stat_destreza * 100))) + "%"},
		{"id": "ingenieria", "nombre": "Ingeniería", "valor": "x" + str(jugador.stat_ingenieria).pad_decimals(1)},
		{"id": "recoleccion", "nombre": "Imán de Oro", "valor": str(jugador.stat_recoleccion).pad_decimals(1) + " m"}
	]
	for stat in stats_ui:
		var fila = HBoxContainer.new()
		fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl_stat = Label.new()
		var en_tope: bool = jugador.stat_en_tope(stat["id"])
		lbl_stat.text = stat["nombre"] + "\n" + stat["valor"] + ("  (MÁX)" if en_tope else "")
		lbl_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(lbl_stat)
		var btn_mejorar = Button.new()
		btn_mejorar.text = " + "
		btn_mejorar.custom_minimum_size = Vector2(50, 50)
		btn_mejorar.disabled = jugador.puntos_mejora <= 0 or en_tope
		btn_mejorar.pressed.connect(func():
			jugador.mejorar_estadistica(stat["id"])
			actualizar_lista_nivel()
		)
		fila.add_child(btn_mejorar)
		menu.add_child(fila)
		_espacio(menu, 5)

# ----------------------------------------------------------
# MESA DE TRABAJO (ensamblar y mejorar con planos)
# ----------------------------------------------------------
func actualizar_lista_ensamblaje():
	var menu: Control = m.menu_ensamblaje
	_limpiar(menu)
	var jugador = m.obtener_jugador_local()
	if not jugador: return
	_titulo(menu, "MESA DE TRABAJO")

	if m.planos_desbloqueados.is_empty():
		var lbl_vacio = Label.new()
		lbl_vacio.text = "No tienes planos.\n¡Explora y caza Jefes!"
		lbl_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_vacio.modulate = Color(0.7, 0.7, 0.7)
		menu.add_child(lbl_vacio)
		return

	var conteo_planos = {}
	for p in m.planos_desbloqueados:
		conteo_planos[p] = conteo_planos.get(p, 0) + 1

	for clave in conteo_planos.keys():
		var datos := Balance.arma(clave)
		if datos.is_empty(): continue
		var costo_ensamblar := int(datos["costo_ensamblaje"])
		var costo_mejorar: int = m.costo_mejora_arma(clave)
		var arma_poseida = m.arma_del_jugador(jugador, clave)

		var lbl_info = Label.new()
		var texto_info = "► %s (x%d Planos)\n" % [datos["nombre"], conteo_planos[clave]]
		if arma_poseida:
			texto_info += "Nivel: %d | Daño: %d" % [m.nivel_armas.get(clave, 1), arma_poseida.dano]
		else:
			texto_info += "Estado: No Ensamblada"
		lbl_info.text = texto_info
		menu.add_child(lbl_info)

		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 50)
		if not arma_poseida:
			btn.text = "Ensamblar\n$" + str(costo_ensamblar)
			btn.modulate = Color(0.5, 1.0, 0.5)
			btn.disabled = m.dinero_global < costo_ensamblar
			btn.pressed.connect(func(): m.pedir_ensamblar(clave))
		else:
			btn.text = "Forjar Mejora Aleatoria\n$" + str(costo_mejorar)
			btn.modulate = Color(0.4, 0.8, 1.0)
			btn.disabled = m.dinero_global < costo_mejorar
			btn.pressed.connect(func(): m.pedir_mejora(clave))
		menu.add_child(btn)
		_espacio(menu, 15)
