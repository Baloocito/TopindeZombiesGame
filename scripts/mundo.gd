extends Node3D

# ==========================================================
# 1. BASES DE DATOS Y CONSTANTES (Configuración estática)
# ==========================================================
const TAMAÑO_GRILLA: float = 2.0

var bd_armas = {
	"pistola": {"nombre": "Pistola 9mm", "tier": 1, "costo_ensamblaje": 0},
	"escopeta": {"nombre": "Escopeta Vieja", "tier": 1, "costo_ensamblaje": 400},
	"smg": {"nombre": "SMG Viper", "tier": 2, "costo_ensamblaje": 1200},
	"rifle_caza": {"nombre": "Rifle de Caza", "tier": 2, "costo_ensamblaje": 1200},
	"lanzallamas": {"nombre": "Lanzallamas", "tier": 3, "costo_ensamblaje": 2500},
	"ballesta": {"nombre": "Ballesta Expl.", "tier": 3, "costo_ensamblaje": 2500},
	"clavos": {"nombre": "Rifle de Clavos", "tier": 3, "costo_ensamblaje": 2500},
	"minigun": {"nombre": "Minigun", "tier": 4, "costo_ensamblaje": 5000},
	"riel": {"nombre": "Cañón de Riel", "tier": 4, "costo_ensamblaje": 5000},
	"lanzagranadas": {"nombre": "Lanzagranadas", "tier": 4, "costo_ensamblaje": 5000}
}
var arma_inspeccionada = null
var datos_estructuras = {
	"madera": {"nombre": "Valla Madera", "precio": 150, "inflacion": 0.10, "hp": 500},
	"puas": {"nombre": "Alambre Púas", "precio": 300, "inflacion": 0.15, "hp": 300},
	"barril": {"nombre": "Barril Explosivo", "precio": 250, "inflacion": 0.0, "hp": 1},
	"acero": {"nombre": "Barrera Acero", "precio": 600, "inflacion": 0.20, "hp": 2000},
	"electrico": {"nombre": "Muro Eléctrico", "precio": 1000, "inflacion": 0.25, "hp": 1200},
	"torreta": {"nombre": "Base Torreta", "precio": 1500, "inflacion": 0.30, "hp": 800}
}

# ==========================================================
# 2. ESTADO GLOBAL DEL JUEGO
# ==========================================================
var modo_construccion: bool = false
var fase_combate: bool = false
var oleada_actual: int = 1
var zombies_vivos: int = 0
var zombies_asesinados_partida: int = 0
var dinero_global: int = 10000
var reparaciones_usadas: int = 0
var modificador_suerte: float = 0.0

# ¡NUEVO! DICCIONARIO DE VOTACIÓN PARA INICIAR LA NOCHE
var jugadores_listos: Dictionary = {}

var planos_desbloqueados: Array[String] = []
var tienda_rotacion_actual: Array[String] = []
var nivel_armas = {
	"pistola": 1, "escopeta": 1, "smg": 1, "rifle_caza": 1,
	"lanzallamas": 1, "ballesta": 1, "clavos": 1,
	"minigun": 1, "riel": 1, "lanzagranadas": 1
}

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
	if get_node_or_null("ContenedorJugadores/%s" % str(id_jugador)):
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
	var escena_a_crear = null
	match tipo:
		"madera": escena_a_crear = escena_madera
		"puas": escena_a_crear = escena_puas
		"barril": escena_a_crear = escena_barril
		"acero": escena_a_crear = escena_acero
		"electrico": escena_a_crear = escena_electrico
		"torreta": escena_a_crear = escena_torreta

	if not escena_a_crear: return

	var nuevo_edificio = escena_a_crear.instantiate()
	if "tipo_estructura" in nuevo_edificio:
		nuevo_edificio.tipo_estructura = tipo

	add_child(nuevo_edificio)
	nuevo_edificio.global_position = pos_real

	if "salud_maxima" in nuevo_edificio:
		nuevo_edificio.salud_maxima = salud_maxima_real
		nuevo_edificio.salud_actual = salud_actual_real

# ==========================================================
# 4. INICIALIZACIÓN
# ==========================================================
func _ready():
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
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
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

	if oleada_actual > 1:
		var bono_supervivencia = 100 * (oleada_actual - 1)
		repartir_experiencia_global(bono_supervivencia)

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
	if not (id_arma in bd_armas): return
	planos_desbloqueados.append(id_arma)
	print("¡PLANO RECOGIDO!: ", bd_armas[id_arma].nombre)

@rpc("authority", "call_local", "reliable")
func actualizar_dinero_para_todos(nuevo_valor: int):
	dinero_global = nuevo_valor
	if texto_dinero: texto_dinero.text = str(dinero_global) + "G"
	actualizar_boton_reparacion()

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
			var precio_mercado = obtener_precio_estructura("madera")
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
		boton_reparar.text = "Reparar Todo ($" + str(costo) + ")"
		boton_reparar.disabled = (dinero_global < costo or usos_restantes <= 0)

# ¡NUEVO! Sincronizado para red
func ejecutar_reparacion_global():
	var costo = obtener_costo_reparacion()
	if costo == 0 or dinero_global < costo or reparaciones_usadas >= 1: return

	# Enviamos la petición al servidor si somos cliente
	if not multiplayer.is_server():
		solicitar_reparacion_servidor.rpc_id(1)
	else:
		solicitar_reparacion_servidor()

@rpc("any_peer", "reliable")
func solicitar_reparacion_servidor():
	if not multiplayer.is_server(): return
	var costo = obtener_costo_reparacion()
	if dinero_global >= costo and reparaciones_usadas < 1:
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
func spawn_loot(pos_muerte: Vector3, tipo_zombie: String):
	if not multiplayer.is_server(): return # Blindaje total

	var bounty: int = 0; var oro_base: int = 0; var xp_ganada: int = 0
	match tipo_zombie:
		"basico": bounty = 10; oro_base = 25; xp_ganada = 5
		"corredor": bounty = 15; oro_base = 45; xp_ganada = 10
		"explosivo": bounty = 20; oro_base = 70; xp_ganada = 20
		"tanque": bounty = 50; oro_base = 150; xp_ganada = 50
		"boss": bounty = 500; oro_base = 2000; xp_ganada = 1000

	sumar_dinero(bounty)
	repartir_experiencia_global(xp_ganada)

	var es_elite = (tipo_zombie == "tanque" or tipo_zombie == "boss")
	var solto_algo: bool = false
	var dado_loot = randf_range(1.0, 100.0) + modificador_suerte

	var umbral_municion = 61.0
	var umbral_botiquin = 86.0
	var umbral_plano = 96.0

	var jugador_base = get_node_or_null("ContenedorJugadores/1")

	# --- FIX (revisión de código) ---
	# Antes esto era "if ... elif ...": el primer if comprobaba si las
	# PROPIEDADES existían en el objeto (siempre true), no si la salud
	# estaba baja, así que el elif de "poca munición" nunca se evaluaba.
	# Ahora son dos "if" independientes, cada uno con su propia condición real.
	if jugador_base:
		if "salud_actual" in jugador_base and "stat_salud_maxima" in jugador_base:
			if jugador_base.salud_actual <= (jugador_base.stat_salud_maxima * 0.3):
				umbral_botiquin = 60.0
				umbral_municion = 96.0

		if jugador_base.arma_actual:
			var tipo_balas = jugador_base.arma_actual.tipo_municion
			var reserva = jugador_base.municion_reserva.get(tipo_balas, 0)
			if reserva <= jugador_base.arma_actual.tamano_cargador:
				umbral_municion = 40.0

	if (dado_loot >= umbral_municion and dado_loot < umbral_botiquin) and not es_elite:
		if caja_municion_escena:
			var caja = caja_municion_escena.instantiate()
			# --- FIX (bug real, confirmado con Mundo.tscn) ---
			# Era "get_parent().add_child(...)". Esta función vive en el
			# propio script de Mundo, así que "get_parent()" ahí es el PADRE
			# de Mundo (la raíz de la escena) -- el objeto se agregaba como
			# HERMANO de Mundo, no como hijo. SpawnerEntidades (el
			# MultiplayerSpawner que replica el loot) tiene spawn_path=".."
			# relativo a SÍ MISMO, o sea vigila los hijos directos de Mundo
			# (su propio padre) -- nunca vigiló fuera de ahí. Resultado: la
			# caja nunca se replicaba a NINGÚN cliente, nunca, para nadie
			# (el Host la veía igual porque la crea localmente). Con
			# add_child() simple (self = Mundo) queda donde SpawnerEntidades
			# sí la ve, force_readable_name igual que antes.
			add_child(caja, true)
			caja.global_position = pos_muerte + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			if jugador_base and jugador_base.arma_actual:
				# --- FIX (revisión de código) ---
				# Comparaba contra "ligera" (minúscula) pero el enum real de
				# ArmaData.tipo_municion es "Ligera" (con mayúscula inicial),
				# así que esta condición nunca era true y el multiplicador
				# de munición ligera siempre caía en el else (2), nunca en 3.
				var multiplicador = 3 if jugador_base.arma_actual.tipo_municion == "Ligera" else 2
				var cantidad = jugador_base.arma_actual.tamano_cargador * multiplicador
				if caja.has_method("configurar"): caja.configurar(jugador_base.arma_actual.tipo_municion, cantidad)
			solto_algo = true

	elif (dado_loot >= umbral_botiquin and dado_loot < umbral_plano) and not es_elite:
		if botiquin_escena:
			var botiquin = botiquin_escena.instantiate()
			# --- FIX: mismo bug que la caja de munición, ver comentario arriba ---
			add_child(botiquin, true)
			botiquin.global_position = pos_muerte + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			solto_algo = true

	elif dado_loot >= umbral_plano or es_elite:
		if plano_arma_escena:
			solto_algo = true
			var plano = plano_arma_escena.instantiate()
			# --- FIX: mismo bug que la caja de munición, ver comentario arriba ---
			add_child(plano, true)
			plano.global_position = pos_muerte + Vector3(0, 0.5, 0)

			var nivel_jugador = 1
			if jugador_base: nivel_jugador = jugador_base.nivel

			var tier_maximo = 2
			if nivel_jugador >= 20: tier_maximo = 4
			elif nivel_jugador >= 10: tier_maximo = 3

			if plano.has_method("generar_plano"):
				plano.generar_plano(tier_maximo, es_elite)

	modificador_suerte = 0.0 if solto_algo else modificador_suerte + 0.5

	var variacion_dinero = randf_range(0.8, 1.2)
	var oro_final = int((oro_base * variacion_dinero) * (1.0 + (0.15 * (oleada_actual - 1))))

	if moneda_escena and oro_final > 0:
		var moneda = moneda_escena.instantiate()
		# --- FIX: mismo bug que la caja de munición, ver comentario arriba ---
		add_child(moneda, true)
		moneda.global_position = pos_muerte + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		moneda.valor_oro = oro_final

func generar_chatarra(posicion_destruccion: Vector3):
	if not multiplayer.is_server(): return
	if moneda_escena:
		var chatarra = moneda_escena.instantiate()
		add_child(chatarra, true)
		chatarra.global_position = posicion_destruccion
		chatarra.valor_oro = 20

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
	var datos = datos_estructuras[clave_id]
	var multiplicador_cantidad = 1.0 + (construcciones_realizadas[clave_id] * datos["inflacion"])
	var cantidad_jugadores = max(1, get_tree().get_nodes_in_group("jugador").size())
	var multiplicador_coop = 1.0 + ((cantidad_jugadores - 1) * 0.25)
	return int(datos["precio"] * multiplicador_cantidad * multiplicador_coop)

func alternar_modo_construccion():
	if fase_combate: return
	if modo_construccion:
		modo_construccion = false
		boton_construir.modulate = Color.WHITE
		holograma.visible = false
		animar_cuadricula(false)
	else:
		abrir_menu_interactivo(menu_construccion, actualizar_lista_construccion)

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

	sumar_dinero(-costo_actual)
	ejecutar_construccion_en_red.rpc(tipo, pos_llave, pos_real, mult_ing)

@rpc("call_local", "reliable")
func ejecutar_construccion_en_red(tipo: String, pos_llave: Vector3, pos_real: Vector3, mult_ing: float):
	var escena_a_crear = null
	match tipo:
		"madera": escena_a_crear = escena_madera
		"puas": escena_a_crear = escena_puas
		"barril": escena_a_crear = escena_barril
		"acero": escena_a_crear = escena_acero
		"electrico": escena_a_crear = escena_electrico
		"torreta": escena_a_crear = escena_torreta

	if not escena_a_crear: return

	construcciones_realizadas[tipo] += 1

	var nuevo_edificio = escena_a_crear.instantiate()
	if "tipo_estructura" in nuevo_edificio:
		nuevo_edificio.tipo_estructura = tipo

	add_child(nuevo_edificio)
	nuevo_edificio.global_position = pos_real
	celdas_ocupadas[pos_llave] = true

	var hp_oficial = datos_estructuras[tipo]["hp"]
	var hp_final = int(hp_oficial * mult_ing)

	if "salud_maxima" in nuevo_edificio:
		nuevo_edificio.salud_maxima = hp_final
		nuevo_edificio.salud_actual = hp_final

	actualizar_boton_reparacion()
	celda_previa_tocada = Vector3.INF
	var costo_siguiente = obtener_precio_estructura(objeto_seleccionado_tienda)
	holograma.material_override.albedo_color = Color(0, 1, 0, 0.6) if dinero_global >= costo_siguiente else Color(1, 0, 0, 0.6)

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

				if objeto_seleccionado_tienda != "" and datos_estructuras.has(objeto_seleccionado_tienda):
					var costo_actual = obtener_precio_estructura(objeto_seleccionado_tienda)
					holograma.material_override.albedo_color = Color(0, 1, 0, 0.6) if dinero_global >= costo_actual else Color(1, 0, 0, 0.6)

# ==========================================================
# 9. SISTEMA DE MENÚS (Independientes por jugador)
# ==========================================================
func _on_boton_cerrar_pressed() -> void: cerrar_menu_lateral()

func _on_boton_mochila_pressed() -> void:
	if obtener_jugador_local(): abrir_menu_interactivo(menu_armeria, actualizar_lista_armeria)

func _on_boton_construir_pressed():
	alternar_modo_construccion()

func _on_boton_nivel_pressed() -> void:
	if obtener_jugador_local(): abrir_menu_interactivo(menu_nivel, actualizar_lista_nivel)

func _on_boton_ensamblar_pressed() -> void:
	if obtener_jugador_local(): abrir_menu_interactivo(menu_ensamblaje, actualizar_lista_ensamblaje)

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
	abrir_menu_interactivo(menu_inspector, actualizar_lista_inspector)

# ==========================================================
# 10. GENERADORES DE INTERFAZ DE MENÚS
# ==========================================================
func actualizar_lista_armeria():
	for hijo in menu_armeria.get_children(): hijo.queue_free()
	var mi_jugador = obtener_jugador_local()
	if not mi_jugador: return

	var titulo = Label.new()
	titulo.text = "ARMARIO TÁCTICO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	menu_armeria.add_child(titulo)

	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15)
	menu_armeria.add_child(separador)

	for arma in mi_jugador.armas_inventario:
		var fila = HBoxContainer.new()
		var btn_nombre = Button.new()
		var prefijo = "▼ " if arma_inspeccionada == arma else "▶ "
		btn_nombre.text = prefijo + arma.nombre
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
			if mi_jugador.armas_equipadas[i] == arma:
				btn_slot.modulate = Color(0.2, 1, 0.2)

			btn_slot.pressed.connect(func():
				mi_jugador.equipar_en_slot(arma, i)
				if mi_jugador.slot_actual == i: mi_jugador.cambiar_arma(i)
				actualizar_lista_armeria()
			)
			caja_slots.add_child(btn_slot)

		fila.add_child(caja_slots)
		menu_armeria.add_child(fila)

		if arma_inspeccionada == arma:
			var panel_stats = PanelContainer.new()
			var vbox_stats = VBoxContainer.new()
			panel_stats.add_child(vbox_stats)

			var rect_img = ColorRect.new()
			rect_img.custom_minimum_size = Vector2(0, 80)
			rect_img.color = Color(0.15, 0.15, 0.15)

			var lbl_img = Label.new()
			lbl_img.text = "[ ESPACIO PARA ICONO TOON ]"
			lbl_img.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_img.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl_img.set_anchors_preset(Control.PRESET_FULL_RECT)

			rect_img.add_child(lbl_img)
			vbox_stats.add_child(rect_img)

			var lbl_datos = Label.new()
			lbl_datos.text = "Daño: %d\nCadencia: %.1f bps\nCargador: %d balas\nRecarga: %.2f s" % [arma.dano, arma.cadencia, arma.tamano_cargador, arma.tiempo_recarga]
			lbl_datos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_datos.modulate = Color(0.7, 1.0, 1.0)
			vbox_stats.add_child(lbl_datos)

			menu_armeria.add_child(panel_stats)

		var espacio = Control.new()
		espacio.custom_minimum_size = Vector2(0, 10)
		menu_armeria.add_child(espacio)

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
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if dinero_global < costo_actual:
			btn.disabled = true
			btn.modulate = Color(1, 0.5, 0.5)

		btn.pressed.connect(func():
			iniciar_colocacion_objeto(clave)
			cerrar_menu_lateral()
		)
		menu_construccion.add_child(btn)

func actualizar_lista_inspector():
	for hijo in menu_inspector.get_children(): hijo.queue_free()
	if not is_instance_valid(torreta_seleccionada):
		cerrar_menu_lateral()
		return

	var mi_jugador = obtener_jugador_local()
	if not mi_jugador: return

	var titulo = Label.new()
	titulo.text = "CENTINELA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	menu_inspector.add_child(titulo)

	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15)
	menu_inspector.add_child(separador)

	var lbl_estado = Label.new()
	var nombre_arma = torreta_seleccionada.arma_equipada.nombre if torreta_seleccionada.arma_equipada else "Ninguna"
	lbl_estado.text = "Salud: %s\nArma: %s\nBalas: %s" % [torreta_seleccionada.salud_actual, nombre_arma, torreta_seleccionada.balas_cargadas]
	lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_inspector.add_child(lbl_estado)

	var separador2 = HSeparator.new()
	separador2.add_theme_constant_override("separation", 15)
	menu_inspector.add_child(separador2)

	if torreta_seleccionada.arma_equipada != null:
		var tipo_municion = torreta_seleccionada.arma_equipada.tipo_municion
		var reserva_jugador = mi_jugador.municion_reserva.get(tipo_municion, 0)
		var btn_recargar = Button.new()
		btn_recargar.text = "Dar 30 Balas %s\n(Tu reserva: %s)" % [tipo_municion, reserva_jugador]
		btn_recargar.custom_minimum_size = Vector2(0, 50)
		btn_recargar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if reserva_jugador < 30: btn_recargar.disabled = true

		btn_recargar.pressed.connect(func():
			mi_jugador.municion_reserva[tipo_municion] -= 30
			torreta_seleccionada.balas_cargadas += 30
			mi_jugador.actualizar_ui_municion()
			actualizar_lista_inspector()
		)
		menu_inspector.add_child(btn_recargar)
	else:
		var lbl_aviso = Label.new()
		lbl_aviso.text = "\n[Instala un arma para cargar balas]"
		lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_aviso.modulate = Color(0.7, 0.7, 0.7)
		menu_inspector.add_child(lbl_aviso)

	var subtitulo_armas = Label.new()
	subtitulo_armas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_inspector.add_child(subtitulo_armas)

	if torreta_seleccionada.arma_equipada == null:
		subtitulo_armas.text = "\n-- INSTALAR ARMA --"
		for arma in mi_jugador.armas_inventario:
			var btn_arma = Button.new()
			btn_arma.text = "Instalar " + arma.nombre
			btn_arma.custom_minimum_size = Vector2(0, 40)
			btn_arma.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			btn_arma.pressed.connect(func():
				torreta_seleccionada.arma_equipada = arma.duplicate()
				if arma.nombre != "Pistola 9mm":
					mi_jugador.armas_inventario.erase(arma)
					for i in range(3):
						if mi_jugador.armas_equipadas[i] == arma:
							mi_jugador.armas_equipadas[i] = null
							if mi_jugador.slot_actual == i:
								mi_jugador.arma_actual = null
								mi_jugador.actualizar_ui_municion()
								mi_jugador.ciclo_arma_rapido()
				actualizar_lista_inspector()
			)
			menu_inspector.add_child(btn_arma)
	else:
		subtitulo_armas.text = "\n-- RECUPERAR ARMA --"
		var btn_recuperar = Button.new()
		btn_recuperar.text = "Desinstalar " + torreta_seleccionada.arma_equipada.nombre
		btn_recuperar.custom_minimum_size = Vector2(0, 40)
		btn_recuperar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		btn_recuperar.pressed.connect(func():
			if torreta_seleccionada.balas_cargadas > 0:
				var tipo_bala = torreta_seleccionada.arma_equipada.tipo_municion
				mi_jugador.municion_reserva[tipo_bala] += torreta_seleccionada.balas_cargadas
				torreta_seleccionada.balas_cargadas = 0
				mi_jugador.actualizar_ui_municion()

			if torreta_seleccionada.arma_equipada.nombre != "Pistola 9mm":
				mi_jugador.armas_inventario.append(torreta_seleccionada.arma_equipada)

			torreta_seleccionada.arma_equipada = null
			actualizar_lista_inspector()
		)
		menu_inspector.add_child(btn_recuperar)

func actualizar_lista_nivel():
	for hijo in menu_nivel.get_children(): hijo.queue_free()
	var mi_jugador = obtener_jugador_local()
	if not mi_jugador: return

	var titulo = Label.new()
	titulo.text = "ATRIBUTOS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	menu_nivel.add_child(titulo)

	var lbl_puntos = Label.new()
	lbl_puntos.text = "Puntos Disponibles: " + str(mi_jugador.puntos_mejora)
	lbl_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mi_jugador.puntos_mejora > 0: lbl_puntos.modulate = Color(1, 1, 0)
	menu_nivel.add_child(lbl_puntos)

	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15)
	menu_nivel.add_child(separador)

	var stats_ui = [
		{"id": "salud", "nombre": "Salud Máxima", "valor": str(mi_jugador.stat_salud_maxima) + " HP"},
		{"id": "agilidad", "nombre": "Agilidad", "valor": str(mi_jugador.stat_agilidad).pad_decimals(1) + " m/s"},
		{"id": "destreza", "nombre": "Destreza", "valor": str(int(mi_jugador.stat_destreza * 100)) + "%"},
		{"id": "ingenieria", "nombre": "Ingeniería", "valor": "x" + str(mi_jugador.stat_ingenieria).pad_decimals(1)},
		{"id": "recoleccion", "nombre": "Imán de Oro", "valor": str(mi_jugador.stat_recoleccion).pad_decimals(1) + " m"}
	]

	for stat in stats_ui:
		var fila = HBoxContainer.new()
		fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl_stat = Label.new()
		lbl_stat.text = stat["nombre"] + "\n" + stat["valor"]
		lbl_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(lbl_stat)

		var btn_mejorar = Button.new()
		btn_mejorar.text = " + "
		btn_mejorar.custom_minimum_size = Vector2(50, 50)
		if mi_jugador.puntos_mejora <= 0: btn_mejorar.disabled = true

		btn_mejorar.pressed.connect(func():
			mi_jugador.mejorar_estadistica(stat["id"])
			actualizar_lista_nivel()
		)
		fila.add_child(btn_mejorar)
		menu_nivel.add_child(fila)
		var espacio = Control.new()
		espacio.custom_minimum_size = Vector2(0, 5)
		menu_nivel.add_child(espacio)

func actualizar_lista_ensamblaje():
	for hijo in menu_ensamblaje.get_children(): hijo.queue_free()

	var mi_jugador = obtener_jugador_local()
	if not mi_jugador: return

	var titulo = Label.new()
	titulo.text = "MESA DE TRABAJO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	menu_ensamblaje.add_child(titulo)

	var separador = HSeparator.new()
	separador.add_theme_constant_override("separation", 15)
	menu_ensamblaje.add_child(separador)

	if planos_desbloqueados.is_empty():
		var lbl_vacio = Label.new()
		lbl_vacio.text = "No tienes planos.\n¡Explora y caza Jefes!"
		lbl_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_vacio.modulate = Color(0.7, 0.7, 0.7)
		menu_ensamblaje.add_child(lbl_vacio)
		return

	var conteo_planos = {}
	for p in planos_desbloqueados:
		conteo_planos[p] = conteo_planos.get(p, 0) + 1

	for clave in conteo_planos.keys():
		var cantidad = conteo_planos[clave]
		var datos = bd_armas[clave]
		var lvl_actual = nivel_armas[clave]
		var costo_ensamblar = datos["costo_ensamblaje"]
		var costo_mejorar = int(costo_ensamblar * 0.6)

		var arma_poseida = null
		for arma in mi_jugador.armas_inventario:
			if arma.nombre == datos["nombre"]:
				arma_poseida = arma
				break

		var lbl_info = Label.new()
		var texto_info = "► " + datos["nombre"] + " (x" + str(cantidad) + " Planos)\n"

		if arma_poseida:
			texto_info += "Nivel: " + str(lvl_actual) + " | Daño: " + str(arma_poseida.dano)
		else:
			texto_info += "Estado: No Ensamblada"

		lbl_info.text = texto_info
		menu_ensamblaje.add_child(lbl_info)

		var fila_botones = HBoxContainer.new()
		fila_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if not arma_poseida:
			var btn_crear = Button.new()
			btn_crear.text = "Ensamblar\n$" + str(costo_ensamblar)
			btn_crear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_crear.custom_minimum_size = Vector2(0, 50)
			btn_crear.modulate = Color(0.5, 1.0, 0.5)
			if dinero_global < costo_ensamblar: btn_crear.disabled = true

			btn_crear.pressed.connect(func():
				sumar_dinero(-costo_ensamblar)
				var ruta_arma = "res://materials/" + clave + ".tres"
				var nueva_arma = load(ruta_arma)
				if nueva_arma:
					var arma_clonada = nueva_arma.duplicate()
					mi_jugador.armas_inventario.append(arma_clonada)
					planos_desbloqueados.erase(clave)
					actualizar_lista_ensamblaje()
			)
			fila_botones.add_child(btn_crear)

		else:
			var btn_mejorar = Button.new()
			btn_mejorar.text = "Forjar Mejora Aleatoria\n$" + str(costo_mejorar)
			btn_mejorar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_mejorar.custom_minimum_size = Vector2(0, 50)
			btn_mejorar.modulate = Color(0.4, 0.8, 1.0)
			if dinero_global < costo_mejorar: btn_mejorar.disabled = true

			btn_mejorar.pressed.connect(func():
				sumar_dinero(-costo_mejorar)
				nivel_armas[clave] += 1
				planos_desbloqueados.erase(clave)

				var stats_posibles = ["dano", "cadencia", "tamano_cargador", "tiempo_recarga"]
				var stat_elegida = stats_posibles.pick_random()
				var bono_rng = randf_range(0.1, 0.4) + (datos["tier"] * 0.1)

				match stat_elegida:
					"dano":
						arma_poseida.dano += max(1, int(arma_poseida.dano * bono_rng))
					"cadencia":
						arma_poseida.cadencia += (arma_poseida.cadencia * bono_rng)
					"tamano_cargador":
						arma_poseida.tamano_cargador += max(1, int(arma_poseida.tamano_cargador * bono_rng))
					"tiempo_recarga":
						arma_poseida.tiempo_recarga = max(0.1, arma_poseida.tiempo_recarga - (arma_poseida.tiempo_recarga * (bono_rng * 0.5)))

				mi_jugador.actualizar_ui_municion()
				actualizar_lista_ensamblaje()
			)
			fila_botones.add_child(btn_mejorar)

		menu_ensamblaje.add_child(fila_botones)

		var espacio = Control.new()
		espacio.custom_minimum_size = Vector2(0, 15)
		menu_ensamblaje.add_child(espacio)
