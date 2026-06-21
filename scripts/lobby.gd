extends Control

# Puerto de red
const PORT = 7000
const MAX_CLIENTS = 3 

var peer = ENetMultiplayerPeer.new()

# ¡NUEVO! Nuestro diccionario de jugadores en la sala
var jugadores_conectados = {}

# Referencias a tus nodos (¡Ajustadas a tu imagen!)
@onready var btn_host = $VBoxContainer/BtnHost
@onready var btn_unirse = $VBoxContainer/BtnUnirse
@onready var input_ip = $VBoxContainer/InputIP
@onready var lista_jugadores = $VBoxContainer/ListaJugadores
@onready var boton_iniciar = $VBoxContainer/BotonIniciarJuego

func _ready():
	# Escondemos el botón de iniciar partida por defecto
	boton_iniciar.hide()
	
	# Conectamos las señales nativas de red de Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_conectado_al_servidor)
	multiplayer.connection_failed.connect(_on_falla_de_conexion)

# ==========================================
# BOTONES DE CONEXIÓN
# ==========================================
func _on_btn_host_pressed():
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		print("Error al crear el Host: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	print("¡Servidor Host creado! Esperando a los muchachos...")
	
	# EL HOST SE REGISTRA A SÍ MISMO (El Host SIEMPRE es el ID 1)
	registrar_jugador(1, "Superviviente 1 (Host)")
	
	# El Host es el jefe, así que él sí puede ver el botón de Iniciar
	boton_iniciar.show()
	
	# Escondemos los botones de conexión
	esconder_menu_conexion()

func _on_btn_unirse_pressed():
	var ip = input_ip.text
	if ip == "":
		ip = "127.0.0.1" 
		
	var error = peer.create_client(ip, PORT)
	if error != OK:
		print("Error al configurar el cliente: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	print("Conectando a la IP: ", ip, "...")
	esconder_menu_conexion()

func esconder_menu_conexion():
	btn_host.hide()
	btn_unirse.hide()
	input_ip.hide()

# ==========================================
# MAGIA DEL LOBBY MULTIJUGADOR (RPCs)
# ==========================================

# Cuando alguien se conecta a la sala
func _on_peer_connected(id):
	print("¡Nuevo jugador en la sala! ID: ", id)
	# Me presento enviando mi nombre al jugador que acaba de entrar
	registrar_jugador.rpc_id(id, multiplayer.get_unique_id(), "Superviviente " + str(multiplayer.get_unique_id()))

# Cuando alguien se va o se cae de la sala
func _on_peer_disconnected(id):
	print("Jugador desconectado: ", id)
	jugadores_conectados.erase(id)
	actualizar_ui_lobby()

# Cuando YO (como cliente) logro entrar a la sala del Host
func _on_conectado_al_servidor():
	print("¡Conectado con éxito al Host!")
	# Me registro a mí mismo en mi propia pantalla
	var mi_id = multiplayer.get_unique_id()
	registrar_jugador(mi_id, "Superviviente " + str(mi_id))

# Si la conexión falla
func _on_falla_de_conexion():
	print("Error de conexión. ¿El Host está activo?")
	# Volvemos a mostrar los botones
	btn_host.show()
	btn_unirse.show()
	input_ip.show()

# ESTA FUNCIÓN SE EJECUTA A TRAVÉS DE LA RED ("any_peer")
@rpc("any_peer", "reliable")
func registrar_jugador(nuevo_id: int, nombre_jugador: String):
	jugadores_conectados[nuevo_id] = nombre_jugador
	actualizar_ui_lobby()
	
	# Si soy el Host, me encargo de pasarle la lista completa a los nuevos
	if multiplayer.is_server():
		for id_existente in jugadores_conectados:
			if id_existente != nuevo_id:
				registrar_jugador.rpc_id(nuevo_id, id_existente, jugadores_conectados[id_existente])

# Refresca el ItemList de la pantalla
func actualizar_ui_lobby():
	lista_jugadores.clear()
	for id in jugadores_conectados:
		lista_jugadores.add_item(jugadores_conectados[id])

# ==========================================
# TRANSICIÓN AL MAPA DE JUEGO
# ==========================================

# --- ¡OJO! CONECTA EL BOTÓN "BotonIniciarJuego" A ESTA FUNCIÓN ---
func _on_boton_iniciar_juego_pressed():
	# El Host le dice a TODOS (incluyéndose a sí mismo) que el juego va a empezar
	iniciar_juego.rpc()

# Esta función se ejecuta al mismo tiempo en las pantallas de TODOS los jugadores
@rpc("call_local", "reliable")
func iniciar_juego():
	hide() # Escondemos el menú de lobby
	print("¡INICIANDO PARTIDA CON ", jugadores_conectados.size(), " JUGADORES!")
	
	# ¡EL SALTO AL MUNDO! 
	# Usamos la misma ruta que tenías en tu menú principal original
	get_tree().change_scene_to_file("res://scenes/mundo.tscn")
