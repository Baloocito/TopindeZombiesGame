extends CharacterBody3D

# ==========================================================
# 1. ESTADÍSTICAS Y CONFIGURACIÓN BASE
# ==========================================================
@export_category("Identidad")
var tipo_zombie: String = "basico"
var costo_en_presupuesto: int = 10

@export_category("Estadísticas de Combate")
var velocidad: float = 1.8
var cadencia_ataque: float = 1.0
var rango_ataque: float = 1.5

var salud_maxima: int = 40
var salud_actual: int
var dano_ataque_actual: int
var dano_estructuras: int = 15
const RADIO_EXPLOSION: float = 3.0

# --- HABILIDADES DE JEFE ---
var cooldown_habilidad: float = 5.0
var temporizador_habilidad: float = 0.0
var esta_cargando_ataque: bool = false

# --- ESTADOS INTERNOS ---
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")
var jugador_objetivo: Node3D = null # Cambiado para ser dinámico
var puede_atacar: bool = true
var esta_muerto: bool = false
var tiempo_vivo: float = 0.0

# Rendimiento (Fase 1): buscar presa y recalcular la ruta cada frame, con 70
# zombies, era lo más caro del servidor. Ahora se hace cada 0,25 s, con un
# desfase al azar para que no lo hagan todos en el mismo frame.
const INTERVALO_IA: float = 0.25
var _temporizador_ia: float = randf() * INTERVALO_IA

# ==========================================================
# 2. NODOS HIJOS Y AUTORIDAD
# ==========================================================
@onready var agente_nav: NavigationAgent3D = $NavigationAgent3D

func _ready():
	# ¡VITAL! El ID 1 (Servidor) es el único dueño legítimo de todos los zombies
	set_multiplayer_authority(1)

# ¡NUEVA FUNCIÓN COOPERATIVA! El zombie escanea quién está más cerca
func buscar_presa_mas_cercana() -> Node3D:
	var jugadores = get_tree().get_nodes_in_group("jugador")
	var presa_cercana = null
	var distancia_minima = INF

	for jug in jugadores:
		# --- NUEVO --- excluimos explícitamente a los derribados (además de
		# que su salud_actual ya queda en 0, ver jugador.gd: quedar_derribado())
		# para que ningún zombie pierda el tiempo "atacando" a alguien que ya
		# está fuera de combate esperando reanimación.
		if is_instance_valid(jug) and jug.salud_actual > 0 and not ("esta_caido" in jug and jug.esta_caido):
			var dist = global_position.distance_to(jug.global_position)
			if dist < distancia_minima:
				distancia_minima = dist
				presa_cercana = jug

	return presa_cercana

# ==========================================================
# 3. NACIMIENTO Y ESCALADO INFINITO (RPG)
# ==========================================================
func nacer(numero_oleada: int, costo: int, tipo: String = "basico"):
	# Todos los números salen de data/zombies.json y de las fórmulas del
	# Manual v3 §8 (Balance). La vida ya no se multiplica por jugadores: en
	# coop sube la CANTIDAD de zombies (presupuesto), no su vida.
	var datos := Balance.zombie(tipo)
	costo_en_presupuesto = costo
	tipo_zombie = tipo
	var escala := float(datos["escala"])
	scale = Vector3.ONE * escala
	rango_ataque = 1.2 * escala
	velocidad = Balance.escalar_velocidad(float(datos["velocidad"]), numero_oleada)
	if tipo == "boss":
		var jugadores := maxi(1, get_tree().get_nodes_in_group("jugador").size())
		salud_maxima = Balance.vida_jefe(numero_oleada, jugadores)
	else:
		salud_maxima = Balance.escalar_vida(float(datos["vida"]), numero_oleada)
	salud_actual = salud_maxima
	dano_ataque_actual = Balance.escalar_dano(float(datos["dano"]), numero_oleada)
	dano_estructuras = Balance.escalar_dano(float(datos["dano_estructuras"]), numero_oleada)

func _physics_process(delta):
	# ¡FILTRO DE RED! Solo la máquina del Host calcula dónde camina el zombie.
	# Los clientes solo lo ven moverse gracias al MultiplayerSynchronizer.
	if not multiplayer.is_server(): return

	if esta_muerto: return

	tiempo_vivo += delta

	if not is_on_floor():
		velocity.y -= gravedad * delta

	if esta_cargando_ataque:
		detener_movimiento()
		move_and_slide()
		return

	# Actualizamos la presa en tiempo real
	_temporizador_ia -= delta
	var recalcular := _temporizador_ia <= 0.0 or not is_instance_valid(jugador_objetivo)
	if recalcular:
		_temporizador_ia = INTERVALO_IA
		jugador_objetivo = buscar_presa_mas_cercana()

	if is_instance_valid(jugador_objetivo):
		var distancia_real = global_position.distance_to(jugador_objetivo.global_position)

		if distancia_real > rango_ataque:
			if agente_nav:
				if recalcular:
					agente_nav.target_position = jugador_objetivo.global_position
				var siguiente_paso = agente_nav.get_next_path_position()

				var direccion = global_position.direction_to(siguiente_paso)
				direccion.y = 0
				direccion = direccion.normalized()

				velocity.x = direccion.x * velocidad
				velocity.z = direccion.z * velocidad

				if velocity.length() > 0.1:
					var pos_mirar = Vector3(siguiente_paso.x, global_position.y, siguiente_paso.z)
					look_at(pos_mirar, Vector3.UP)
		else:
			detener_movimiento()
			if puede_atacar:
				if tipo_zombie == "explosivo": explotar()
				else: atacar(jugador_objetivo)
	else:
		detener_movimiento()

	move_and_slide()
	revisar_colisiones()

	if tipo_zombie == "boss" and is_instance_valid(jugador_objetivo):
		temporizador_habilidad -= delta
		if temporizador_habilidad <= 0.0 and global_position.distance_to(jugador_objetivo.global_position) <= 8.0:
			iniciar_golpe_sismico()
			temporizador_habilidad = cooldown_habilidad

func detener_movimiento():
	velocity.x = move_toward(velocity.x, 0, velocidad)
	velocity.z = move_toward(velocity.z, 0, velocidad)

# ==========================================================
# 5. SISTEMA DE COMBATE Y HABILIDADES
# ==========================================================
func atacar(objetivo):
	puede_atacar = false
	if is_instance_valid(objetivo):
		# Antes solo se buscaba recibir_dano_en_red, que las estructuras no
		# tienen: los zombies nunca dañaban barricadas ni torretas.
		if objetivo.is_in_group("barricadas") and objetivo.has_method("recibir_dano"):
			objetivo.recibir_dano(dano_estructuras)
		elif objetivo.has_method("recibir_dano_en_red"):
			objetivo.recibir_dano_en_red.rpc(dano_ataque_actual)
	await get_tree().create_timer(cadencia_ataque).timeout
	if is_instance_valid(self) and not esta_muerto:
		puede_atacar = true

func revisar_colisiones():
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		var objeto_chocado = colision.get_collider()

		if objeto_chocado and objeto_chocado.is_in_group("barricadas") and puede_atacar:
			atacar(objeto_chocado)

func iniciar_golpe_sismico():
	esta_cargando_ataque = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(3.0, 3.0, 3.0), 1.0)

	await get_tree().create_timer(1.0).timeout

	if not is_instance_valid(self) or esta_muerto: return

	ejecutar_golpe_sismico()
	scale = Vector3(2.5, 2.5, 2.5)
	esta_cargando_ataque = false

func ejecutar_golpe_sismico():
	var radio_impacto = 6.0
	var dano_habilidad = int(dano_ataque_actual * 1.5)

	# --- FIX (revisión de código) --- misma razón que en atacar()
	if is_instance_valid(jugador_objetivo) and global_position.distance_to(jugador_objetivo.global_position) <= radio_impacto:
		if jugador_objetivo.has_method("recibir_dano_en_red"): jugador_objetivo.recibir_dano_en_red.rpc(dano_habilidad)

	# Las barricadas SÍ son autoridad del servidor por defecto, así que la
	# llamada directa está bien acá — no hace falta RPC.
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for defensa in barricadas:
		if is_instance_valid(defensa) and global_position.distance_to(defensa.global_position) <= radio_impacto:
			if defensa.has_method("recibir_dano"): defensa.recibir_dano(dano_habilidad)

func explotar():
	puede_atacar = false
	if is_instance_valid(jugador_objetivo) and jugador_objetivo.has_method("recibir_dano_en_red"):
		jugador_objetivo.recibir_dano_en_red.rpc(dano_ataque_actual)
	# La explosión también golpea las estructuras cercanas (150 base, §7).
	for defensa in get_tree().get_nodes_in_group("barricadas"):
		if is_instance_valid(defensa) and global_position.distance_to(defensa.global_position) <= RADIO_EXPLOSION:
			if defensa.has_method("recibir_dano"): defensa.recibir_dano(dano_estructuras)
	recibir_dano(salud_actual)

@rpc("any_peer", "call_local", "reliable")
func recibir_dano_en_red(cantidad: int):
	recibir_dano(cantidad)

func recibir_dano(cantidad: int):
	# ¡FILTRO DE RED CRÍTICO! Las balas existen en ambas pantallas, pero
	# solo el Servidor descuenta la vida, registra la muerte y suelta el oro.
	if not multiplayer.is_server(): return

	if esta_muerto: return

	salud_actual -= cantidad

	if salud_actual <= 0:
		esta_muerto = true

		var mundo = get_parent()
		if is_instance_valid(mundo):
			if mundo.has_method("zombie_eliminado"): mundo.zombie_eliminado()
			if mundo.has_method("spawn_loot"): mundo.spawn_loot(global_position, tipo_zombie)

		# Al borrarse en el Servidor, el MultiplayerSpawner de Godot
		# lo borra automáticamente en los clientes.
		queue_free()
