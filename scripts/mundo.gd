extends Node3D

# ==========================================================
# 1. ESTADOS DEL JUEGO Y REFERENCIAS PRINCIPALES
# ==========================================================
var modo_construccion: bool = false
var fase_combate: bool = false 
var oleada_actual: int = 1     
var zombies_vivos: int = 0     
@onready var menu_pausa = $MenuPausa # Ajusta la ruta si es necesario
@onready var texto_game_over = $InterfazUI/TextoGameOver
@onready var boton_reiniciar = $InterfazUI/BotonReiniciar
@onready var boton_iniciar = $InterfazUI/BotonIniciar 
@onready var texto_dinero = $InterfazUI/EsquinaDerecha/HBoxContainer/PanelDinero/HBoxContainer/LblDinero
@onready var boton_construir = $InterfazUI/EsquinaDerecha/HBoxContainer/CajaBotones/BotonConstruir
@onready var lbl_construir = $InterfazUI/EsquinaDerecha/HBoxContainer/CajaBotones/LblConstruir

@export var caja_municion_escena: PackedScene 
@export var botiquin_escena: PackedScene 
@export var moneda_escena: PackedScene

# --- NUEVAS REFERENCIAS UI ---
@onready var panel_fase = $InterfazUI/ContenedorAlertas/PanelFase
@onready var lbl_titulo_fase = $InterfazUI/ContenedorAlertas/PanelFase/VBoxContainer/LblTituloFase
@onready var lbl_zombies = $InterfazUI/ContenedorAlertas/PanelFase/VBoxContainer/CajaZombies/LblZombies
var zombies_asesinados_partida: int = 0

func _ready():
	holograma.visible = false
	
	panel_fase.visible = false
	fase_preparacion()

# ==========================================================
# 2. SISTEMA DE ECONOMÍA, PROGRESIÓN Y REPARACIÓN
# ==========================================================
var dinero_global: int = 10000
var reparaciones_usadas: int = 0 
var modificador_suerte: float = 0.0 


@onready var boton_reparar = $InterfazUI/BotonReparar 

func sumar_dinero(cantidad: int):
	dinero_global += cantidad
	texto_dinero.text = str(dinero_global) + "G"
	actualizar_boton_reparacion()

# ¡OPTIMIZADO! Función única para no repetir código al dar XP
func repartir_experiencia_global(cantidad: int):
	if cantidad <= 0: return
	var jugadores = get_tree().get_nodes_in_group("jugador")
	for jug in jugadores:
		if jug.has_method("ganar_experiencia"):
			jug.ganar_experiencia(cantidad)

func obtener_costo_reparacion() -> int:
	var costo_total = 0
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	
	for barricada in barricadas:
		if barricada.has_method("obtener_costo_reparacion"):
			var precio_mercado = obtener_precio_estructura("madera") # Por defecto
			if "tipo_estructura" in barricada and barricada.tipo_estructura != "":
				precio_mercado = obtener_precio_estructura(barricada.tipo_estructura)
			costo_total += barricada.obtener_costo_reparacion(precio_mercado)
			
	return costo_total
	
func actualizar_boton_reparacion():
	if not boton_reparar: return
	
	var costo = obtener_costo_reparacion()
	var usos_restantes = 1 - reparaciones_usadas 
	
	if costo == 0:
		boton_reparar.text = "Base Intacta"
		boton_reparar.disabled = true
	else:
		boton_reparar.text = "Reparar Todo ($" + str(costo)
		boton_reparar.disabled = (dinero_global < costo or usos_restantes <= 0)

func ejecutar_reparacion_global():
	var costo = obtener_costo_reparacion()
	if costo == 0 or dinero_global < costo or reparaciones_usadas >= 1: return
		
	sumar_dinero(-costo)
	reparaciones_usadas += 1
	
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for barricada in barricadas:
		if barricada.has_method("reparar_completamente"):
			barricada.reparar_completamente()
			
	actualizar_boton_reparacion()

func spawn_loot(pos_muerte: Vector3, tipo_zombie: String):
	var bounty: int = 0
	var oro_base: int = 0
	var prob_oro: float = 0.0
	var xp_ganada: int = 0 
	
	# 1. Ajuste de Estadísticas por Tipo
	match tipo_zombie:
		"basico":
			bounty = 10; oro_base = 25; prob_oro = 60.0; xp_ganada = 5 # Subimos prob_oro de 40 a 60
		"corredor":
			bounty = 15; oro_base = 45; prob_oro = 70.0; xp_ganada = 10
		"explosivo":
			bounty = 20; oro_base = 70; prob_oro = 80.0; xp_ganada = 20
		"tanque":
			bounty = 50; oro_base = 150; prob_oro = 100.0; xp_ganada = 50
		"boss":
			bounty = 500; oro_base = 2000; prob_oro = 100.0; xp_ganada = 1000
		
	sumar_dinero(bounty)
	repartir_experiencia_global(xp_ganada)
			
	# 2. Lógica de Loot de Ítems (Ajustada)
	var dado_loot = randf_range(1.0, 100.0) + modificador_suerte
	var solto_algo: bool = false
	
	# Rango 61-85: Munición (25% de probabilidad) - PRIORIDAD LIGERA
	if dado_loot >= 61.0 and dado_loot < 86.0:
		if caja_municion_escena:
			var caja = caja_municion_escena.instantiate()
			get_parent().add_child(caja) # Añadir al padre para que no se mueva con el zombie
			caja.global_position = pos_muerte + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			
			# Lógica inteligente para dar más munición ligera si el jugador la usa
			var jugadores = get_tree().get_nodes_in_group("jugador")
			if jugadores.size() > 0:
				var jugador = jugadores[0]
				if jugador.arma_actual:
					# Si usa SMG o Minigun, damos 3 cargadores en vez de 2
					var multiplicador = 3 if jugador.arma_actual.tipo_municion == "ligera" else 2
					var cantidad = jugador.arma_actual.tamano_cargador * multiplicador
					if caja.has_method("configurar"): 
						caja.configurar(jugador.arma_actual.tipo_municion, cantidad)
			solto_algo = true
			
	# Rango 86-95: Botiquines (10% de probabilidad)
	elif dado_loot >= 86.0 and dado_loot < 96.0:
		if botiquin_escena:
			var botiquin = botiquin_escena.instantiate()
			get_parent().add_child(botiquin)
			botiquin.global_position = pos_muerte + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			solto_algo = true
			
	# Rango 96+: Item Especial / Arma (5% de probabilidad)
	elif dado_loot >= 96.0:
		# Aquí iría tu lógica de soltar una pieza de arma o item raro
		solto_algo = true

	# Sistema de Pity (Suerte)
	modificador_suerte = 0.0 if solto_algo else modificador_suerte + 0.5

	# 3. Lógica de Oro Físico
	if randf_range(1.0, 100.0) <= prob_oro:
		var oro_final = int(oro_base * (1.0 + (0.15 * (oleada_actual - 1))))
		if moneda_escena:
			var moneda = moneda_escena.instantiate()
			get_parent().add_child(moneda)
			moneda.global_position = pos_muerte + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			moneda.valor_oro = oro_final
			
func generar_chatarra(posicion_destruccion: Vector3):
	if moneda_escena:
		var chatarra = moneda_escena.instantiate()
		add_child(chatarra)
		chatarra.global_position = posicion_destruccion
		chatarra.valor_oro = 20

# ==========================================================
# 3. LÓGICA DE OLEADAS Y ANIMACIONES
# ==========================================================
var tween_fase: Tween # ¡NUEVO! Controla la animación para poder interrumpirla si es necesario

func animar_fase(titulo: String, color_texto: Color):
	lbl_titulo_fase.text = titulo
	lbl_titulo_fase.modulate = color_texto
	
	# Aseguramos que el panel se vea y lo preparamos para la animación
	panel_fase.visible = true
	panel_fase.modulate.a = 0.0 # Totalmente transparente al inicio
	panel_fase.scale = Vector2(1.2, 1.2) # Un poco más grande para el efecto de impacto
	
	# Si había una animación anterior corriendo, la detenemos
	if tween_fase: tween_fase.kill()
	tween_fase = create_tween()
	
	# PASO 1: Aparecer rápidamente (Fade In + Rebote)
	tween_fase.tween_property(panel_fase, "modulate:a", 1.0, 0.4)
	tween_fase.parallel().tween_property(panel_fase, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE)
	
	# PASO 2: Mantenerse en pantalla por 4 segundos
	tween_fase.tween_interval(4.0)
	
	# PASO 3: Desvanecerse suavemente (Fade Out)
	tween_fase.tween_property(panel_fase, "modulate:a", 0.0, 0.5)
	
	# PASO 4: Apagar el nodo para que no estorbe (ahorra memoria)
	tween_fase.tween_callback(func(): panel_fase.visible = false)
	
func fase_preparacion():
	fase_combate = false
	modo_construccion = false
	holograma.visible = false
	
	boton_construir.text = "🔨" 
	lbl_construir.text = "Construcción"
	
	if oleada_actual > 1:
		var bono_supervivencia = 100 * (oleada_actual - 1)
		repartir_experiencia_global(bono_supervivencia)
	
	animar_fase("DÍA " + str(oleada_actual) + ": PREPÁRATE", Color.WHITE)
	
	boton_iniciar.visible = true
	boton_construir.visible = true
	reparaciones_usadas = 0 
	if boton_reparar:
		boton_reparar.visible = true
		actualizar_boton_reparacion()
		
func iniciar_oleada():
	fase_combate = true
	modo_construccion = false 
	holograma.visible = false
	cerrar_menu_lateral()
	
	# ¡NUEVO! Llamamos a la animación con color ROJO PELIGRO
	animar_fase("NOCHE ETERNA: OLEADA " + str(oleada_actual), Color(1, 0.2, 0.2))
	
	boton_iniciar.visible = false
	boton_construir.visible = false 
	if boton_reparar: boton_reparar.visible = false
	
	zombies_vivos = $GeneradorZombies.preparar_oleada(oleada_actual)
	$GeneradorZombies.iniciar_generacion()

func zombie_eliminado():
	GuardadoGlobal.zombies_totales += 1
	
	# ¡NUEVO! Actualizamos el marcador de calaveras
	zombies_asesinados_partida += 1
	lbl_zombies.text = str(zombies_asesinados_partida)
	
	zombies_vivos -= 1
	if zombies_vivos <= 0:
		oleada_actual += 1
		fase_preparacion()

func ejecutar_game_over():
	$GeneradorZombies/TimerSpawn.stop()
	if oleada_actual > GuardadoGlobal.record_oleada:
		GuardadoGlobal.record_oleada = oleada_actual
	GuardadoGlobal.guardar_datos()
	
	texto_game_over.visible = true
	boton_reiniciar.visible = true
	boton_iniciar.visible = false
	boton_construir.visible = false
	if boton_reparar: boton_reparar.visible = false

func _on_boton_reiniciar_pressed():
	get_tree().reload_current_scene()

# ==========================================================
# 4. SISTEMA DE TIENDA Y CONSTRUCCIÓN
# ==========================================================
var objeto_seleccionado_tienda: String = ""
var torreta_seleccionada: Node3D = null 

@export var escena_madera: PackedScene
@export var escena_puas: PackedScene
@export var escena_barril: PackedScene
@export var escena_acero: PackedScene
@export var escena_electrico: PackedScene
@export var escena_torreta: PackedScene

var datos_estructuras = {
	"madera": {"nombre": "Valla Madera", "precio": 150, "inflacion": 0.10, "hp": 500},
	"puas": {"nombre": "Alambre Púas", "precio": 300, "inflacion": 0.15, "hp": 300},
	"barril": {"nombre": "Barril Explosivo", "precio": 250, "inflacion": 0.0, "hp": 1},
	"acero": {"nombre": "Barrera Acero", "precio": 600, "inflacion": 0.20, "hp": 2000},
	"electrico": {"nombre": "Muro Eléctrico", "precio": 1000, "inflacion": 0.25, "hp": 1200},
	"torreta": {"nombre": "Base Torreta", "precio": 1500, "inflacion": 0.30, "hp": 800}
}

var construcciones_realizadas = {
	"madera": 0, "puas": 0, "barril": 0, "acero": 0, "electrico": 0, "torreta": 0
}


@onready var holograma = $Holograma
const TAMAÑO_GRILLA: float = 2.0 
var celdas_ocupadas: Dictionary = {}

func obtener_precio_estructura(clave_id: String) -> int:
	var datos = datos_estructuras[clave_id]
	var multiplicador_cantidad = 1.0 + (construcciones_realizadas[clave_id] * datos["inflacion"])
	var cantidad_jugadores = max(1, get_tree().get_nodes_in_group("jugador").size())
	var multiplicador_coop = 1.0 + ((cantidad_jugadores - 1) * 0.25)
	return int(datos["precio"] * multiplicador_cantidad * multiplicador_coop)

func alternar_modo_construccion():
	if fase_combate: return 
		
	if modo_construccion:
		modo_construccion = false 
		lbl_construir.text = "Tienda\nConstrucción" # <--- Cambiamos el Label de abajo
		boton_construir.modulate = Color.WHITE # Vuelve a su color normal
		holograma.visible = false
	else:
		abrir_menu_construccion()

func iniciar_colocacion_objeto(tipo_objeto: String):
	modo_construccion = true
	objeto_seleccionado_tienda = tipo_objeto 
	
	lbl_construir.text = "Cancelar\nConstrucción" # <--- Cambiamos el Label de abajo
	boton_construir.modulate = Color(1, 0.5, 0.5) # Lo teñimos de rojo para indicar que cancela
	
	holograma.visible = true

func construir_estructura():
	if objeto_seleccionado_tienda == "": return
	
	var costo_actual = obtener_precio_estructura(objeto_seleccionado_tienda)
	if dinero_global < costo_actual: return 
		
	var pos_llave = Vector3(snapped(holograma.global_position.x, 0.1), 1.0, snapped(holograma.global_position.z, 0.1))
	if celdas_ocupadas.has(pos_llave): return
	
	var escena_a_crear = null
	match objeto_seleccionado_tienda:
		"madera": escena_a_crear = escena_madera
		"puas": escena_a_crear = escena_puas
		"barril": escena_a_crear = escena_barril
		"acero": escena_a_crear = escena_acero
		"electrico": escena_a_crear = escena_electrico
		"torreta": escena_a_crear = escena_torreta
		
	if not escena_a_crear: return
		
	sumar_dinero(-costo_actual)
	construcciones_realizadas[objeto_seleccionado_tienda] += 1
		
	var nuevo_edificio = escena_a_crear.instantiate()
	if "tipo_estructura" in nuevo_edificio:
		nuevo_edificio.tipo_estructura = objeto_seleccionado_tienda
		
	add_child(nuevo_edificio)
	nuevo_edificio.global_position = holograma.global_position
	celdas_ocupadas[pos_llave] = true
	
	actualizar_boton_reparacion()
	# Si decides dejar el modo construcción continuo, no toques el lbl_construir aquí.
	# =========================================================
	# ¡NUEVO! APLICAMOS LA STAT DE INGENIERÍA
	# =========================================================
	var hp_oficial = datos_estructuras[objeto_seleccionado_tienda]["hp"]
	var multiplicador_ingenieria = 1.0
	
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if not jugadores.is_empty() and "stat_ingenieria" in jugadores[0]:
		multiplicador_ingenieria = jugadores[0].stat_ingenieria
		
	var hp_final = int(hp_oficial * multiplicador_ingenieria)
	
	if "salud_maxima" in nuevo_edificio:
		nuevo_edificio.salud_maxima = hp_final
		nuevo_edificio.salud_actual = hp_final
	
	actualizar_boton_reparacion()
	


func _process(_delta):
	if not modo_construccion or fase_combate: return
		
	var camara = get_viewport().get_camera_3d()
	if not camara: return
		
	var pos_pantalla = get_viewport().get_mouse_position()
	var origen_rayo = camara.project_ray_origin(pos_pantalla)
	var direccion_rayo = camara.project_ray_normal(pos_pantalla)
	var punto_interseccion = Plane(Vector3.UP, 0).intersects_ray(origen_rayo, direccion_rayo)
	
	if punto_interseccion != null:
		holograma.global_position = Vector3(snapped(punto_interseccion.x, TAMAÑO_GRILLA), 1.0, snapped(punto_interseccion.z, TAMAÑO_GRILLA))
		
		# ¡OPTIMIZADO! Evitamos calcular el precio si no hemos elegido nada en la tienda
		if objeto_seleccionado_tienda != "" and datos_estructuras.has(objeto_seleccionado_tienda):
			var costo_actual = obtener_precio_estructura(objeto_seleccionado_tienda) 
			holograma.material_override.albedo_color = Color(0, 1, 0, 0.5) if dinero_global >= costo_actual else Color(1, 0, 0, 0.5)

func _unhandled_input(event):
	if not modo_construccion or fase_combate: return
		
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		construir_estructura()


# ==========================================================
# 5. MENÚS LATERALES (ARMERÍA, TIENDA E INSPECTOR)
# ==========================================================
# El panel principal y el botón de cerrar siguen en la misma ruta
@onready var panel_lateral = $InterfazUI/PanelLateral
@onready var boton_cerrar_panel = $InterfazUI/PanelLateral/BotonCerrar

# ¡AQUÍ ESTÁ LA NUEVA RUTA LARGA! (Atravesando el Margen, el Scroll y el VBoxContainer)
@onready var menu_armeria = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuArmeria
@onready var menu_construccion = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuConstruccion
@onready var menu_inspector = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuInspector
@onready var menu_nivel = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuNivel

func _on_boton_cambiar_arma_pressed() -> void:
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if not jugadores.is_empty(): jugadores[0].ciclo_arma_rapido()

func _on_boton_cerrar_pressed() -> void: cerrar_menu_lateral()
func _on_boton_mochila_pressed() -> void: abrir_armeria()

func cerrar_menu_lateral():
	if panel_lateral: panel_lateral.visible = false

func abrir_armeria():
	if fase_combate: return
	panel_lateral.visible = true
	menu_armeria.visible = true
	menu_construccion.visible = false
	menu_inspector.visible = false
	menu_nivel.visible = false
	actualizar_lista_armeria()
	
func actualizar_lista_armeria():
	for hijo in menu_armeria.get_children(): hijo.queue_free()
		
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.is_empty(): return
	var jugador = jugadores[0]
	
	# --- 1. TÍTULO PROFESIONAL ---
	var titulo = Label.new()
	titulo.text = "ARMARIO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24) # Letra más grande
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Color Amarillo/Oro
	menu_armeria.add_child(titulo)
	
	# --- 2. LÍNEA SEPARADORA ---
	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15) # Espacio extra
	menu_armeria.add_child(separador)
	
	# --- 3. LISTA DE ARMAS ---
	for arma in jugador.armas_inventario:
		var fila = HBoxContainer.new() 
		
		var lbl_nombre = Label.new()
		lbl_nombre.text = "  " + arma.nombre # Un pequeño espacio al inicio para que no se pegue al borde
		lbl_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_nombre.add_theme_font_size_override("font_size", 18) # Tamaño legible
		fila.add_child(lbl_nombre)
		
		# Contenedor para los botones de slot para que queden agrupados
		var caja_slots = HBoxContainer.new()
		
		for i in range(3):
			var btn_slot = Button.new()
			btn_slot.text = str(i + 1) 
			btn_slot.custom_minimum_size = Vector2(45, 45) # Botones cuadrados perfectos para celular
			
			# Destacar el slot si ya tiene ESTA arma equipada
			if jugador.armas_equipadas[i] == arma:
				btn_slot.modulate = Color(0.2, 1, 0.2) # Verde brillante
			
			btn_slot.pressed.connect(func():
				jugador.equipar_en_slot(arma, i)
				if jugador.slot_actual == i: jugador.cambiar_arma(i)
				actualizar_lista_armeria() # Recargamos para ver el color verde actualizarse
			)
			caja_slots.add_child(btn_slot)
			
		fila.add_child(caja_slots)
		menu_armeria.add_child(fila)
		
		# Pequeño espacio entre cada fila de armas
		var espacio = Control.new()
		espacio.custom_minimum_size = Vector2(0, 10)
		menu_armeria.add_child(espacio)

func abrir_menu_construccion():
	panel_lateral.visible = true
	menu_armeria.visible = false
	menu_construccion.visible = true 
	menu_inspector.visible = false
	menu_nivel.visible = false
	actualizar_lista_construccion()
	
func actualizar_lista_construccion():
	for hijo in menu_construccion.get_children(): hijo.queue_free()
		
	var titulo = Label.new()
	titulo.text = "--- INGENIERÍA ---"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	menu_construccion.add_child(titulo)
	
	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15)
	menu_construccion.add_child(separador)
	
	for clave in datos_estructuras.keys():
		var datos = datos_estructuras[clave]
		var costo_actual = obtener_precio_estructura(clave)
		var btn = Button.new()
		
		btn.text = datos["nombre"] + " ($" + str(costo_actual) + ") | HP: " + str(datos["hp"])
		btn.custom_minimum_size = Vector2(0, 60) 
		# ¡LA MAGIA! Obligamos al botón a estirarse a todo lo ancho
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		if dinero_global < costo_actual:
			btn.disabled = true
			btn.modulate = Color(1, 0.5, 0.5)
			
		btn.pressed.connect(func():
			iniciar_colocacion_objeto(clave)
			cerrar_menu_lateral()
		)
		menu_construccion.add_child(btn)

func abrir_menu_inspector(torreta_tocada: Node3D):
	if fase_combate: return
	torreta_seleccionada = torreta_tocada
	panel_lateral.visible = true
	menu_armeria.visible = false
	menu_construccion.visible = false
	menu_inspector.visible = true 
	menu_nivel.visible = false
	actualizar_lista_inspector()

func actualizar_lista_inspector():
	# 1. LIMPIEZA Y VALIDACIÓN
	for hijo in menu_inspector.get_children(): 
		hijo.queue_free()
		
	if not is_instance_valid(torreta_seleccionada):
		cerrar_menu_lateral()
		return
		
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.is_empty(): return
	var jugador = jugadores[0]
	
	# 2. ENCABEZADO Y ESTADO GENERAL
	var titulo = Label.new()
	titulo.text = "--- CENTINELA ---"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_inspector.add_child(titulo)
	
	var lbl_estado = Label.new()
	var nombre_arma = torreta_seleccionada.arma_equipada.nombre if torreta_seleccionada.arma_equipada else "Ninguna"
	lbl_estado.text = "Salud: %s\nArma: %s\nBalas: %s" % [torreta_seleccionada.salud_actual, nombre_arma, torreta_seleccionada.balas_cargadas]
	menu_inspector.add_child(lbl_estado)
	
	# ==========================================
	# 3. SECCIÓN DE MUNICIÓN
	# ==========================================
	if torreta_seleccionada.arma_equipada != null:
		var tipo_municion = torreta_seleccionada.arma_equipada.tipo_municion
		var reserva_jugador = jugador.municion_reserva.get(tipo_municion, 0)
		
		var btn_recargar = Button.new()
		btn_recargar.text = "Dar 30 Balas %s\n(Tu reserva: %s)" % [tipo_municion, reserva_jugador]
		btn_recargar.custom_minimum_size = Vector2(0, 50)
		
		# Bloqueamos el botón si no te alcanzan las balas
		if reserva_jugador < 30: 
			btn_recargar.disabled = true
			
		btn_recargar.pressed.connect(func():
			jugador.municion_reserva[tipo_municion] -= 30
			torreta_seleccionada.balas_cargadas += 30
			jugador.actualizar_ui_municion()
			actualizar_lista_inspector() 
		)
		menu_inspector.add_child(btn_recargar)
	else:
		# Si no hay arma, mostramos un aviso en gris
		var lbl_aviso = Label.new()
		lbl_aviso.text = "\n[Instala un arma para cargar balas]"
		lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_aviso.modulate = Color(0.7, 0.7, 0.7) 
		menu_inspector.add_child(lbl_aviso)
	
	# ==========================================
	# 4. SECCIÓN DE INSTALAR/DESINSTALAR ARMAS
	# ==========================================
	var subtitulo_armas = Label.new()
	subtitulo_armas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_inspector.add_child(subtitulo_armas)
	
	if torreta_seleccionada.arma_equipada == null:
		subtitulo_armas.text = "\n-- INSTALAR ARMA --"
		for arma in jugador.armas_inventario:
			var btn_arma = Button.new()
			btn_arma.text = "Instalar " + arma.nombre
			btn_arma.custom_minimum_size = Vector2(0, 40)
			
			btn_arma.pressed.connect(func():
				# A. Le damos el arma a la torreta y la borramos del inventario
				torreta_seleccionada.arma_equipada = arma
				jugador.armas_inventario.erase(arma)
				
				# B. Buscamos si estaba equipada en la barra rápida y la sacamos
				for i in range(3):
					if jugador.armas_equipadas[i] == arma:
						jugador.armas_equipadas[i] = null
						
						# C. ¡EL EXORCISMO! Si la tenía en la mano físicamente
						if jugador.slot_actual == i:
							jugador.arma_actual = null 
							jugador.actualizar_ui_municion() 
							jugador.ciclo_arma_rapido() 
							
				actualizar_lista_inspector()
			)
			menu_inspector.add_child(btn_arma)
	else:
		subtitulo_armas.text = "\n-- RECUPERAR ARMA --"
		var btn_recuperar = Button.new()
		btn_recuperar.text = "Desinstalar " + torreta_seleccionada.arma_equipada.nombre
		btn_recuperar.custom_minimum_size = Vector2(0, 40)
		
		btn_recuperar.pressed.connect(func():
			# A. Recuperamos las balas sobrantes primero
			if torreta_seleccionada.balas_cargadas > 0:
				var tipo_bala = torreta_seleccionada.arma_equipada.tipo_municion
				jugador.municion_reserva[tipo_bala] += torreta_seleccionada.balas_cargadas
				torreta_seleccionada.balas_cargadas = 0
				jugador.actualizar_ui_municion()
			
			# B. Devolvemos el arma al inventario del jugador
			jugador.armas_inventario.append(torreta_seleccionada.arma_equipada)
			torreta_seleccionada.arma_equipada = null
			
			actualizar_lista_inspector()
		)
		menu_inspector.add_child(btn_recuperar)
# --- CARA D: MENÚ DE NIVEL Y ATRIBUTOS ---
func abrir_menu_nivel():
	panel_lateral.visible = true
	menu_armeria.visible = false
	menu_construccion.visible = false
	menu_inspector.visible = false
	menu_nivel.visible = true # ¡Encendemos el menú de RPG!
	
	actualizar_lista_nivel()

func actualizar_lista_nivel():
	for hijo in menu_nivel.get_children(): 
		hijo.queue_free()
		
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.is_empty(): return
	var jugador = jugadores[0]
	
	# 1. Título y Puntos Disponibles
	var titulo = Label.new()
	titulo.text = "--- ATRIBUTOS (Nivel " + str(jugador.nivel) + ") ---"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_nivel.add_child(titulo)
	
	var lbl_puntos = Label.new()
	lbl_puntos.text = "Puntos para gastar: " + str(jugador.puntos_mejora)
	lbl_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if jugador.puntos_mejora > 0:
		lbl_puntos.modulate = Color(1, 1, 0) # Lo pintamos de amarillo brillante si hay puntos
	menu_nivel.add_child(lbl_puntos)
	
	# 2. Diccionario de Estadísticas Actuales
	var stats_ui = [
		{"id": "salud", "nombre": "Salud Máxima", "valor": str(jugador.stat_salud_maxima) + " HP"},
		{"id": "agilidad", "nombre": "Agilidad", "valor": str(jugador.stat_agilidad).pad_decimals(1) + " m/s"},
		{"id": "destreza", "nombre": "Destreza", "valor": str(int(jugador.stat_destreza * 100)) + "%"},
		{"id": "ingenieria", "nombre": "Ingeniería", "valor": "x" + str(jugador.stat_ingenieria).pad_decimals(1)},
		{"id": "recoleccion", "nombre": "Imán de Oro", "valor": str(jugador.stat_recoleccion).pad_decimals(1) + " m"}
	]
	
	# 3. Dibujamos cada fila (Texto a la izquierda, Botón '+' a la derecha)
	for stat in stats_ui:
		var fila = HBoxContainer.new()
		
		var lbl_stat = Label.new()
		lbl_stat.text = stat["nombre"] + "\nActual: " + stat["valor"]
		lbl_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(lbl_stat)
		
		var btn_mejorar = Button.new()
		btn_mejorar.text = " + "
		btn_mejorar.custom_minimum_size = Vector2(50, 50) # Botón cuadrado y táctil
		
		# Si no hay puntos, el botón se bloquea
		if jugador.puntos_mejora <= 0:
			btn_mejorar.disabled = true
			
		# Al presionar el +, llamamos a la función RPG del jugador
		btn_mejorar.pressed.connect(func():
			jugador.mejorar_estadistica(stat["id"])
			actualizar_lista_nivel() # Recargamos el menú para ver el cambio en vivo
		)
		
		fila.add_child(btn_mejorar)
		menu_nivel.add_child(fila)


func _on_boton_nivel_pressed() -> void:
	abrir_menu_nivel() # ¡Reemplazamos el 'pass' por esto!


func _on_boton_pausa_pressed() -> void:
	if menu_pausa:
		menu_pausa.alternar_pausa()
		
func _on_boton_construir_pressed():
	
	alternar_modo_construccion()
