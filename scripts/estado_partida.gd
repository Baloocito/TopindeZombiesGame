extends Node

# ==========================================================
# AUTOLOAD "EstadoPartida"
# ==========================================================
# Por qué existe este archivo:
# Cuando alguien se conecta DESPUÉS de que el Host ya inició la partida,
# su árbol de nodos todavía es el de Lobby.tscn (no tiene "Mundo" ni
# "ContenedorJugadores"). Cualquier RPC que el servidor le mande apuntando
# a esos nodos falla con "Node not found", porque esos nodos todavía no
# existen en su pantalla.
#
# Un Autoload es la única cosa que existe con la MISMA ruta ("/root/EstadoPartida")
# sin importar si el jugador está viendo Lobby.tscn o Mundo.tscn. Por eso lo
# usamos como "buzón" para avisarle a un jugador tardío que debe saltar de
# escena, ANTES de que el servidor le mande nada relacionado con Mundo.
#
# CONFIGURACIÓN NECESARIA (una sola vez, en el editor):
# Project -> Project Settings -> Autoload -> Path: res://scripts/estado_partida.gd
# Node Name: EstadoPartida -> Add
#
# No hace falta tocar lobby.gd para nada de esto.

# ==========================================================
# NUEVO (Fase 1.C: Reconexión en caliente)
# ==========================================================
# El id de red que Godot te asigna (multiplayer.get_unique_id()) CAMBIA cada
# vez que te conectás -- no sirve para reconocer "este es el mismo jugador
# que se cayó hace un rato". Por eso este Autoload guarda una identidad
# propia, separada de la red:

# Token de ESTE proceso/dispositivo. Se genera UNA sola vez por lanzamiento
# del juego (mientras el proceso siga vivo, no cambia). Alcanza para
# reconexión "en caliente" (se cae la red un rato y volvés a conectarte
# desde el mismo cliente en ejecución) -- sobrevivir a que Android MATE el
# proceso del todo necesita además persistir esto en disco y reconstruir el
# resto desde el guardado de partida (Sección 0.B, todavía pendiente).
var mi_token: String = ""

# El NOMBRE del nodo (bajo ContenedorJugadores) que es "mi personaje" en la
# partida actual -- distinto de multiplayer.get_unique_id() apenas
# reconectás (tu id de red cambia, pero tu personaje sigue siendo el mismo
# nodo, con el nombre viejo). camera_3d.gd y mundo.gd usan ESTE valor, no
# multiplayer.get_unique_id(), para encontrar "mi propio jugador".
var mi_id_logico: int = -1

# ==========================================================
# NUEVO (Sala con cupo fijo): quiénes estaban en la sala al arrancar
# ==========================================================
# Solo lo usa el SERVIDOR. lobby.gd lo llena justo antes de iniciar_juego(),
# con los ids de red de todos los que ya estaban adentro cuando se llenó el
# cupo. mundo.gd lo consulta en solicitar_sincronizacion_tardia() para
# distinguir "alguien que arrancó la partida con todos los demás" (su id
# está acá, aunque su solicitud le gane de mano al spawneo inicial por pura
# carrera de red) de "un desconocido que se conectó después de que la sala
# ya se cerró" (su id NO está acá, y no tiene token de reconexión válido).
var ids_iniciales: Array = []

func _ready():
	if mi_token == "":
		mi_token = str(Time.get_ticks_usec()) + "_" + str(randi())

# El servidor le informa a cada peer (nuevo o reconectado) cuál es el nombre
# real de SU nodo de jugador bajo ContenedorJugadores.
@rpc("authority", "reliable")
func informar_id_logico(id_logico: int):
	mi_id_logico = id_logico
	print("EstadoPartida: mi id lógico de jugador es ", mi_id_logico)
	_ocultar_overlay_reconectando()

# ==========================================================
# NUEVO (Fase 1.D: Ganchos de ciclo de vida de la app)
# ==========================================================
# Puerto único de la red. lobby.gd lo lee desde aquí (EstadoPartida.PUERTO_RED),
# así que si hay que cambiarlo, se cambia SOLO en este lugar.
const PUERTO_RED = 7000

# lobby.gd nos avisa a qué IP se conectó por última vez, para poder
# reintentar solos si la conexión se cae mientras la app está en background.
var ultima_ip: String = ""
var _reconectando: bool = false
var _overlay: CanvasLayer = null
var _label_overlay: Label = null
var _overlay_generacion: int = 0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_al_perder_foco()
		NOTIFICATION_APPLICATION_RESUMED:
			_al_recuperar_foco()

func _al_perder_foco() -> void:
	if not multiplayer.has_multiplayer_peer(): return
	# A propósito NO cerramos el peer acá. Godot/el SO pueden congelar el
	# proceso solos; si lo hacen, el socket se cae de verdad y nos enteramos
	# al volver (abajo). Si nosotros lo cerráramos activamente, estaríamos
	# tratando un simple cambio de foco como un abandono voluntario.
	print("EstadoPartida: la app perdió el foco -- dejamos el peer como está.")

func _al_recuperar_foco() -> void:
	if ultima_ip == "" or _reconectando: return
	if multiplayer.has_multiplayer_peer():
		var peer_actual = multiplayer.multiplayer_peer
		if peer_actual and peer_actual.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			return # seguimos conectados, no hay nada que hacer

	print("EstadoPartida: recuperamos el foco y la conexión se cayó -- reintentando a ", ultima_ip)
	_mostrar_overlay_reconectando()
	_reconectando = true

	var nuevo_peer = ENetMultiplayerPeer.new()
	var error = nuevo_peer.create_client(ultima_ip, PUERTO_RED)
	if error != OK:
		_reconectando = false
		_ocultar_overlay_reconectando()
		return

	multiplayer.multiplayer_peer = nuevo_peer
	if not multiplayer.connected_to_server.is_connected(_on_reconexion_exitosa):
		multiplayer.connected_to_server.connect(_on_reconexion_exitosa, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_on_reconexion_fallida):
		multiplayer.connection_failed.connect(_on_reconexion_fallida, CONNECT_ONE_SHOT)

func _on_reconexion_exitosa() -> void:
	_reconectando = false
	print("EstadoPartida: reconexión automática exitosa -- esperando que el servidor nos ponga al día.")
	# El resto (avisar_partida_en_curso -> saltar a Mundo ->
	# solicitar_sincronizacion_tardia con nuestro token) ya lo dispara el
	# propio servidor al ver este peer_connected, igual que con cualquier
	# jugador tardío. El overlay se oculta en informar_id_logico, cuando el
	# servidor confirma que ya nos reconoció.

func _on_reconexion_fallida() -> void:
	_reconectando = false
	print("EstadoPartida: no se pudo reconectar automáticamente.")
	# Dejamos el overlay puesto con un aviso -- no hay a quién más
	# reintentar sin que el jugador vuelva a poner la IP a mano.
	if _label_overlay:
		_label_overlay.text = "No se pudo reconectar.\nRevisá tu conexión."

func _mostrar_overlay_reconectando() -> void:
	mostrar_overlay_texto("Reconectando…")

func _ocultar_overlay_reconectando() -> void:
	if _overlay:
		_overlay.visible = false

# ==========================================================
# NUEVO: overlay genérico reutilizable
# ==========================================================
# Mismo overlay que ya usábamos solo para "Reconectando…", pero con texto
# configurable. mundo.gd lo usa mientras un jugador (nuevo o reconectado)
# espera a que el servidor lo ponga al día -- antes esa espera se veía como
# pantalla congelada / personaje invisible que no responde, que es
# exactamente lo que se reportó como bug. Se oculta solo, en
# informar_id_logico(), apenas el servidor confirma que ya está sincronizado.
func mostrar_overlay_texto(texto: String) -> void:
	if not _overlay:
		_overlay = CanvasLayer.new()
		_overlay.layer = 100
		var fondo = ColorRect.new()
		fondo.color = Color(0, 0, 0, 0.75)
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.add_child(fondo)
		_label_overlay = Label.new()
		_label_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label_overlay.add_theme_font_size_override("font_size", 32)
		_label_overlay.add_theme_color_override("font_color", Color.WHITE)
		_overlay.add_child(_label_overlay)
		get_tree().root.add_child(_overlay)
	_label_overlay.text = texto
	_overlay.visible = true

	# --- FIX: red de seguridad contra un overlay pegado para siempre ---
	# Ya arreglamos la causa real (mundo.gd ahora avisa el id lógico por su
	# cuenta, push, sin depender de una carrera de red). Pero un overlay que
	# tapa toda la pantalla y bloquea los clics es tan grave si se traba que
	# vale la pena un segundo seguro: si nadie lo oculta en 8 segundos, se
	# oculta solo. Usamos un número de "generación" para no ocultar por
	# error un overlay que se volvió a mostrar por otro motivo mientras
	# tanto (por ejemplo, sincronización -> reconexión en el mismo ratito).
	_overlay_generacion += 1
	var mi_generacion = _overlay_generacion
	get_tree().create_timer(8.0).timeout.connect(func():
		if _overlay_generacion == mi_generacion and _overlay:
			_overlay.visible = false
	)

@rpc("authority", "call_local", "reliable")
func avisar_partida_en_curso():
	# Si ya estoy en Mundo (por ejemplo soy el propio servidor, o ya cargué
	# la escena por otra vía), no hacemos nada.
	var escena_actual = get_tree().current_scene
	if escena_actual and escena_actual.scene_file_path == "res://scenes/mundo.tscn":
		return

	print("EstadoPartida: la partida ya está en curso, saltando directo a Mundo.")
	get_tree().change_scene_to_file("res://scenes/mundo.tscn")
