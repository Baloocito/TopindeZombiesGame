extends Node3D

# ==========================================================
# 1. BASES DE DATOS Y CONSTANTES (Configuración estática)
# ==========================================================
const TAMAÑO_GRILLA: float = 2.0

# Los precios, vidas y armas ya no viven aquí: están en data/*.json y se
# piden a Balance (Manual v3). Este script solo guarda el estado de la partida.

# ==========================================================
# 2. ESTADO GLOBAL DEL JUEGO
# ==========================================================
var modo_construccion: bool = false
var fase_combate: bool = false
var oleada_actual: int = 1
var zombies_vivos: int = 0
var zombies_asesinados_partida: int = 0
var dinero_global: int = 0  # se carga de data/progresion.json en _ready
var reparaciones_usadas: int = 0

# ¡NUEVO! DICCIONARIO DE VOTACIÓN PARA INICIAR LA NOCHE
var jugadores_listos: Dictionary = {}

var planos_desbloqueados: Array[String] = []
var tienda_rotacion_actual: Array[String] = []
var nivel_armas: Dictionary = {}  # id de arma -> nivel de mejora (Mesa de Trabajo)

var objeto_seleccionado_tienda: String = ""
var torreta_seleccionada: Node3D = null
var construcciones_realizadas = { "madera": 0, "puas": 0, "barril": 0, "acero": 0, "electrico": 0, "torreta": 0 }
var celdas_ocupadas: Dictionary = {}
var celda_previa_tocada: Vector3 = Vector3.INF

# ==========================================================
# 3. ENLACES A NODOS (UI y Escenas)
# ==========================================================
@export_category("Escenas de Entidades")
@export var escena_jugador: PackedScene
@export var plano_arma_escena: PackedScene
@export var caja_municion_escena: PackedScene
@export var botiquin_escena: PackedScene
@export var moneda_escena: PackedScene

@export var escena_madera: PackedScene
@export var escena_puas: PackedScene
@export var escena_barril: PackedScene
@export var escena_acero: PackedScene
@export var escena_electrico: PackedScene
@export var escena_torreta: PackedScene

@onready var holograma = $Holograma
@onready var cuadricula_visual = $CuadriculaVisual
@onready var texto_game_over = $InterfazUI/TextoGameOver
@onready var boton_reiniciar = $InterfazUI/BotonReiniciar
@onready var boton_iniciar = $InterfazUI/BotonIniciar
@onready var texto_dinero = $InterfazUI/HudSuperiorDerecho/GrupoDinero/PanelDinero/LblDinero
@onready var boton_reparar = $InterfazUI/BotonReparar

@onready var boton_pausa = $InterfazUI/HudLateralDerecho/BotonPausa
@onready var boton_construir = $InterfazUI/HudLateralDerecho/BotonConstruir
@onready var boton_mochila = $InterfazUI/HudLateralDerecho/BotonMochila
@onready var boton_ensamblar = $InterfazUI/HudLateralDerecho/BotonEnsamblar
@onready var boton_nivel = $InterfazUI/HudSuperiorIzquierdo/BotonNivel

@onready var hud_combate = $InterfazUI/EsquinaArmas
@onready var slot_arma_1 = $InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma1
@onready var slot_arma_2 = $InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma2
@onready var slot_arma_3 = $InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma3
@onready var btn_recarga_izq = $InterfazUI/BotonRecargaIzquierdo
@onready var btn_recarga_der = $InterfazUI/BotonRecargaDerecho

@onready var panel_fase = $InterfazUI/ContenedorAlertas/PanelFase
@onready var lbl_titulo_fase = $InterfazUI/ContenedorAlertas/PanelFase/VBoxContainer/LblTituloFase
@onready var lbl_zombies = $InterfazUI/ContenedorAlertas/PanelFase/VBoxContainer/CajaZombies/LblZombies

@onready var menu_pausa = $MenuPausa
@onready var panel_lateral = $InterfazUI/PanelLateral
@onready var boton_cerrar_panel = $InterfazUI/PanelLateral/BotonCerrar
@onready var menu_armeria = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuArmeria
@onready var menu_construccion = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuConstruccion
@onready var menu_inspector = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuInspector
@onready var menu_nivel = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuNivel
@onready var menu_ensamblaje = $InterfazUI/PanelLateral/MargenInterno/ScrollLateral/ContenedorMenus/MenuEnsamblaje

var tween_fase: Tween

# Módulos separados de este script (se crean en _ready).
var menus: MenusMundo
var loot: LootMundo

# ==========================================================
# 3.5. LÓGICA DE MULTIJUGADOR Y BÚSQUEDA LOCAL
# ==========================================================
# --- FIX (revisión de código, Fase 1.C: Reconexión) ---
# Antes esto usaba multiplayer.get_unique_id() directo. Eso deja de servir
# apenas hay reconexión: tu id de red CAMBIA cada vez que te reconectás,
# pero tu personaje sigue siendo el mismo nodo (con el nombre viejo).
# EstadoPartida.mi_id_logico es el que el servidor te informa como "tu
# nodo real" y no cambia aunque tu id de red sí.
func obtener_jugador_local():
	var mi_id = str(EstadoPartida.mi_id_logico)
	var contenedor = get_node_or_null("ContenedorJugadores")
	if contenedor and EstadoPartida.mi_id_logico != -1 and contenedor.has_node(mi_id):
		return contenedor.get_node(mi_id)
	return null

func generar_jugadores_multijugador():
	spawnear_jugador(1)
	for id in multiplayer.get_peers():
		spawnear_jugador(id)

func spawnear_jugador(id: int):
	# --- FIX (revisión de código) ---
	# Esta función ahora se llama desde DOS lugares (generar_jugadores_multijugador
	# al arrancar, y solicitar_sincronizacion_tardia cuando un cliente recién
	# cargó Mundo). Sin este guard, una carrera de red entre ambos caminos podía
	# espawnear al mismo jugador dos veces (Godot renombra el segundo clon,
	# tipo "2@2", y quedaba un jugador fantasma duplicado en el mapa).
	if get_node_or_null("ContenedorJugadores/%s" % str(id)):
		return
	var nuevo_jugador = escena_jugador.instantiate()
	nuevo_jugador.name = str(id)
	$ContenedorJugadores.add_child(nuevo_jugador)
	nuevo_jugador.global_position = Vector3(randf_range(-2.0, 2.0), 1.0, randf_range(-2.0, 2.0))

	# --- FIX (bug real, confirmado con captura de pantalla) ---
	# Antes, el único que avisaba "este es tu personaje" (informar_id_logico)
	# era solicitar_sincronizacion_tardia, disparado por el PROPIO cliente al
	# cargar Mundo.tscn. Problema: en un arranque simultáneo normal, este
	# spawneo del servidor (que no necesita ida y vuelta por red) casi
	# siempre gana la carrera contra el pedido del cliente -- que entonces
	# llega tarde, se encuentra con que el nodo YA existe, y
	# solicitar_sincronizacion_tardia se cortaba ahí sin avisarle nada a
	# nadie. Resultado: EstadoPartida.mi_id_logico se quedaba en -1 para
	# siempre en ese cliente -- la cámara nunca encontraba a quién seguir, y
	# el overlay "Sincronizando partida..." (que se oculta justo en
	# informar_id_logico) se quedaba pegado en pantalla, tapando los clics y
	# bloqueando hasta el botón de Iniciar Horda. Ahora se lo empujamos
	# nosotros mismos apenas lo creamos, sin depender de que el cliente lo
	# pida a tiempo.
	if id != 1:
		EstadoPartida.informar_id_logico.rpc_id(id, id)

# ==========================================================
# 3.6. LATE JOIN (Fase 1, GDD v2 Sección 0.E)
# ==========================================================
# --- NUEVO ---
# Antes, spawnear_jugador() solo corría una vez en _ready(), para quienes ya
# estaban conectados al cargar mundo.tscn. Un jugador que se conecta DESPUÉS
# (reconexión tras una caída, o alguien que se suma a mitad de partida) nunca
# era spawneado -- el juego simplemente lo ignoraba. Escuchando
# multiplayer.peer_connected durante TODA la partida (no solo al inicio),
# cualquiera que se conecte después se suma "al ritmo" del equipo: mismo
# dinero, misma oleada, misma fase.
func _on_peer_conectado_tardio(id: int):
	if not multiplayer.is_server(): return
	if get_node_or_null("ContenedorJugadores/%s" % str(id)):
		return
	print("¡Jugador tardío conectado! ID: %s -- avisándole que salte a Mundo (oleada %s)." % [id, oleada_actual])
	# Solo le avisamos que cambie de escena. Todavía NO lo espawneamos ni le
	# mandamos estado, porque su árbol de nodos sigue siendo el de Lobby
	# (no existe "Mundo" ni "ContenedorJugadores" ahí todavía). Él mismo nos
	# va a pedir los datos apenas termine de cargar Mundo.tscn (ver abajo).
	EstadoPartida.avisar_partida_en_curso.rpc_id(id)

# ==========================================================
# 3.7. RECONEXIÓN EN CALIENTE (Fase 1, GDD v2 Sección 0.C/D)
# ==========================================================
# Ventana de gracia: cuánto tiempo (en segundos) espera el servidor a que un
# jugador desconectado vuelva a conectarse desde el MISMO cliente (mismo
# token) antes de dejar de reservarle su personaje.
const VENTANA_GRACIA_SEGUNDOS: float = 90.0

# token (EstadoPartida.mi_token del jugador) -> id de red ACTUAL. Nos deja
# saber, cuando alguien se desconecta, a qué token pertenecía ese id.
var token_por_id: Dictionary = {}

# token -> datos para restaurar SI reconecta a tiempo: id_logico (nombre de
# su nodo), el momento en que se cayó, si estaba derribado o no, y su vida
# y posición justo antes de caerse.
var jugadores_desconectados: Dictionary = {}

func _on_peer_desconectado(id: int):
	if not multiplayer.is_server(): return

	var token = null
	for t in token_por_id.keys():
		if token_por_id[t] == id:
			token = t
			break
	if token == null: return
	token_por_id.erase(token)

	var nodo = get_node_or_null("ContenedorJugadores/%s" % str(id))
	if not is_instance_valid(nodo): return

	jugadores_desconectados[token] = {
		"id_logico": id,
		"hora_desconexion": Time.get_ticks_msec(),
		"estaba_caido": nodo.esta_caido,
		"salud_guardada": max(1, nodo.salud_actual) if not nodo.esta_caido else 0,
		"posicion_guardada": nodo.global_position
	}

	# Lo derribamos (si no lo estaba ya) para que el equipo no quede en
	# desventaja injusta mientras esperamos a ver si vuelve.
	if nodo.has_method("quedar_derribado") and not nodo.esta_caido:
		nodo.quedar_derribado()

	print("Jugador %s se desconectó -- derribado, ventana de gracia de %ss para reconectar." % [id, VENTANA_GRACIA_SEGUNDOS])

# NUEVA función: la llama el propio cliente (nuevo O reconectado) cuando YA
# cargó Mundo.tscn. Un solo punto de entrada para los dos casos.
@rpc("any_peer", "reliable")
func solicitar_sincronizacion_tardia(token: String):
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()

	# --- FIX: red de seguridad si ya estaba spawneado ---
	# Antes esto cortaba en silencio ("return" sin avisar nada) si el nodo ya
	# existía -- que es exactamente lo que pasa en un arranque simultáneo
	# normal, porque spawnear_jugador() del servidor gana la carrera casi
	# siempre. Ahora spawnear_jugador() avisa el id lógico por su cuenta
	# apenas crea el nodo (ver ahí), así que ESTO ya no debería hacer falta
	# -- pero si por lo que sea ese aviso no llegó (paquete perdido, orden
	# de carga raro), se lo reenviamos acá para no dejar a nadie con la
	# pantalla de "Sincronizando..." pegada para siempre.
	if get_node_or_null("ContenedorJugadores/%s" % str(id)):
		token_por_id[token] = id
		EstadoPartida.informar_id_logico.rpc_id(id, id)
		sincronizar_jugador_tardio.rpc_id(id, oleada_actual, dinero_global, fase_combate)
		return

	# --- ¿Es una reconexión dentro de la ventana de gracia? ---
	if jugadores_desconectados.has(token):
		var info = jugadores_desconectados[token]
		var segundos_pasados = (Time.get_ticks_msec() - info["hora_desconexion"]) / 1000.0
		var id_logico = info["id_logico"]
		var nodo_reclamado = get_node_or_null("ContenedorJugadores/%s" % str(id_logico))

		jugadores_desconectados.erase(token) # una sola oportunidad de reclamo por caída

		if segundos_pasados <= VENTANA_GRACIA_SEGUNDOS and is_instance_valid(nodo_reclamado):
			token_por_id[token] = id
			nodo_reclamado.set_multiplayer_authority(id)

			EstadoPartida.informar_id_logico.rpc_id(id, id_logico)
			sincronizar_jugador_tardio.rpc_id(id, oleada_actual, dinero_global, fase_combate)

			for estructura in get_children():
				if estructura.is_in_group("barricadas") and "tipo_estructura" in estructura and "salud_actual" in estructura:
					reproducir_estructura_para_tardio.rpc_id(id, estructura.tipo_estructura, estructura.global_position, estructura.salud_actual, estructura.salud_maxima)

			# Le reproducimos a TODOS los jugadores existentes, incluido el suyo
			# propio (su cliente es una conexión de red nueva -- nunca recibió
			# nada de lo que ya existía antes de conectarse, ni siquiera su
			# propio personaje). Para el suyo, forzamos la autoridad real
			# (su id de red nuevo) en vez de dejar que quede con el nombre
			# viejo del nodo.
			for jugador_existente in $ContenedorJugadores.get_children():
				var es_el_mio = jugador_existente.name == str(id_logico)
				reproducir_jugador_para_tardio.rpc_id(id, jugador_existente.name.to_int(), jugador_existente.global_position, id if es_el_mio else -1)

			# Si estaba vivo cuando se cayó, le devolvemos el control con la
			# vida/posición que tenía. Si ya estaba derribado, sigue derribado
			# (no regalamos una reanimación gratis por desconectarse).
			if not info["estaba_caido"] and nodo_reclamado.has_method("reconectar_en_red"):
				nodo_reclamado.reconectar_en_red.rpc(info["salud_guardada"], info["posicion_guardada"])

			print("Jugador reconectado dentro de la ventana de gracia. id_logico=%s nuevo id_red=%s" % [id_logico, id])
			return
		# si se acabó el tiempo o el nodo ya no existe, se rechaza como cualquier desconocido abajo

	# --- FIX (Fase 1: sala con cupo fijo) ---
	# Antes, cualquier conexión sin token conocido entraba como "jugador
	# nuevo" (spawnear_jugador). Eso tenía sentido cuando cualquiera podía
	# sumarse a mitad de partida -- pero ahora lobby.gd ya no deja arrancar
	# la horda hasta llenar el cupo elegido por el host, así que la sala
	# está pensada para cerrarse. El nodo Lobby (con su chequeo de
	# contraseña/cupo) se destruye al cambiar de escena a Mundo, pero el
	# socket ENet del host sigue escuchando en el puerto -- sin este
	# rechazo, un desconocido que se conectara DESPUÉS de iniciada la
	# partida se metía derecho como jugador nuevo, sin pasar por ningún
	# control.
	#
	# OJO: esta rama también la pisan, en condiciones normales, los
	# jugadores que arrancaron la horda JUNTO con todos los demás -- su
	# propio _ready() manda este mismo RPC apenas cargan Mundo.tscn, y si
	# esa solicitud le gana de mano por red a generar_jugadores_multijugador()
	# del servidor, llega hasta acá aunque no sea ningún desconocido. Por
	# eso primero chequeamos ids_iniciales (la lista que lobby.gd guardó
	# justo antes de cerrar la sala) -- si el id estaba ahí, es un arranque
	# normal y lo dejamos entrar por el camino de siempre. Solo rechazamos
	# a quien NO estaba en esa lista y tampoco trae un token de reconexión
	# válido.
	if id in EstadoPartida.ids_iniciales:
		token_por_id[token] = id
		print("Jugador %s ya cargó Mundo -- sincronizando partida en curso (oleada %s)." % [id, oleada_actual])
		for jugador_existente in $ContenedorJugadores.get_children():
			reproducir_jugador_para_tardio.rpc_id(id, jugador_existente.name.to_int(), jugador_existente.global_position)
		spawnear_jugador(id)
		EstadoPartida.informar_id_logico.rpc_id(id, id)
		sincronizar_jugador_tardio.rpc_id(id, oleada_actual, dinero_global, fase_combate)
		for estructura in get_children():
			if estructura.is_in_group("barricadas") and "tipo_estructura" in estructura and "salud_actual" in estructura:
				reproducir_estructura_para_tardio.rpc_id(id, estructura.tipo_estructura, estructura.global_position, estructura.salud_actual, estructura.salud_maxima)
		return

	print("Jugador %s intentó entrar a una partida ya en curso sin token válido -- rechazado." % id)
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(id)

# Recrea en la pantalla del jugador tardío/reconectado a UN compañero (o al
# Host, o a él mismo) que ya existía ANTES de que esta conexión de red se
# estableciera. Sin esto, el MultiplayerSpawner nunca le informa de esos
# jugadores porque fueron espawneados antes de que este peer existiera para
# la red. "autoridad_real": -1 = dejar la autoridad por defecto (el propio
# nombre del nodo, para compañeros); un id concreto = forzar esa autoridad
# (para reconectar a alguien bajo un id de red nuevo).
@rpc("authority", "reliable")
func reproducir_jugador_para_tardio(id_jugador: int, pos: Vector3, autoridad_real: int = -1):
	var existente = get_node_or_null("ContenedorJugadores/%s" % str(id_jugador))
	if existente:
		# Puede que el spawner ya lo haya creado al conectarnos; igual hay que
		# corregir la autoridad si es nuestro personaje recuperado.
		if autoridad_real != -1:
			existente.set_multiplayer_authority(autoridad_real)
		return
	var nuevo_jugador = escena_jugador.instantiate()
	nuevo_jugador.name = str(id_jugador)
	$ContenedorJugadores.add_child(nuevo_jugador)
	nuevo_jugador.global_position = pos
	if autoridad_real != -1:
		nuevo_jugador.set_multiplayer_authority(autoridad_real)

# --- FIX (revisión de código) ---
# Esta función se llamaba en solicitar_sincronizacion_tardia() pero nunca
# había sido escrita -- de ahí el error "Identifier not declared in the
# current scope". Es la que pone al día al jugador tardío en SU pantalla:
# oleada, dinero y si ya está en combate o en fase de preparación.
@rpc("authority", "reliable")
func sincronizar_jugador_tardio(oleada: int, dinero: int, en_combate: bool):
	oleada_actual = oleada
	dinero_global = dinero
	fase_combate = en_combate

	if texto_dinero:
		texto_dinero.text = str(dinero_global) + "G"

	cambiar_fase_ui(en_combate)

	if boton_reparar:
		boton_reparar.visible = not en_combate
		actualizar_boton_reparacion()

	if en_combate:
		animar_fase("TE UNISTE A LA NOCHE " + str(oleada_actual), Color(1, 0.4, 0.4))
	else:
		animar_fase("DÍA " + str(oleada_actual) + ": PREPÁRATE", Color.WHITE)

# Recrea visualmente UNA estructura ya existente en la pantalla del jugador
# tardío. A diferencia de ejecutar_construccion_en_red, esto NO toca
# construcciones_realizadas ni celdas_ocupadas -- esa contabilidad ya se hizo
# cuando la estructura se construyó de verdad; esto es solo ponerse al día
# visualmente.
@rpc("authority", "reliable")
func reproducir_estructura_para_tardio(tipo: String, pos_real: Vector3, salud_actual_real: int, salud_maxima_real: int):
	var nuevo_edificio = _crear_estructura(tipo, pos_real)
	if not nuevo_edificio: return

	if "salud_maxima" in nuevo_edificio:
		nuevo_edificio.salud_maxima = salud_maxima_real
		nuevo_edificio.salud_actual = salud_actual_real

# ==========================================================
# 4. INICIALIZACIÓN
# ==========================================================
func _ready():
	# Cliente que volvió desde el Lobby a una partida en curso: se conecta
	# recién ahora, con Mundo ya cargado (ver EstadoPartida.avisar_partida_en_curso).
	if EstadoPartida.cliente_reentrando:
		EstadoPartida.conectar_como_cliente()

	dinero_global = int(Balance.progresion["dinero_inicial"])
	for id in Balance.ids_armas(): nivel_armas[id] = 1

	menus = MenusMundo.new()
	menus.name = "Menus"
	menus.m = self
	add_child(menus)
	loot = LootMundo.new()
	loot.name = "Loot"
	loot.m = self
	add_child(loot)

	holograma.visible = false
	panel_fase.visible = false

	# Aseguramos de que el botón iniciar esté conectado a la nueva función de votación
	if boton_iniciar and not boton_iniciar.pressed.is_connected(_al_presionar_iniciar):
		boton_iniciar.pressed.connect(_al_presionar_iniciar)
	# Si YO soy el que recién cargó Mundo (host normal, tardío o reconectado),
	# le pido al servidor mis datos, mandándole mi token propio (no mi id de
	# red, que puede haber cambiado si me estoy reconectando). Si ya estaba
	# espawneado (inicio normal de partida), el guard de arriba
	# (get_node_or_null en spawnear_jugador) hace que esto no rompa nada ni
	# duplique jugadores.
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer() and not EstadoPartida.cliente_reentrando:
		# --- NUEVO: feedback visible mientras esperamos la respuesta del
		# servidor. Antes esta espera (normalmente menos de un segundo, pero
		# a veces más si la carga de escena tardó) se veía como pantalla
		# congelada / personaje invisible que no responde. Se oculta solo en
		# EstadoPartida.informar_id_logico() apenas el servidor confirma.
		EstadoPartida.mostrar_overlay_texto("Sincronizando partida…")
		solicitar_sincronizacion_tardia.rpc_id(1, EstadoPartida.mi_token)
	conectar_botones_combate()

	if multiplayer.is_server():
		EstadoPartida.mi_id_logico = 1 # El Host siempre es el id 1

		# --- NUEVO (Late join, GDD v2 Sección 0.E) ---
		# Escuchamos conexiones nuevas durante TODA la partida, no solo al
		# arrancar. Conectada ANTES de generar_jugadores_multijugador() para
		# no dejar ninguna ventana sin cubrir.
		if not multiplayer.peer_connected.is_connected(_on_peer_conectado_tardio):
			multiplayer.peer_connected.connect(_on_peer_conectado_tardio)

		# --- NUEVO (Fase 1.C: Reconexión) ---
		# Cuando alguien se cae, lo derribamos y guardamos su lugar en vez de
		# borrarlo, por si vuelve dentro de la ventana de gracia.
		if not multiplayer.peer_disconnected.is_connected(_on_peer_desconectado):
			multiplayer.peer_disconnected.connect(_on_peer_desconectado)

		# El Host configura la partida inicial y avisa a todos
		generar_jugadores_multijugador()
		sumar_dinero(0)
		fase_preparacion_en_red.rpc(1)

func conectar_botones_combate():
	var equipar_lambda = func(slot_id: int):
		var mi_jugador = obtener_jugador_local()
		if mi_jugador: mi_jugador.equipar_arma_directa(slot_id)

	var recargar_lambda = func():
		var mi_jugador = obtener_jugador_local()
		if mi_jugador and mi_jugador.has_method("recargar_arma_actual"):
			mi_jugador.recargar_arma_actual()

	if slot_arma_1: slot_arma_1.pressed.connect(equipar_lambda.bind(0))
	if slot_arma_2: slot_arma_2.pressed.connect(equipar_lambda.bind(1))
	if slot_arma_3: slot_arma_3.pressed.connect(equipar_lambda.bind(2))
	if btn_recarga_izq: btn_recarga_izq.pressed.connect(recargar_lambda)
	if btn_recarga_der: btn_recarga_der.pressed.connect(recargar_lambda)

# ==========================================================
# 5. GESTOR DE FASES Y SISTEMA DE VOTACIÓN (READY UP)
# ==========================================================
func _al_presionar_iniciar():
	# El jugador presiona, deshabilitamos su botón para evitar spam
	boton_iniciar.disabled = true
	boton_iniciar.text = "¡Listo!"
	# Le enviamos el voto al Servidor
	declarar_listo_servidor.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func declarar_listo_servidor(id_jugador: int):
	if not multiplayer.is_server(): return

	jugadores_listos[id_jugador] = true
	var total_jugadores = multiplayer.get_peers().size() + 1 # Clientes + Host
	var listos = jugadores_listos.size()

	# Actualizamos visualmente el botón para que todos vean cuántos faltan
	actualizar_ui_listos.rpc(listos, total_jugadores)

	# Si todos votaron que sí, comienza la masacre
	if listos >= total_jugadores:
		jugadores_listos.clear()
		iniciar_oleada_en_red.rpc()

@rpc("call_local", "reliable")
func actualizar_ui_listos(listos: int, totales: int):
	if boton_iniciar and not boton_iniciar.disabled:
		boton_iniciar.text = "Iniciar Noche (" + str(listos) + "/" + str(totales) + ")"

@rpc("call_local", "reliable")
func fase_preparacion_en_red(nueva_oleada: int):
	oleada_actual = nueva_oleada
	fase_combate = false
	modo_construccion = false
	holograma.visible = false

	# --- NUEVO (mecánica de derribo/reanimación) ---
	# Si se llegó hasta acá es porque la oleada terminó con al menos un
	# jugador en pie (si todos hubieran caído, revisar_todos_caidos() ya
	# habría disparado el Game Over antes de llegar aquí). Aprovechamos el
	# descanso del nuevo día para revivir a cualquiera que haya quedado
	# derribado durante la noche. Solo el SERVIDOR emite estas RPCs de
	# reanimación (evita que cada peer las repita N veces, una por cliente).
	if multiplayer.is_server():
		for jug in get_tree().get_nodes_in_group("jugador"):
			if jug.has_method("revivir_en_red") and "esta_caido" in jug and jug.esta_caido:
				jug.revivir_en_red.rpc(1.0)

	# XP por noche superada (Manual v3 §5). Cada pantalla se la da a SU
	# jugador: esta función ya corre en todos los peers.
	if oleada_actual > 1:
		_dar_experiencia_local(Balance.xp_por_noche(oleada_actual - 1))

	animar_fase("DÍA " + str(oleada_actual) + ": PREPÁRATE", Color.WHITE)
	cambiar_fase_ui(false)

	reparaciones_usadas = 0
	if boton_reparar:
		boton_reparar.visible = true
		actualizar_boton_reparacion()

	# Restauramos el botón de iniciar para la nueva oleada
	if boton_iniciar:
		boton_iniciar.disabled = false
		boton_iniciar.text = "Iniciar Noche"

@rpc("call_local", "reliable")
func iniciar_oleada_en_red():
	fase_combate = true
	modo_construccion = false
	holograma.visible = false
	cerrar_menu_lateral()
	animar_fase("NOCHE ETERNA: OLEADA " + str(oleada_actual), Color(1, 0.2, 0.2))

	cambiar_fase_ui(true)
	if boton_reparar: boton_reparar.visible = false

	# SOLO el servidor spawnea los zombies
	if multiplayer.is_server():
		zombies_vivos = $GeneradorZombies.preparar_oleada(oleada_actual)
		$GeneradorZombies.iniciar_generacion()

func cambiar_fase_ui(es_combate: bool):
	var ui_dia = [boton_iniciar, boton_construir, boton_mochila, boton_nivel, boton_ensamblar]
	var ui_noche = [hud_combate, btn_recarga_izq, btn_recarga_der]

	for elemento in ui_dia:
		if is_instance_valid(elemento): elemento.visible = not es_combate

	for elemento in ui_noche:
		if is_instance_valid(elemento): elemento.visible = es_combate

	var mi_jugador = obtener_jugador_local()
	if mi_jugador and mi_jugador.has_method("set_can_fire"):
		mi_jugador.set_can_fire(es_combate)

func animar_fase(titulo: String, color_texto: Color):
	lbl_titulo_fase.text = titulo
	lbl_titulo_fase.modulate = color_texto
	panel_fase.visible = true
	panel_fase.modulate.a = 0.0
	panel_fase.scale = Vector2(1.2, 1.2)

	if tween_fase: tween_fase.kill()
	tween_fase = create_tween()
	tween_fase.tween_property(panel_fase, "modulate:a", 1.0, 0.4)
	tween_fase.parallel().tween_property(panel_fase, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE)
	tween_fase.tween_interval(4.0)
	tween_fase.tween_property(panel_fase, "modulate:a", 0.0, 0.5)
	tween_fase.tween_callback(panel_fase.hide)

# ==========================================================
# 6. SISTEMA DE ECONOMÍA, PROGRESIÓN Y REPARACIÓN
# ==========================================================
func sumar_dinero(cantidad: int):
	if not multiplayer.is_server(): return
	dinero_global += cantidad
	actualizar_dinero_para_todos.rpc(dinero_global)

# --- FIX (revisión de código) ---
# moneda.gd llama a "mundo.sincronizar_dinero_en_red.rpc(valor_oro)" al
# recolectarse, pero esta función no existía acá -- solo existía
# actualizar_dinero_para_todos. Como mundo.has_method("sincronizar_dinero_en_red")
# daba false, moneda.gd nunca mandaba la RPC: la moneda se destruía
# (queue_free) sin sumar oro nunca, en silencio, sin ningún error en consola.
# Este alias usa la ruta ya existente y correcta (sumar_dinero, que ya hace
# el broadcast) para no duplicar lógica.
@rpc("any_peer", "reliable")
func sincronizar_dinero_en_red(cantidad_oro: int):
	if not multiplayer.is_server(): return
	sumar_dinero(cantidad_oro)

# --- NUEVO (revisión de código) ---
# planos_desbloqueados es la lista de planos de TODO EL EQUIPO, no de un
# jugador individual. plano_arma.gd la llama vía el servidor cuando alguien
# recoge un plano, para que se reparta a TODAS las pantallas a la vez
# (antes solo se modificaba en la pantalla de quien lo tocaba, y el resto
# del equipo jamás veía ese plano en su Mesa de Trabajo).
@rpc("call_local", "reliable")
func agregar_plano_para_todos(id_arma: String):
	if Balance.arma(id_arma).is_empty(): return
	planos_desbloqueados.append(id_arma)
	print("¡PLANO RECOGIDO!: ", Balance.arma(id_arma)["nombre"])
	_refrescar_menu_si_abierto(menu_ensamblaje, menus.actualizar_lista_ensamblaje)

@rpc("authority", "call_local", "reliable")
func quitar_plano_para_todos(id_arma: String):
	planos_desbloqueados.erase(id_arma)
	_refrescar_menu_si_abierto(menu_ensamblaje, menus.actualizar_lista_ensamblaje)

@rpc("authority", "call_local", "reliable")
func actualizar_dinero_para_todos(nuevo_valor: int):
	dinero_global = nuevo_valor
	if texto_dinero: texto_dinero.text = str(dinero_global) + "G"
	actualizar_boton_reparacion()

# Antes el servidor sumaba la XP sobre SUS copias de los jugadores, y solo
# la del host era real: los demás nunca subían de nivel por bajas. Ahora cada
# pantalla se la da a su propio personaje.
@rpc("authority", "call_local", "reliable")
func dar_experiencia_equipo(cantidad: int):
	_dar_experiencia_local(cantidad)

func _dar_experiencia_local(cantidad: int):
	if cantidad <= 0: return
	var jugador = obtener_jugador_local()
	if jugador and jugador.has_method("ganar_experiencia"):
		jugador.ganar_experiencia(cantidad)

func obtener_costo_reparacion() -> int:
	var costo_total = 0
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for barricada in barricadas:
		if barricada.has_method("obtener_costo_reparacion"):
			var precio_mercado = obtener_precio_estructura("madera")
			if "tipo_estructura" in barricada and barricada.tipo_estructura != "":
				precio_mercado = obtener_precio_estructura(barricada.tipo_estructura)
			costo_total += barricada.obtener_costo_reparacion(precio_mercado)
	return costo_total

func actualizar_boton_reparacion():
	if not boton_reparar: return
	var costo = obtener_costo_reparacion()
	var usos_restantes = int(Balance.progresion["reparaciones_por_dia"]) - reparaciones_usadas

	if costo == 0:
		boton_reparar.text = "Base Intacta"
		boton_reparar.disabled = true
	else:
		boton_reparar.text = "Reparar Todo ($" + str(costo) + ")"
		boton_reparar.disabled = (dinero_global < costo or usos_restantes <= 0)

# ¡NUEVO! Sincronizado para red
func ejecutar_reparacion_global():
	var costo = obtener_costo_reparacion()
	if costo == 0 or dinero_global < costo or reparaciones_usadas >= int(Balance.progresion["reparaciones_por_dia"]): return

	# Enviamos la petición al servidor si somos cliente
	if not multiplayer.is_server():
		solicitar_reparacion_servidor.rpc_id(1)
	else:
		solicitar_reparacion_servidor()

@rpc("any_peer", "reliable")
func solicitar_reparacion_servidor():
	if not multiplayer.is_server(): return
	var costo = obtener_costo_reparacion()
	if dinero_global >= costo and reparaciones_usadas < int(Balance.progresion["reparaciones_por_dia"]):
		sumar_dinero(-costo)
		ejecutar_reparacion_en_red.rpc()

@rpc("call_local", "reliable")
func ejecutar_reparacion_en_red():
	reparaciones_usadas += 1
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for barricada in barricadas:
		if barricada.has_method("reparar_completamente"):
			barricada.reparar_completamente()
	actualizar_boton_reparacion()

# ==========================================================
# 7. GENERACIÓN DE LOOT E IA DE COMBATE (Cerebro del Host)
# ==========================================================
# La lógica vive en scripts/mundo/loot_mundo.gd; zombie.gd y las
# estructuras siguen llamando a estas dos funciones de Mundo.
func spawn_loot(pos_muerte: Vector3, tipo_zombie: String):
	loot.spawn_loot(pos_muerte, tipo_zombie)

func generar_chatarra(posicion_destruccion: Vector3):
	loot.generar_chatarra(posicion_destruccion)

func zombie_eliminado():
	if not multiplayer.is_server(): return

	GuardadoGlobal.zombies_totales += 1
	zombies_asesinados_partida += 1
	actualizar_ui_zombies.rpc(zombies_asesinados_partida)

	zombies_vivos -= 1
	if zombies_vivos <= 0:
		oleada_actual += 1
		# Pasamos a la siguiente fase para todos
		fase_preparacion_en_red.rpc(oleada_actual)

@rpc("call_local", "reliable")
func actualizar_ui_zombies(asesinados: int):
	zombies_asesinados_partida = asesinados
	if lbl_zombies: lbl_zombies.text = str(zombies_asesinados_partida)

# --- NUEVO (mecánica de derribo/reanimación) ---
# Cada jugador que queda derribado (jugador.gd: quedar_derribado()) llama a
# esto SOLO en la instancia del servidor. Si TODOS los jugadores del grupo
# "jugador" están derribados a la vez, recién ahí es Game Over de verdad.
func revisar_todos_caidos():
	if not multiplayer.is_server(): return

	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.is_empty(): return

	for jug in jugadores:
		if not ("esta_caido" in jug) or not jug.esta_caido:
			return # alguien sigue en pie, todavía no es Game Over

	ejecutar_game_over_en_red.rpc()

# --- FIX (revisión de código) ---
# Antes esto era una función local (ejecutar_game_over()) que cada jugador
# llamaba SOLO en su propia pantalla al morir. Eso permitía que el primer
# jugador en morir viera "HAS MUERTO" y presionara "Reintentar"
# (_on_boton_reiniciar_pressed -> reload_current_scene) aunque el resto del
# equipo siguiera vivo y conectado -- recargando SU escena local a mitad de
# una partida de red todavía activa, lo que rompía la cámara y demás estado.
# Ahora es una RPC ("call_local", igual que las otras fases del juego) que
# solo se dispara desde revisar_todos_caidos() cuando de verdad todos
# cayeron, y llega a TODAS las pantallas a la vez: recién ahí aparece
# "HAS MUERTO" y el botón de Reintentar, para todos al mismo tiempo.
@rpc("call_local", "reliable")
func ejecutar_game_over_en_red():
	if multiplayer.is_server():
		$GeneradorZombies/TimerSpawn.stop()
		if oleada_actual > GuardadoGlobal.record_oleada:
			GuardadoGlobal.record_oleada = oleada_actual
		GuardadoGlobal.guardar_datos()

	texto_game_over.visible = true
	boton_reiniciar.visible = true

	cambiar_fase_ui(false)
	boton_iniciar.visible = false
	boton_construir.visible = false

func _on_boton_reiniciar_pressed():
	get_tree().reload_current_scene()

# ==========================================================
# 8. SISTEMA DE TIENDA Y CONSTRUCCIÓN TÁCTIL
# ==========================================================
func obtener_precio_estructura(clave_id: String) -> int:
	var datos := Balance.estructura(clave_id)
	if datos.is_empty(): return 0
	var multiplicador_cantidad = 1.0 + (construcciones_realizadas[clave_id] * float(datos["inflacion"]))
	var cantidad_jugadores = max(1, get_tree().get_nodes_in_group("jugador").size())
	var multiplicador_coop = 1.0 + ((cantidad_jugadores - 1) * float(Balance.progresion["multiplicador_precio_por_jugador"]))
	return int(datos["precio"] * multiplicador_cantidad * multiplicador_coop)

func alternar_modo_construccion():
	if fase_combate: return
	if modo_construccion:
		modo_construccion = false
		boton_construir.modulate = Color.WHITE
		holograma.visible = false
		animar_cuadricula(false)
	else:
		abrir_menu_interactivo(menu_construccion, menus.actualizar_lista_construccion)

func iniciar_colocacion_objeto(clave: String):
	modo_construccion = true
	objeto_seleccionado_tienda = clave

	boton_construir.modulate = Color(1, 0.5, 0.5)
	holograma.visible = false
	celda_previa_tocada = Vector3.INF
	animar_cuadricula(true)

func animar_cuadricula(mostrar: bool):
	if not cuadricula_visual: return
	if mostrar:
		cuadricula_visual.visible = true
		cuadricula_visual.position.y = -2.0
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(cuadricula_visual, "position:y", 0.1, 0.5)
	else:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(cuadricula_visual, "position:y", -2.0, 0.4)
		tween.tween_callback(cuadricula_visual.hide)

func construir_estructura():
	if objeto_seleccionado_tienda == "": return

	var pos_llave = Vector3(snapped(holograma.global_position.x, 0.1), 1.0, snapped(holograma.global_position.z, 0.1))

	var multiplicador_ingenieria = 1.0
	var mi_jugador = obtener_jugador_local()
	if mi_jugador and "stat_ingenieria" in mi_jugador:
		multiplicador_ingenieria = mi_jugador.stat_ingenieria

	if multiplayer.is_server():
		solicitar_construccion(objeto_seleccionado_tienda, pos_llave, holograma.global_position, multiplicador_ingenieria)
	else:
		solicitar_construccion.rpc_id(1, objeto_seleccionado_tienda, pos_llave, holograma.global_position, multiplicador_ingenieria)

	celda_previa_tocada = Vector3.INF
	holograma.visible = false
	animar_cuadricula(false)
	modo_construccion = false
	boton_construir.modulate = Color.WHITE

@rpc("any_peer", "reliable")
func solicitar_construccion(tipo: String, pos_llave: Vector3, pos_real: Vector3, mult_ing: float):
	if not multiplayer.is_server(): return

	var costo_actual = obtener_precio_estructura(tipo)
	if dinero_global < costo_actual: return
	if celdas_ocupadas.has(pos_llave): return
	# No construir encima de alguien: el jugador quedaba atrapado dentro del
	# muro (la colisión lo dejaba pegado sin poder moverse).
	if _hay_alguien_en(pos_real): return

	sumar_dinero(-costo_actual)
	ejecutar_construccion_en_red.rpc(tipo, pos_llave, pos_real, mult_ing)

@rpc("call_local", "reliable")
func ejecutar_construccion_en_red(tipo: String, pos_llave: Vector3, pos_real: Vector3, mult_ing: float):
	var nuevo_edificio = _crear_estructura(tipo, pos_real)
	if not nuevo_edificio: return
	construcciones_realizadas[tipo] += 1
	celdas_ocupadas[pos_llave] = true

	var hp_oficial = int(Balance.estructura(tipo)["hp"])
	var hp_final = int(hp_oficial * mult_ing)

	if "salud_maxima" in nuevo_edificio:
		nuevo_edificio.salud_maxima = hp_final
		nuevo_edificio.salud_actual = hp_final

	actualizar_boton_reparacion()
	celda_previa_tocada = Vector3.INF
	if objeto_seleccionado_tienda == "": return
	var costo_siguiente = obtener_precio_estructura(objeto_seleccionado_tienda)
	holograma.material_override.albedo_color = Color(0, 1, 0, 0.6) if dinero_global >= costo_siguiente else Color(1, 0, 0, 0.6)

const RADIO_LIBRE_CONSTRUCCION: float = 1.4

func _hay_alguien_en(pos: Vector3) -> bool:
	for grupo in ["jugador", "enemigos"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(n): continue
			var d := Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
			if d < RADIO_LIBRE_CONSTRUCCION: return true
	return false

func _escena_estructura(tipo: String) -> PackedScene:
	match tipo:
		"madera": return escena_madera
		"puas": return escena_puas
		"barril": return escena_barril
		"acero": return escena_acero
		"electrico": return escena_electrico
		"torreta": return escena_torreta
	return null

func _llave_celda(pos: Vector3) -> Vector3:
	return Vector3(snapped(pos.x, 0.1), 1.0, snapped(pos.z, 0.1))

# Crea la estructura con un nombre fijo según su casilla. Las estructuras
# nacen por RPC en cada pantalla (no por MultiplayerSpawner); con nombres
# automáticos cada peer le ponía uno distinto y su MultiplayerSynchronizer
# no encontraba el nodo ("Node not found").
func _crear_estructura(tipo: String, pos_real: Vector3) -> Node3D:
	var escena := _escena_estructura(tipo)
	if not escena: return null
	var llave := _llave_celda(pos_real)
	var nombre := "Estructura_%d_%d" % [roundi(llave.x * 10.0), roundi(llave.z * 10.0)]
	if has_node(nombre): return null
	var nuevo_edificio = escena.instantiate()
	nuevo_edificio.name = nombre
	if "tipo_estructura" in nuevo_edificio:
		nuevo_edificio.tipo_estructura = tipo
	add_child(nuevo_edificio)
	nuevo_edificio.global_position = pos_real
	return nuevo_edificio

# La llama EstructuraBase.destruir() en todas las pantallas: libera la casilla
# para poder volver a construir ahí (antes quedaba bloqueada para siempre).
func liberar_celda(pos: Vector3):
	celdas_ocupadas.erase(_llave_celda(pos))
	actualizar_boton_reparacion()

func _unhandled_input(event):
	if not modo_construccion or fase_combate: return

	if event is InputEventScreenTouch and event.pressed:
		var camara = get_viewport().get_camera_3d()
		if not camara: return

		var origen_rayo = camara.project_ray_origin(event.position)
		var direccion_rayo = camara.project_ray_normal(event.position)
		var punto_interseccion = Plane(Vector3.UP, 0).intersects_ray(origen_rayo, direccion_rayo)

		if punto_interseccion != null:
			var celda_tocada = Vector3(snapped(punto_interseccion.x, TAMAÑO_GRILLA), 0.0, snapped(punto_interseccion.z, TAMAÑO_GRILLA))

			if holograma.visible and celda_tocada == celda_previa_tocada:
				construir_estructura()
			else:
				holograma.global_position = celda_tocada
				holograma.visible = true
				celda_previa_tocada = celda_tocada

				if objeto_seleccionado_tienda != "" and not Balance.estructura(objeto_seleccionado_tienda).is_empty():
					var costo_actual = obtener_precio_estructura(objeto_seleccionado_tienda)
					holograma.material_override.albedo_color = Color(0, 1, 0, 0.6) if dinero_global >= costo_actual else Color(1, 0, 0, 0.6)

# ==========================================================
# 9. SISTEMA DE MENÚS (Independientes por jugador)
# ==========================================================
func _on_boton_cerrar_pressed() -> void: cerrar_menu_lateral()

func _on_boton_mochila_pressed() -> void:
	if obtener_jugador_local(): abrir_menu_interactivo(menu_armeria, menus.actualizar_lista_armeria)

func _on_boton_construir_pressed():
	alternar_modo_construccion()

func _on_boton_nivel_pressed() -> void:
	if obtener_jugador_local(): abrir_menu_interactivo(menu_nivel, menus.actualizar_lista_nivel)

func _on_boton_ensamblar_pressed() -> void:
	if obtener_jugador_local(): abrir_menu_interactivo(menu_ensamblaje, menus.actualizar_lista_ensamblaje)

func _on_boton_pausa_pressed() -> void:
	if menu_pausa: menu_pausa.alternar_pausa()

func cerrar_menu_lateral():
	if panel_lateral: panel_lateral.visible = false

func abrir_menu_interactivo(menu_activo: Control, funcion_generadora: Callable):
	if fase_combate: return
	panel_lateral.visible = true
	var todos_los_menus = [menu_armeria, menu_construccion, menu_inspector, menu_nivel, menu_ensamblaje]
	for menu in todos_los_menus:
		if is_instance_valid(menu):
			menu.visible = (menu == menu_activo)
	funcion_generadora.call()

func abrir_menu_inspector(torreta_tocada: Node3D):
	torreta_seleccionada = torreta_tocada
	abrir_menu_interactivo(menu_inspector, menus.actualizar_lista_inspector)

func _refrescar_menu_si_abierto(menu: Control, generador: Callable):
	if panel_lateral and panel_lateral.visible and is_instance_valid(menu) and menu.visible:
		generador.call()

# ==========================================================
# 10. MESA DE TRABAJO EN RED (los menús están en mundo/menus_mundo.gd)
# ==========================================================
# Antes ensamblar y mejorar cobraban con sumar_dinero(), que solo funciona
# en el servidor: para el jugador 2 era gratis, y el plano se borraba solo en
# su pantalla. Ahora el servidor valida plano y oro, cobra, y le confirma al
# jugador que lo pidió.

func arma_del_jugador(jugador, id_arma: String) -> ArmaData:
	for arma in jugador.armas_inventario:
		if arma.id == id_arma: return arma
	return null

func costo_mejora_arma(id_arma: String) -> int:
	return int(int(Balance.arma(id_arma).get("costo_ensamblaje", 0)) * 0.6)

func pedir_ensamblar(id_arma: String):
	solicitar_ensamblar.rpc_id(1, id_arma)

func pedir_mejora(id_arma: String):
	solicitar_mejora.rpc_id(1, id_arma)

func _remitente() -> int:
	var id := multiplayer.get_remote_sender_id()
	return 1 if id == 0 else id

@rpc("any_peer", "call_local", "reliable")
func solicitar_ensamblar(id_arma: String):
	if not multiplayer.is_server(): return
	var costo := int(Balance.arma(id_arma).get("costo_ensamblaje", 0))
	if not (id_arma in planos_desbloqueados) or dinero_global < costo: return
	sumar_dinero(-costo)
	quitar_plano_para_todos.rpc(id_arma)
	confirmar_ensamblaje.rpc_id(_remitente(), id_arma)

@rpc("authority", "call_local", "reliable")
func confirmar_ensamblaje(id_arma: String):
	var jugador = obtener_jugador_local()
	if not jugador: return
	var arma := Balance.crear_arma(id_arma)
	if arma: jugador.armas_inventario.append(arma)
	_refrescar_menu_si_abierto(menu_ensamblaje, menus.actualizar_lista_ensamblaje)

@rpc("any_peer", "call_local", "reliable")
func solicitar_mejora(id_arma: String):
	if not multiplayer.is_server(): return
	var costo := costo_mejora_arma(id_arma)
	if not (id_arma in planos_desbloqueados) or dinero_global < costo: return
	sumar_dinero(-costo)
	quitar_plano_para_todos.rpc(id_arma)
	confirmar_mejora.rpc_id(_remitente(), id_arma)

@rpc("authority", "call_local", "reliable")
func confirmar_mejora(id_arma: String):
	var jugador = obtener_jugador_local()
	if not jugador: return
	var arma := arma_del_jugador(jugador, id_arma)
	if not arma: return
	nivel_armas[id_arma] = nivel_armas.get(id_arma, 1) + 1
	var bono := randf_range(0.1, 0.4) + (Balance.tier_arma(id_arma) * 0.1)
	match ["dano", "cadencia", "tamano_cargador", "tiempo_recarga"].pick_random():
		"dano": arma.dano += max(1, int(arma.dano * bono))
		"cadencia": arma.cadencia += arma.cadencia * bono
		"tamano_cargador": arma.tamano_cargador += max(1, int(arma.tamano_cargador * bono))
		"tiempo_recarga": arma.tiempo_recarga = max(0.1, arma.tiempo_recarga * (1.0 - bono * 0.5))
	jugador.actualizar_ui_municion()
	_refrescar_menu_si_abierto(menu_ensamblaje, menus.actualizar_lista_ensamblaje)
