extends CharacterBody3D

# ==========================================================
# 1. SISTEMA RPG Y ESTADÍSTICAS (GDD OFICIAL)
# ==========================================================
@export_category("Configuración RPG")
var nivel: int = 1
var experiencia_actual: int = 0
var puntos_mejora: int = 0

var stat_salud_maxima: int = 100
# --- FIX (revisión de código) ---
# Antes esta variable no tenía valor por defecto y solo se asignaba dentro
# del bloque "if is_multiplayer_authority()" en _ready(). Eso significa que
# la copia que el SERVIDOR tiene de un jugador INVITADO (donde el servidor
# no es la autoridad de ese nodo) nunca ejecutaba esa línea, y salud_actual
# se quedaba en 0 para siempre en esa copia. zombie.gd filtra objetivos con
# "jug.salud_actual > 0", así que el servidor descartaba al invitado como
# presa válida: los zombies nunca lo detectaban ni lo perseguían. Con un
# valor inicial > 0 aquí, y reforzado en _ready() (ver abajo, ya sin el
# candado de autoridad), el servidor siempre ve una salud coherente.
var salud_actual: int = 100

# --- NUEVO: SISTEMA DE "DERRIBADO" / REANIMACIÓN ---
# En vez de Game Over individual al llegar a 0 de vida, el jugador queda
# "derribado" (fuera de combate, no puede moverse ni disparar) hasta que:
#  a) un compañero vivo lo reanima acercándose, o
#  b) la oleada termina con al menos un jugador en pie (revive a todos).
# Solo si TODOS los jugadores quedan derribados a la vez se dispara el
# Game Over real (ver mundo.gd: revisar_todos_caidos()).
var esta_caido: bool = false
var temporizador_reanimacion: float = 0.0
const RADIO_REANIMACION: float = 2.0
const TIEMPO_REANIMACION: float = 3.0

var stat_agilidad: float = 4.0
var stat_destreza: float = 1.0       # Multiplicador de velocidad de recarga
var stat_ingenieria: float = 1.0     # Multiplicador de HP para estructuras/torretas
var stat_recoleccion: float = 3.0    # Radio de atracción del imán de monedas

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- REFERENCIAS UI GENERALES ---
# --- REFERENCIAS UI GENERALES ---
@onready var lbl_salud_num = $"../../InterfazUI/HudSuperiorIzquierdo/TarjetaJugador/Fila/HudEstadisticas/FilaSalud/LblSaludNum"
@onready var barra_salud = $"../../InterfazUI/HudSuperiorIzquierdo/TarjetaJugador/Fila/HudEstadisticas/BarraSalud"
@onready var lbl_nivel = $"../../InterfazUI/HudSuperiorIzquierdo/TarjetaJugador/Fila/HudEstadisticas/LblNivel"
@onready var barra_xp = $"../../InterfazUI/HudSuperiorIzquierdo/TarjetaJugador/Fila/HudEstadisticas/BarraXP"
@onready var panel_nivel_up = $"../../InterfazUI/ContenedorAlertas/PanelNivelUp"
@onready var lbl_puntos_mejora = $"../../InterfazUI/ContenedorAlertas/PanelNivelUp/LblPuntos"
@onready var boton_nivel_hud = get_node_or_null("../../InterfazUI/HudSuperiorIzquierdo/TarjetaJugador/Fila/BotonNivel")

# --- REFERENCIAS UI INVENTARIO DE COMBATE ---
@onready var slots_ui: Array = [
	$"../../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma1",
	$"../../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma2",
	$"../../InterfazUI/EsquinaArmas/ContenedorArmas/SlotArma3"
]

var tween_nivel: Tween

# ==========================================================
# 2. SISTEMA DE ARMAS E INVENTARIO
# ==========================================================
@export_category("Ajustes de Combate")
@export var bala_escena: PackedScene
@onready var punto_disparo = $PuntoDisparo
# Máximo error (radianes, ~20°) entre hacia dónde mira el cuerpo y hacia dónde
# apunta el joystick para poder disparar. Evita gastar balas en la dirección vieja
# mientras el personaje todavía está girando.
const ANGULO_MAX_DISPARO := 0.35

var armas_inventario: Array[ArmaData] = []
var armas_equipadas: Array[ArmaData] = [null, null, null]
var cargadores_equipados: Array[int] = [0, 0, 0]

var arma_actual: ArmaData
var slot_actual: int = 0
var balas_en_cargador: int = 0
var esta_recargando: bool = false
var _id_recarga: int = 0  # cambia con cada recarga o cambio de arma: invalida recargas viejas
var temporizador_disparo: float = 0.0

var can_fire_fase: bool = false

var municion_reserva: Dictionary = {}

# Puntos invertidos en cada stat (para respetar el tope del Manual v3 §5).
var puntos_en_stat: Dictionary = {"salud": 0, "agilidad": 0, "destreza": 0, "ingenieria": 0, "recoleccion": 0}

# ==========================================================
# 3. INICIALIZACIÓN (¡BLINDADA PARA MULTIJUGADOR!)
# ==========================================================
func _enter_tree():
	# ¡Aquí es donde Godot nos pide que definamos la autoridad!
	set_multiplayer_authority(name.to_int())

func _ready():
	# --- FIX (revisión de código) ---
	# Esta línea corre SIEMPRE, en TODAS las copias del nodo (la del dueño
	# real y las réplicas no-autoritativas que ven el servidor y los demás
	# peers), no solo detrás del candado de autoridad. Es inofensivo pegarle
	# el mismo valor a una copia que no es tuya, y es justo lo que necesita
	# el servidor para poder evaluar correctamente "salud_actual > 0" sobre
	# CUALQUIER jugador al elegir presa en buscar_presa_mas_cercana().
	# Valores iniciales desde data/progresion.json (Balance).
	stat_salud_maxima = int(Balance.stat("salud")["base"])
	stat_agilidad = float(Balance.stat("agilidad")["base"])
	stat_destreza = float(Balance.stat("destreza")["base"])
	stat_ingenieria = float(Balance.stat("ingenieria")["base"])
	stat_recoleccion = float(Balance.stat("recoleccion")["base"])
	municion_reserva = Balance.progresion["municion_inicial"].duplicate()
	for tipo in municion_reserva.keys(): municion_reserva[tipo] = int(municion_reserva[tipo])
	salud_actual = stat_salud_maxima

	# Si tú eres el dueño absoluto de este clon específico:
	if is_multiplayer_authority():
		actualizar_ui_vida()
		actualizar_ui_xp()

		# Arma inicial creada desde data/armas.json: cada jugador recibe su
		# propia copia (mejorarla no afecta a nadie más). Antes además se
		# regalaban Escopeta y SMG al empezar (restos de pruebas).
		var arma_inicial: ArmaData = Balance.crear_arma(Balance.progresion["arma_inicial"])
		if arma_inicial:
			armas_inventario.append(arma_inicial)
			equipar_en_slot(arma_inicial, 0)
			cambiar_arma(0)


func set_can_fire(valor: bool) -> void:
	can_fire_fase = valor

# ==========================================================
# 4. LOOP DE FÍSICAS Y CONTROLES (¡SOLO PARA EL DUEÑO!)
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# ¡AQUÍ ESTÁ LA MAGIA! Ignoramos los joysticks si no somos el dueño
	if is_multiplayer_authority():
		# --- NUEVO: si estoy derribado, no muevo ni disparo ---
		if esta_caido:
			velocity.x = move_toward(velocity.x, 0, stat_agilidad)
			velocity.z = move_toward(velocity.z, 0, stat_agilidad)
			move_and_slide()
			return

		var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
		var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
		# Atado por el Hospedero: no camina (pero puede apuntar y disparar).
		if atado:
			direction = Vector3.ZERO
			_procesar_atadura(delta)

		if direction:
			velocity.x = direction.x * stat_agilidad
			velocity.z = direction.z * stat_agilidad
		else:
			velocity.x = move_toward(velocity.x, 0, stat_agilidad)
			velocity.z = move_toward(velocity.z, 0, stat_agilidad)

		temporizador_disparo += delta

		var aim_dir := Input.get_vector("apuntar_izq", "apuntar_der", "apuntar_arriba", "apuntar_abajo")

		if aim_dir.length() > 0.1:
			var angulo_objetivo = atan2(aim_dir.x, aim_dir.y)
			rotation.y = lerp_angle(rotation.y, angulo_objetivo, 15.0 * delta)

			var alineado = absf(angle_difference(rotation.y, angulo_objetivo)) < ANGULO_MAX_DISPARO
			# Táctil: dispara quien empuja el joystick más allá del anillo rojo
			# (acción "disparar_tactil"). Mando/otros: como antes, stick > 0.6.
			var quiere_disparar = (InputMap.has_action("disparar_tactil") and Input.is_action_pressed("disparar_tactil")) \
				or (not DisplayServer.is_touchscreen_available() and aim_dir.length() > 0.6)
			if quiere_disparar and alineado and can_fire_fase:
				intentar_disparar()

		# --- NUEVO: reanimación por proximidad ---
		# Si estoy vivo y hay un compañero derribado cerca, tras quedarme
		# TIEMPO_REANIMACION segundos junto a él, pido al servidor que lo revida.
		var companero_caido = buscar_companero_caido_cercano()
		if companero_caido:
			temporizador_reanimacion += delta
			if temporizador_reanimacion >= TIEMPO_REANIMACION:
				temporizador_reanimacion = 0.0
				solicitar_revivir_companero.rpc_id(1, companero_caido.name)
		else:
			temporizador_reanimacion = 0.0

	move_and_slide()

# ==========================================================
# 5. LÓGICA CORE DE COMBATE, SLOTS Y RECARGA
# ==========================================================
func equipar_en_slot(nueva_arma: ArmaData, slot: int):
	if slot < 0 or slot > 2: return
	armas_equipadas[slot] = nueva_arma
	cargadores_equipados[slot] = nueva_arma.tamano_cargador
	actualizar_ui_municion()

func cambiar_arma(slot: int):
	if slot < 0 or slot > 2 or armas_equipadas[slot] == null: return

	if arma_actual != null:
		cargadores_equipados[slot_actual] = balas_en_cargador

	slot_actual = slot
	arma_actual = armas_equipadas[slot]
	balas_en_cargador = cargadores_equipados[slot]

	# Cambiar de arma cancela la recarga en curso (ver recargar()).
	_id_recarga += 1
	esta_recargando = false
	temporizador_disparo = 1.0
	actualizar_ui_municion()

func equipar_arma_directa(indice_slot: int):
	if indice_slot >= 0 and indice_slot < armas_equipadas.size():
		if armas_equipadas[indice_slot] != null:
			cambiar_arma(indice_slot)

func ciclo_arma_rapido():
	var siguiente_slot = slot_actual
	for i in range(3):
		siguiente_slot = (siguiente_slot + 1) % 3
		if armas_equipadas[siguiente_slot] != null:
			cambiar_arma(siguiente_slot)
			return

func intentar_disparar():
	if not arma_actual or esta_recargando: return

	var tiempo_entre_balas = 1.0 / arma_actual.cadencia
	if temporizador_disparo >= tiempo_entre_balas:
		if balas_en_cargador > 0:
			# 1. Lógica LOCAL: Gastamos la bala de tu cargador (Solo ocurre en tu pantalla)
			temporizador_disparo = 0.0
			balas_en_cargador -= 1
			actualizar_ui_municion()

			# 2. Lógica de RED: Le gritamos a todos que generen la bala, pasándole los datos exactos
			ejecutar_disparo_en_red.rpc(arma_actual.dano, arma_actual.dispersion, arma_actual.balas_por_disparo)
		else:
			recargar()

# ¡MAGIA RPC! Recibimos los datos del arma directamente en los parámetros
@rpc("call_local", "any_peer", "reliable")
func ejecutar_disparo_en_red(dano_arma: int, dispersion_arma: float, cantidad_balas: int):
	if not bala_escena: return

	# Calculamos la dispersión usando el dato que llegó por la red
	var dispersion_rad = deg_to_rad(dispersion_arma) if dispersion_arma > 0.0 else 0.0

	for i in range(cantidad_balas):
		var nueva_bala = bala_escena.instantiate()
		get_tree().current_scene.add_child(nueva_bala)
		nueva_bala.global_transform = punto_disparo.global_transform

		if dispersion_rad > 0.0:
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)

		# Le inyectamos el daño que llegó por la red
		if "dano" in nueva_bala:
			nueva_bala.dano = dano_arma

		# --- FIX (revision de codigo) ---
		# ejecutar_disparo_en_red corre en TODOS los peers (broadcast con
		# call_local), asi que cada uno instancia su propia bala local.
		# Marcamos "es_bala_propia" solo en la copia que ve el propio tirador
		# (is_multiplayer_authority() de ESTE jugador, en ESTE peer). Asi,
		# solo esa bala reporta el impacto al servidor -- evitamos que el
		# mismo disparo cuente dano varias veces (una por cada pantalla).
		if "es_bala_propia" in nueva_bala:
			nueva_bala.es_bala_propia = is_multiplayer_authority()

func recargar():
	if not arma_actual or esta_recargando or balas_en_cargador == arma_actual.tamano_cargador: return

	var tipo = arma_actual.tipo_municion
	if municion_reserva[tipo] <= 0: return

	esta_recargando = true
	_id_recarga += 1
	var mi_recarga := _id_recarga
	var arma_recargando := arma_actual
	actualizar_ui_municion()

	var tiempo_real = arma_actual.tiempo_recarga / stat_destreza
	await get_tree().create_timer(tiempo_real).timeout

	# Si durante la espera se cambió de arma, la recarga se cancela SIN gastar
	# munición. Antes seguía de todas formas: cargaba el arma nueva con la
	# munición del tipo viejo y el arma vieja se quedaba vacía.
	if mi_recarga != _id_recarga or arma_actual != arma_recargando:
		return

	var balas_necesarias = arma_actual.tamano_cargador - balas_en_cargador
	if municion_reserva[tipo] >= balas_necesarias:
		balas_en_cargador += balas_necesarias
		municion_reserva[tipo] -= balas_necesarias
	else:
		balas_en_cargador += municion_reserva[tipo]
		municion_reserva[tipo] = 0

	esta_recargando = false
	actualizar_ui_municion()

func recargar_arma_actual():
	recargar()

func recoger_municion(cantidad: int, tipo: String):
	if municion_reserva.has(tipo):
		municion_reserva[tipo] += cantidad
		actualizar_ui_municion()

# ==========================================================
# 6. ENLACE DE UI (¡BLOQUEADO SOLO PARA EL JUGADOR LOCAL!)
# ==========================================================
func actualizar_ui_vida():
	if not is_multiplayer_authority(): return # El clon no debe tocar mi pantalla

	if lbl_salud_num and barra_salud:
		if esta_caido:
			lbl_salud_num.text = "DERRIBADO"
		else:
			lbl_salud_num.text = "%s / %s" % [salud_actual, stat_salud_maxima]
		barra_salud.max_value = stat_salud_maxima
		var valor_mostrado = 0 if esta_caido else salud_actual
		var tween = create_tween()
		tween.tween_property(barra_salud, "value", float(valor_mostrado), 0.2).set_trans(Tween.TRANS_SINE)

func actualizar_ui_xp():
	if not is_multiplayer_authority(): return

	if lbl_nivel and barra_xp:
		var xp_necesaria = Balance.xp_para_nivel(nivel)
		lbl_nivel.text = "NIVEL %s" % nivel + ("   +%d puntos" % puntos_mejora if puntos_mejora > 0 else "")
		# El botón de nivel se pinta de naranja si hay puntos sin gastar.
		if boton_nivel_hud:
			boton_nivel_hud.modulate = Color(1.0, 0.72, 0.45) if puntos_mejora > 0 else Color.WHITE
		barra_xp.max_value = xp_necesaria
		var tween = create_tween()
		tween.tween_property(barra_xp, "value", float(experiencia_actual), 0.2).set_trans(Tween.TRANS_SINE)

func actualizar_ui_municion():
	if not is_multiplayer_authority(): return

	for i in range(3):
		if i >= slots_ui.size(): break
		var slot_nodo = slots_ui[i]
		if not is_instance_valid(slot_nodo): continue

		var lbl_nombre = slot_nodo.find_child("LblNombre*", true, false)
		var lbl_balas = slot_nodo.find_child("LblBalas*", true, false)

		var arma = armas_equipadas[i]
		if arma != null:
			if lbl_nombre: lbl_nombre.text = arma.nombre

			var balas_render = balas_en_cargador if i == slot_actual else cargadores_equipados[i]
			var tipo_ammo = arma.tipo_municion
			var reserva = municion_reserva.get(tipo_ammo, 0)

			if lbl_balas:
				if esta_recargando and i == slot_actual:
					lbl_balas.text = "Recargando…"
				else:
					lbl_balas.text = str(balas_render) + " / " + str(reserva)

			# Arma en mano: borde naranja. Las otras, tarjeta de vidrio normal.
			slot_nodo.theme_type_variation = &"TarjetaArmaActiva" if i == slot_actual else &"TarjetaArma"
			slot_nodo.modulate = Color.WHITE if i == slot_actual else Color(1, 1, 1, 0.7)
		else:
			if lbl_nombre: lbl_nombre.text = "Vacío"
			if lbl_balas: lbl_balas.text = "—"
			slot_nodo.theme_type_variation = &"TarjetaArma"
			slot_nodo.modulate = Color(1, 1, 1, 0.35)

# ==========================================================
# 7. EVENTOS RPG, DAÑO Y PROGRESIÓN
# ==========================================================
# --- FIX (revision de codigo) ---
# Los zombies (que solo corren su IA en el servidor) llamaban
# recibir_dano() DIRECTO sobre el nodo jugador. Eso funcionaba para
# el Host (porque el Host ES el servidor), pero para un invitado, el
# servidor solo tiene una copia local NO autoritativa de su personaje
# -- salud_actual nunca esta sincronizada via MultiplayerSynchronizer
# (la autoridad de este nodo es el jugador dueno, no el servidor), asi
# que el dano nunca llegaba a la pantalla real del invitado.
# Esta RPC hace que el dano se aplique sobre el nodo verdadero de cada
# jugador, sea quien sea su dueno. "call_local" evita el error
# ERR_INVALID_PARAMETER cuando el Host se ataca a si mismo (mismo bug
# que ya resolvimos en declarar_listo_servidor).
@rpc("any_peer", "call_local", "reliable")
func recibir_dano_en_red(cantidad: int):
	# Solo aceptamos dano que venga del servidor (id 1) o de nosotros
	# mismos ejecutando localmente (remitente 0 = llamada local, gracias
	# a call_local). Bloquea que un cliente modificado se mande dano
	# arbitrario a si mismo o a otros.
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != 1: return
	recibir_dano(cantidad)

func recibir_dano(cantidad: int):
	# Un jugador ya derribado no puede "morir de nuevo" por más golpes que
	# le lleguen mientras está en el suelo esperando reanimación.
	if esta_caido: return

	salud_actual -= cantidad
	actualizar_ui_vida()
	if salud_actual <= 0: quedar_derribado()

# --- NUEVO (mecánica de derribo/reanimación) ---
# Antes esto era morir(): mataba al jugador al instante y disparaba el Game
# Over solo para él, mientras el resto seguía jugando. Eso permitía que el
# primero en morir presionara "Reintentar" (get_tree().reload_current_scene)
# y recargara SU escena aunque el resto del equipo siguiera vivo y conectado
# — la causa del bug de cámara desenfocada que viste. Ahora, en vez de morir,
# el jugador queda "derribado": sigue visible en el suelo (para que lo puedan
# encontrar y reanimar) pero no puede moverse ni disparar. El Game Over real
# solo ocurre cuando TODOS los jugadores están derribados a la vez (ver
# mundo.gd: revisar_todos_caidos() / ejecutar_game_over_en_red).
func quedar_derribado():
	esta_caido = true
	salud_actual = 0
	atado = false
	_mostrar_atadura(false)
	actualizar_ui_vida()

	# --- FIX (revisión de código) ---
	# "scale.y = 0.3" (escala NO uniforme) rompe a Jolt Physics: el motor no
	# soporta escalar de forma distinta cada eje en un CollisionShape3D, y
	# tira el error "A scale of (X, Y, Z) is not supported by Jolt Physics"
	# en CADA frame de física mientras el jugador está derribado (además
	# de aplicar una escala rara que ni siquiera es la que pedimos). Un
	# escalado UNIFORME (mismo valor en los 3 ejes) sí es válido para Jolt.
	# Sacrificamos el efecto de "aplastado" por uno de "encogido", pero sigue
	# siendo visualmente claro que el jugador está fuera de combate, y no
	# rompe la física.
	scale = Vector3(0.55, 0.55, 0.55)

	# Solo la instancia del SERVIDOR evalúa si esto significa Game Over
	# (evita que cada cliente dispare su propia comprobación redundante).
	if multiplayer.is_server():
		var mundo = get_parent().get_parent() # Ajustado para subir desde ContenedorJugadores
		if mundo.has_method("revisar_todos_caidos"): mundo.revisar_todos_caidos()

# Revive este jugador. porcentaje_salud controla con cuánta vida vuelve:
# 1.0 al pasar de oleada (descanso completo), menos si lo reanima un
# compañero a mitad de la noche (para que no sea gratis).
func revivir(porcentaje_salud: float = 1.0):
	if not esta_caido: return
	esta_caido = false
	salud_actual = max(1, int(stat_salud_maxima * porcentaje_salud))
	scale = Vector3(1.0, 1.0, 1.0)
	actualizar_ui_vida()

# --- RPC de reanimación ---
# Igual que recibir_dano_en_red: esto corre en TODOS los peers (broadcast),
# así que la copia real del jugador reanimado (sea de quien sea) se actualiza
# en su propia pantalla, y la copia del servidor también, sin depender del
# MultiplayerSynchronizer (que no replica salud_actual/esta_caido).
@rpc("any_peer", "call_local", "reliable")
func revivir_en_red(porcentaje_salud: float):
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != 1: return
	revivir(porcentaje_salud)

# --- NUEVO (Fase 1.C: Reconexión en caliente) ---
# El servidor llama esto cuando un jugador que estaba VIVO al desconectarse
# (no derribado) vuelve a conectarse dentro de la ventana de gracia. Le
# devuelve el control de este mismo nodo con la vida y posición que tenía
# justo antes de caerse -- como si nunca se hubiera ido. Si estaba derribado
# al caerse, el servidor NO llama esto (sigue derribado, esperando
# reanimación normal, para no regalar una revivida gratis por desconectarse).
@rpc("any_peer", "call_local", "reliable")
func reconectar_en_red(salud_restaurada: int, posicion_restaurada: Vector3):
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != 1: return
	esta_caido = false
	salud_actual = salud_restaurada
	global_position = posicion_restaurada
	scale = Vector3(1.0, 1.0, 1.0)
	actualizar_ui_vida()

# ==========================================================
# ATADURAS DEL HOSPEDERO (noche 20, fase 2)
# ==========================================================
# El servidor ata a quien quedó dentro del círculo. Solo: te liberas solo a
# los `duracion` segundos. Coop: solo te libera un compañero que se quede a
# menos de 2 m durante 1 s (o, como último recurso, a los 10 s). Mientras
# estás atado pierdes un 5 % de vida por segundo.
const RADIO_LIBERAR := 2.0
var atado := false
var _atado_requiere_ayuda := false
var _t_atado := 0.0
var _t_ayuda := 0.0
var _t_dano_atado := 0.0

@rpc("any_peer", "call_local", "reliable")
func atar_en_red(duracion: float, requiere_ayuda: bool):
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != 1: return
	if esta_caido: return
	atado = true
	_atado_requiere_ayuda = requiere_ayuda
	_t_atado = 10.0 if requiere_ayuda else duracion
	_t_ayuda = 0.0
	_t_dano_atado = 1.0
	_mostrar_atadura(true)
	if is_multiplayer_authority():
		var mundo = get_parent().get_parent()
		if mundo.has_method("mostrar_aviso"):
			mundo.mostrar_aviso("¡Atado! Un compañero debe acercarse para liberarte." if requiere_ayuda else "¡Atado! Aguanta 3 segundos…")

@rpc("any_peer", "call_local", "reliable")
func liberar_atadura_en_red():
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != 1 and remitente != get_multiplayer_authority(): return
	atado = false
	_mostrar_atadura(false)

func _procesar_atadura(delta: float):
	_t_atado -= delta
	_t_dano_atado -= delta
	if _t_dano_atado <= 0.0:
		_t_dano_atado = 1.0
		recibir_dano(maxi(1, int(stat_salud_maxima * 0.05)))
	if _atado_requiere_ayuda:
		var cerca := false
		for jug in get_tree().get_nodes_in_group("jugador"):
			if jug == self or not is_instance_valid(jug) or jug.esta_caido: continue
			if "atado" in jug and jug.atado: continue
			if global_position.distance_to(jug.global_position) <= RADIO_LIBERAR:
				cerca = true
				break
		_t_ayuda = _t_ayuda + delta if cerca else 0.0
	if _t_atado <= 0.0 or _t_ayuda >= 1.0:
		liberar_atadura_en_red.rpc()

func _mostrar_atadura(activa: bool):
	var anillo := get_node_or_null("Atadura")
	if not activa:
		if anillo: anillo.queue_free()
		return
	if anillo: return
	anillo = MeshInstance3D.new()
	anillo.name = "Atadura"
	var toro := TorusMesh.new()
	toro.inner_radius = 0.55
	toro.outer_radius = 0.75
	anillo.mesh = toro
	anillo.position = Vector3(0, 0.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.3, 1.0)
	mat.emission_energy_multiplier = 2.0
	anillo.material_override = mat
	add_child(anillo)
	var t := anillo.create_tween().set_loops()
	t.tween_property(anillo, "position:y", 1.3, 0.5)
	t.tween_property(anillo, "position:y", 0.4, 0.5)

# Busca, entre los jugadores vivos, si hay alguno derribado a corta
# distancia (para la reanimación por proximidad).
func buscar_companero_caido_cercano() -> Node3D:
	for jug in get_tree().get_nodes_in_group("jugador"):
		if jug == self or not is_instance_valid(jug): continue
		if "esta_caido" in jug and jug.esta_caido:
			if global_position.distance_to(jug.global_position) <= RADIO_REANIMACION:
				return jug
	return null

# El cliente (vivo) le pide al servidor que reanime a un compañero derribado.
# Validado en el servidor para que un cliente modificado no pueda revivir
# gente a distancia o sin cumplir el tiempo de reanimación.
# --- FIX (revisión de código) ---
# Faltaba "call_local" acá. Cuando el HOST es quien reanima, su propio
# rpc_id(1, ...) apunta a sí mismo (Host = servidor = id 1) -- exactamente
# el mismo bug que ya resolvimos antes en declarar_listo_servidor ("RPC ...
# on yourself is not allowed by selected mode"): sin call_local, Godot
# rechaza la llamada y la función nunca corre. Por eso el Host podía SER
# reanimado (el invitado sí llega al servidor real, que es otro peer), pero
# no podía reanimar él mismo a nadie. El guard "if not multiplayer.is_server()"
# de abajo sigue evitando que esto se ejecute dos veces cuando el que llama
# es un cliente (la copia local del cliente entra y sale de inmediato).
@rpc("any_peer", "call_local", "reliable")
func solicitar_revivir_companero(nombre_nodo: String):
	if not multiplayer.is_server(): return
	var contenedor = get_parent()
	if not contenedor or not contenedor.has_node(nombre_nodo): return

	var companero = contenedor.get_node(nombre_nodo)
	if not is_instance_valid(companero) or not ("esta_caido" in companero) or not companero.esta_caido:
		return
	if global_position.distance_to(companero.global_position) > RADIO_REANIMACION * 1.5:
		return # margen extra por latencia, pero evita reanimar desde el otro lado del mapa

	if companero.has_method("revivir_en_red"):
		companero.revivir_en_red.rpc(0.5) # Reanimado a mitad de la noche: vuelve con 50% de vida

func curar(porcentaje: float):
	if salud_actual >= stat_salud_maxima: return
	var cantidad_curacion = max(1, int(stat_salud_maxima * porcentaje))
	salud_actual = min(salud_actual + cantidad_curacion, stat_salud_maxima)
	actualizar_ui_vida()

func ganar_experiencia(cantidad: int):
	if nivel >= int(Balance.progresion["nivel_maximo"]): return
	experiencia_actual += cantidad
	var xp_necesaria = Balance.xp_para_nivel(nivel)

	if experiencia_actual >= xp_necesaria:
		subir_nivel()
	else:
		actualizar_ui_xp()

func subir_nivel():
	var xp_necesaria = Balance.xp_para_nivel(nivel)
	experiencia_actual -= xp_necesaria
	nivel += 1
	puntos_mejora += int(Balance.progresion["puntos_por_nivel"])
	salud_actual = stat_salud_maxima

	actualizar_ui_vida()
	actualizar_ui_xp()

	if not is_multiplayer_authority(): return

	if panel_nivel_up and lbl_puntos_mejora:
		lbl_puntos_mejora.text = "+" + str(puntos_mejora) + " Puntos de Mejora"
		panel_nivel_up.visible = true
		panel_nivel_up.modulate.a = 0.0

		if tween_nivel: tween_nivel.kill()
		tween_nivel = create_tween()
		tween_nivel.tween_property(panel_nivel_up, "modulate:a", 1.0, 0.3)
		tween_nivel.tween_interval(3.0)
		tween_nivel.tween_property(panel_nivel_up, "modulate:a", 0.0, 0.5)
		tween_nivel.tween_callback(func(): panel_nivel_up.visible = false)

	if experiencia_actual >= Balance.xp_para_nivel(nivel) and nivel < int(Balance.progresion["nivel_maximo"]):
		subir_nivel()

func mejorar_estadistica(estadistica: String):
	if puntos_mejora <= 0 or not puntos_en_stat.has(estadistica): return
	if stat_en_tope(estadistica): return
	var por_punto = Balance.stat(estadistica)["por_punto"]

	match estadistica:
		"salud":
			stat_salud_maxima += int(por_punto)
			salud_actual += int(por_punto)
			actualizar_ui_vida()
		"agilidad": stat_agilidad += float(por_punto)
		"destreza": stat_destreza += float(por_punto)
		"ingenieria": stat_ingenieria += float(por_punto)
		"recoleccion": stat_recoleccion += float(por_punto)

	puntos_en_stat[estadistica] += 1
	puntos_mejora -= 1
	actualizar_ui_xp()

func stat_en_tope(estadistica: String) -> bool:
	return puntos_en_stat.get(estadistica, 0) >= int(Balance.stat(estadistica)["tope_puntos"])

# ==========================================================
# 8. GUARDADO DE PARTIDA (Fase 1)
# ==========================================================
# El servidor guarda la partida al cerrar cada noche, pero los datos de cada
# personaje viven en la pantalla de su dueño. Estas dos funciones los
# empaquetan para mandarlos al servidor y los restauran al continuar.

func exportar_estado() -> Dictionary:
	var armas := []
	for arma in armas_inventario: armas.append(arma.a_diccionario())
	var equipadas := []
	for arma in armas_equipadas: equipadas.append(armas_inventario.find(arma) if arma else -1)
	return {
		"nivel": nivel, "experiencia": experiencia_actual, "puntos_mejora": puntos_mejora,
		"puntos_en_stat": puntos_en_stat.duplicate(),
		"stat_salud_maxima": stat_salud_maxima, "stat_agilidad": stat_agilidad,
		"stat_destreza": stat_destreza, "stat_ingenieria": stat_ingenieria,
		"stat_recoleccion": stat_recoleccion,
		"municion": municion_reserva.duplicate(),
		"armas": armas, "equipadas": equipadas, "slot_actual": slot_actual
	}

func importar_estado(d: Dictionary) -> void:
	if d.is_empty(): return
	nivel = int(d.get("nivel", 1))
	experiencia_actual = int(d.get("experiencia", 0))
	puntos_mejora = int(d.get("puntos_mejora", 0))
	for k in d.get("puntos_en_stat", {}).keys(): puntos_en_stat[k] = int(d["puntos_en_stat"][k])
	stat_salud_maxima = int(d.get("stat_salud_maxima", stat_salud_maxima))
	stat_agilidad = float(d.get("stat_agilidad", stat_agilidad))
	stat_destreza = float(d.get("stat_destreza", stat_destreza))
	stat_ingenieria = float(d.get("stat_ingenieria", stat_ingenieria))
	stat_recoleccion = float(d.get("stat_recoleccion", stat_recoleccion))
	for tipo in d.get("municion", {}).keys(): municion_reserva[tipo] = int(d["municion"][tipo])

	var armas: Array = d.get("armas", [])
	if not armas.is_empty():
		armas_inventario.clear()
		for datos in armas: armas_inventario.append(ArmaData.desde_diccionario(datos))
		armas_equipadas.fill(null)
		var equipadas: Array = d.get("equipadas", [])
		for i in range(mini(3, equipadas.size())):
			var idx := int(equipadas[i])
			if idx >= 0 and idx < armas_inventario.size():
				equipar_en_slot(armas_inventario[idx], i)
		arma_actual = null
		var slot := int(d.get("slot_actual", 0))
		if slot < 0 or slot > 2 or armas_equipadas[slot] == null:
			slot = 0
			for k in range(3):
				if armas_equipadas[k] != null:
					slot = k
					break
		cambiar_arma(slot)

	salud_actual = stat_salud_maxima
	actualizar_ui_vida()
	actualizar_ui_xp()
	actualizar_ui_municion()
