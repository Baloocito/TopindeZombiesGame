extends Control

# Puerto de red
const MAX_CLIENTS = 4  # tope duro de conexiones ENet (host + hasta 3 más)

var peer = ENetMultiplayerPeer.new()

# Diccionario de jugadores en la sala: id_red -> nombre
var jugadores_conectados = {}

# ==========================================================
# NUEVO: sala con cupo fijo + contraseña opcional
# ==========================================================
# Decisión de esta iteración: sin servidor de matchmaking todavía, así que
# "pública" de verdad (aparecer en una lista sin compartir nada) no es
# posible -- necesitaría un servidor intermedio que liste salas abiertas.
# Por ahora TODA sala es "privada por invitación": el host comparte su IP
# (y una contraseña, si puso una) por fuera del juego, igual que antes.
# Lo que sí agregamos: el host elige cuántos jugadores quiere en total, y
# "Iniciar Partida" queda oculto hasta llenar ese número. Esto elimina por
# completo el caso de "alguien entra después de que la horda ya arrancó",
# que era la fuente de casi todos los bugs de sincronización tardía.
var cantidad_deseada: int = 1  # 1 = jugar solo (el host sin invitados)
var contrasena_sala: String = ""
var soy_host: bool = false
var sala_bloqueada: bool = false  # true apenas arranca la partida

# Referencias a tus nodos originales
@onready var btn_host = $VBoxContainer/BtnHost
@onready var btn_unirse = $VBoxContainer/BtnUnirse
@onready var input_ip = $VBoxContainer/InputIP
@onready var lista_jugadores = $VBoxContainer/ListaJugadores
@onready var boton_iniciar = $VBoxContainer/BotonIniciarJuego

# Controles nuevos -- se crean solos en _crear_controles_nuevos(), no hace
# falta tocar la escena Lobby.tscn en el editor.
var fila_cantidad: HBoxContainer
var spin_cantidad: SpinBox
var input_contrasena_crear: LineEdit
var input_contrasena_unirse: LineEdit
var label_estado_sala: Label
var boton_volver: Button
var boton_continuar: Button
var _continuando: bool = false

func _ready():
	boton_iniciar.hide()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_conectado_al_servidor)
	multiplayer.connection_failed.connect(_on_falla_de_conexion)

	_crear_controles_nuevos()
	_aplicar_estilo()

func _crear_controles_nuevos():
	var vbox = $VBoxContainer

	# --- Cuántos jugadores quiere el host en total (incluyéndose) ---
	fila_cantidad = HBoxContainer.new()
	var label_cantidad = Label.new()
	label_cantidad.text = "Jugadores en la sala: "
	spin_cantidad = SpinBox.new()
	spin_cantidad.min_value = 1
	spin_cantidad.max_value = MAX_CLIENTS
	spin_cantidad.value = cantidad_deseada
	spin_cantidad.value_changed.connect(func(v):
		cantidad_deseada = int(v)
		_actualizar_texto_boton_host())
	fila_cantidad.add_child(label_cantidad)
	fila_cantidad.add_child(spin_cantidad)
	vbox.add_child(fila_cantidad)
	vbox.move_child(fila_cantidad, btn_host.get_index())

	# --- Contraseña opcional al crear sala ---
	input_contrasena_crear = LineEdit.new()
	input_contrasena_crear.placeholder_text = "Contraseña (opcional)"
	input_contrasena_crear.secret = true
	vbox.add_child(input_contrasena_crear)
	vbox.move_child(input_contrasena_crear, btn_host.get_index())

	# --- Contraseña al unirse (solo hace falta si la sala tiene una) ---
	input_contrasena_unirse = LineEdit.new()
	input_contrasena_unirse.placeholder_text = "Contraseña (si la sala tiene)"
	input_contrasena_unirse.secret = true
	vbox.add_child(input_contrasena_unirse)
	vbox.move_child(input_contrasena_unirse, input_ip.get_index() + 1)

	# --- "Sala: 2/4 jugadores" / mensajes de rechazo ---
	label_estado_sala = Label.new()
	label_estado_sala.hide()
	vbox.add_child(label_estado_sala)

	# --- Salida siempre disponible (antes no había forma de volver al menú) ---
	boton_volver = Button.new()
	boton_volver.text = "Volver al menú"
	boton_volver.pressed.connect(_volver_al_menu)
	vbox.add_child(boton_volver)

	# --- Continuar la última partida guardada (Fase 1) ---
	# Solo lo ve quien tiene una partida guardada en este equipo (el anfitrión
	# de esa partida). Los demás se unen normal y recuperan su personaje.
	boton_continuar = Button.new()
	vbox.add_child(boton_continuar)
	vbox.move_child(boton_continuar, btn_host.get_index() + 1)
	boton_continuar.pressed.connect(_on_btn_continuar_pressed)
	var guardada := GuardadoGlobal.cargar_partida()
	if guardada.is_empty():
		boton_continuar.hide()
	else:
		var n_jugadores := maxi(1, guardada.get("jugadores", {}).size())
		boton_continuar.text = "Continuar partida (Noche %d, %d jugador%s)" % [int(guardada.get("oleada", 1)), n_jugadores, "" if n_jugadores == 1 else "es"]

	_actualizar_texto_boton_host()

func _on_btn_continuar_pressed():
	var guardada := GuardadoGlobal.cargar_partida()
	if guardada.is_empty(): return
	EstadoPartida.partida_a_cargar = guardada
	cantidad_deseada = clampi(guardada.get("jugadores", {}).size(), 1, MAX_CLIENTS)
	spin_cantidad.value = cantidad_deseada
	_continuando = true
	_on_btn_host_pressed()
	_continuando = false

# Presentación: fondo oscuro y todo dentro de una tarjeta centrada.
func _aplicar_estilo():
	var fondo := ColorRect.new()
	fondo.color = Color(0.078, 0.09, 0.11)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	move_child(fondo, 0)

	var vbox: VBoxContainer = $VBoxContainer
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var tarjeta := PanelContainer.new()
	centro.add_child(tarjeta)
	vbox.reparent(tarjeta, false)
	vbox.custom_minimum_size = Vector2(460, 0)
	vbox.add_theme_constant_override("separation", 12)

	var titulo: Label = vbox.get_node("Label")
	titulo.text = "PARTIDA EN EQUIPO"
	titulo.theme_type_variation = &"Titulo"
	titulo.add_theme_font_size_override("font_size", 32)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	btn_host.theme_type_variation = &"BotonPrimario"
	boton_iniciar.theme_type_variation = &"BotonPrimario"
	boton_continuar.theme_type_variation = &"BotonPrimario"
	lista_jugadores.custom_minimum_size = Vector2(0, 120)
	input_ip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for b in [btn_host, btn_unirse, boton_iniciar, boton_continuar, boton_volver]:
		EstiloUI.agregar_rebote(b)

func _actualizar_texto_boton_host():
	btn_host.text = "Jugar Solo" if cantidad_deseada <= 1 else "Crear Partida (Host)"

# Cierra la conexión (si hay) y vuelve al menú principal. Sirve tanto antes de
# crear/unirse a una sala como estando ya dentro de una.
func _volver_al_menu():
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	EstadoPartida.ids_iniciales = []
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()

# ==========================================
# BOTONES DE CONEXIÓN
# ==========================================
func _on_btn_host_pressed():
	# Partida nueva salvo que venga de "Continuar partida".
	if not _continuando:
		EstadoPartida.partida_a_cargar = {}
	var error = peer.create_server(EstadoPartida.PUERTO_RED, MAX_CLIENTS)
	if error != OK:
		print("Error al crear el Host: ", error)
		return

	soy_host = true
	contrasena_sala = input_contrasena_crear.text
	multiplayer.multiplayer_peer = peer
	print("¡Servidor Host creado! Esperando a los muchachos... (sala de ", cantidad_deseada, ")")

	# EL HOST SE REGISTRA A SÍ MISMO (El Host SIEMPRE es el ID 1)
	jugadores_conectados[1] = "Superviviente 1 (Host)"
	actualizar_ui_lobby()
	_actualizar_estado_sala()

	esconder_menu_conexion()

	# Una sala de 1 jugador es "jugar solo": no hay nadie a quien esperar.
	if cantidad_deseada <= 1:
		_on_boton_iniciar_juego_pressed()

func _on_btn_unirse_pressed():
	var ip = input_ip.text
	if ip == "":
		ip = "127.0.0.1"

	var error = peer.create_client(ip, EstadoPartida.PUERTO_RED)
	if error != OK:
		print("Error al configurar el cliente: ", error)
		return

	multiplayer.multiplayer_peer = peer

	# --- FIX (Fase 1.D: Reconexión automática) ---
	# EstadoPartida (el Autoload) necesita saber a qué IP nos conectamos para
	# poder reintentar solo si la conexión se cae mientras la app está en
	# background (ver _al_recuperar_foco en estado_partida.gd). Sin esta
	# línea, ultima_ip se queda vacío para siempre y el auto-reconectar nunca
	# tiene a dónde reintentar.
	EstadoPartida.ultima_ip = ip

	print("Conectando a la IP: ", ip, "...")
	esconder_menu_conexion()

func esconder_menu_conexion():
	btn_host.hide()
	btn_unirse.hide()
	input_ip.hide()
	if boton_continuar: boton_continuar.hide()
	fila_cantidad.hide()
	input_contrasena_crear.hide()
	input_contrasena_unirse.hide()

func _mostrar_menu_conexion():
	btn_host.show()
	btn_unirse.show()
	input_ip.show()
	fila_cantidad.show()
	input_contrasena_crear.show()
	input_contrasena_unirse.show()

# ==========================================
# CONEXIÓN Y VALIDACIÓN
# ==========================================
# Ya no nos presentamos apenas se abre el socket ENet (eso pasaba ANTES de
# que hubiera chance de validar contraseña o cupo). Ahora, quien se conecta
# manda una solicitud explícita y el host decide si lo deja pasar.

func _on_peer_connected(id):
	print("Nueva conexión de red, ID: ", id, " -- esperando que se identifique.")

func _on_peer_disconnected(id):
	print("Jugador desconectado: ", id)
	if soy_host:
		jugadores_conectados.erase(id)
		sincronizar_lista_jugadores.rpc(jugadores_conectados)

func _on_conectado_al_servidor():
	print("Conectado a nivel de red -- pidiendo entrar a la sala...")
	var mi_id = multiplayer.get_unique_id()
	var mi_contrasena = input_contrasena_unirse.text
	solicitar_entrar_a_sala.rpc_id(1, mi_id, "Superviviente " + str(mi_id), mi_contrasena)

func _on_falla_de_conexion():
	print("Error de conexión. ¿El Host está activo?")
	_mostrar_menu_conexion()

# El cliente le pide entrar al host, mandando la contraseña que escribió (si
# la sala no tiene, cualquier valor -- incluso vacío -- sirve).
@rpc("any_peer", "reliable")
func solicitar_entrar_a_sala(id_solicitante: int, nombre: String, contrasena_ingresada: String):
	if not multiplayer.is_server(): return

	if sala_bloqueada:
		_rechazar_conexion(id_solicitante, "La partida ya empezó.")
		return

	if contrasena_sala != "" and contrasena_ingresada != contrasena_sala:
		_rechazar_conexion(id_solicitante, "Contraseña incorrecta.")
		return

	if jugadores_conectados.size() >= cantidad_deseada:
		_rechazar_conexion(id_solicitante, "La sala ya está llena.")
		return

	jugadores_conectados[id_solicitante] = nombre
	informar_cantidad_deseada.rpc_id(id_solicitante, cantidad_deseada)
	sincronizar_lista_jugadores.rpc(jugadores_conectados)

func _rechazar_conexion(id_solicitante: int, motivo: String) -> void:
	print("Jugador ", id_solicitante, " rechazado: ", motivo)
	avisar_rechazo.rpc_id(id_solicitante, motivo)
	# Le damos un instante para que el aviso le llegue antes de cortar el socket.
	await get_tree().create_timer(0.3).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(id_solicitante)

@rpc("authority", "reliable")
func avisar_rechazo(motivo: String):
	print("No se pudo entrar a la sala: ", motivo)
	label_estado_sala.show()
	label_estado_sala.text = "No se pudo entrar: " + motivo
	# El peer viejo ya quedó inválido -- armamos uno nuevo para el próximo intento.
	peer = ENetMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	_mostrar_menu_conexion()

@rpc("authority", "reliable")
func informar_cantidad_deseada(cantidad: int):
	cantidad_deseada = cantidad

# El host es la única fuente de verdad de la lista de jugadores; cada vez
# que cambia, la reparte completa a todos (incluyéndose, con call_local).
# Evitamos así el patrón anterior de "cada cliente se presenta a mano",
# que dejaba a los clientes viejos sin saber de los nuevos.
@rpc("authority", "call_local", "reliable")
func sincronizar_lista_jugadores(lista: Dictionary):
	jugadores_conectados = lista
	actualizar_ui_lobby()
	_actualizar_estado_sala()

# Refresca el ItemList de la pantalla
func actualizar_ui_lobby():
	lista_jugadores.clear()
	for id in jugadores_conectados:
		lista_jugadores.add_item(jugadores_conectados[id])

func _actualizar_estado_sala():
	label_estado_sala.show()
	label_estado_sala.text = "Sala: %d/%d jugadores" % [jugadores_conectados.size(), cantidad_deseada]

	if soy_host:
		boton_iniciar.visible = jugadores_conectados.size() >= cantidad_deseada

# ==========================================
# TRANSICIÓN AL MAPA DE JUEGO
# ==========================================

# --- ¡OJO! CONECTA EL BOTÓN "BotonIniciarJuego" A ESTA FUNCIÓN ---
func _on_boton_iniciar_juego_pressed():
	if jugadores_conectados.size() < cantidad_deseada:
		return  # por si el botón quedó visible por un frame de más
	sala_bloqueada = true

	# --- FIX (Sala con cupo fijo) ---
	# mundo.gd necesita saber quiénes estaban legítimamente en la sala al
	# arrancar, para no confundirlos con un desconocido que se conecta
	# después de cerrada la sala (ver ids_iniciales en estado_partida.gd).
	EstadoPartida.ids_iniciales = jugadores_conectados.keys()

	# El Host le dice a TODOS (incluyéndose a sí mismo) que el juego va a empezar
	iniciar_juego.rpc()

# Esta función se ejecuta al mismo tiempo en las pantallas de TODOS los jugadores
@rpc("call_local", "reliable")
func iniciar_juego():
	hide()  # Escondemos el menú de lobby
	print("¡INICIANDO PARTIDA CON ", jugadores_conectados.size(), " JUGADORES!")

	# ¡EL SALTO AL MUNDO!
	# Usamos la misma ruta que tenías en tu menú principal original
	get_tree().change_scene_to_file("res://scenes/mundo.tscn")
