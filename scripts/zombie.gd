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

# --- JEFES Y NODOS ---
# Los jefes (y los nodos de energía del Hospedero) no usan la IA de abajo:
# su cerebro es un nodo hijo (scripts/enemigos/*_ia.gd) que solo existe en el
# servidor. Ver nacer().
var ia: Node = null
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
	# tipo_zombie llega con el spawn: cada pantalla pinta el enemigo según su tipo.
	_aplicar_aspecto.call_deferred()

# ----------------------------------------------------------
# MODELO Y ANIMACIONES (personajes PSX + Mixamo)
# ----------------------------------------------------------
const ROL_POR_TIPO := {"basico": "basico", "corredor": "corredor", "explosivo": "explosivo",
	"tanque": "tanque", "acechador": "acechador", "guardian": "guardian",
	"mosca_titan": "mosca_titan", "mosca_titan_plus": "mosca_titan", "hospedero": "hospedero"}
const TIPOS_JEFE_ANIM := ["acechador", "guardian", "mosca_titan", "mosca_titan_plus", "hospedero"]
var animador: Animador = null
var arrastrando := false   # malherido: sigue avanzando, a rastras
var _t_impacto := 0.0
var _pos_previa := Vector3.INF
var _rapidez := 0.0

func _crear_modelo(contenedor: Node3D):
	var rol: String = ROL_POR_TIPO.get(tipo_zombie, "basico")
	var lista: Array = ModelosPSX.roles().get(rol, [])
	if lista.is_empty():
		contenedor.add_child(ModelosPSX.zombie())
		return
	# El mismo nombre de nodo en todas las pantallas => el mismo modelo.
	var nombre_modelo: String = lista[absi(hash(String(name))) % lista.size()]
	var p := ModelosPSX.personaje(nombre_modelo)
	contenedor.add_child(p)
	animador = Animador.para(p.get_child(0), "jefe" if tipo_zombie in TIPOS_JEFE_ANIM else "zombie")
	animador.poner("reposo")
	animador.seek(randf() * 2.0, true)
	# Uno de cada tres zombies comunes aparece gritando (igual en todas las pantallas).
	if tipo_zombie in ["basico", "corredor", "tanque"] and absi(hash(String(name))) % 3 == 0:
		animador.accion("grito", 1.4, 2.0)

# Corre en todas las pantallas: la animación sale de cuánto se movió.
func _process(delta: float) -> void:
	if not animador or esta_muerto or delta <= 0.0: return
	var p := global_position
	if _pos_previa != Vector3.INF:
		var v := Vector2(p.x - _pos_previa.x, p.z - _pos_previa.z).length() / delta
		_rapidez = lerpf(_rapidez, v, minf(1.0, delta * 8.0))
	_pos_previa = p
	var esc := maxf(0.5, scale.x)
	var r := _rapidez / esc
	if arrastrando:
		animador.poner("arrastre", clampf(r / 0.45, 0.6, 2.4))
	elif r < 0.25:
		animador.poner("reposo")
	elif r > 2.6 or tipo_zombie in ["corredor", "acechador"]:
		animador.poner("correr", clampf(r / 3.5, 0.6, 1.8))
	else:
		animador.poner("caminar", clampf(r / 0.9, 0.8, 2.6))

# El servidor avisa a todas las pantallas que suene una acción.
@rpc("authority", "call_local", "unreliable")
func animar_en_red(nombre: String, duracion: float = -1.0, velocidad: float = 1.0):
	if animador: animador.accion(nombre, duracion, velocidad)

# Zombie malherido que cae y sigue a rastras (más lento).
@rpc("authority", "call_local", "reliable")
func arrastrar_en_red():
	arrastrando = true
	velocidad *= 0.4
	if animador: animador.terminar_accion()

# Muerte: animación en todas las pantallas y el cuerpo se borra después.
@rpc("authority", "call_local", "reliable")
func morir_en_red():
	esta_muerto = true
	remove_from_group("enemigos")
	remove_from_group("jefes")
	collision_layer = 0
	collision_mask = 1
	if animador: animador.morir()
	if has_node("SombraPS1"): $SombraPS1.visible = false

func _aplicar_aspecto():
	var datos := Balance.zombie(tipo_zombie)
	var modelo := get_node_or_null("zombie_run") as Node3D
	if tipo_zombie == "nodo":
		if modelo: modelo.visible = false
		var cristal := MeshInstance3D.new()
		var prisma := PrismMesh.new()
		prisma.size = Vector3(0.9, 1.8, 0.9)
		cristal.mesh = prisma
		cristal.position = Vector3(0, 1.2, 0)
		var mat_c := StandardMaterial3D.new()
		mat_c.albedo_color = Color(datos.get("color", "#22d3ee"))
		mat_c.emission_enabled = true
		mat_c.emission = mat_c.albedo_color
		mat_c.emission_energy_multiplier = 2.5
		cristal.material_override = mat_c
		add_child(cristal)
		var giro := cristal.create_tween().set_loops()
		giro.tween_property(cristal, "rotation:y", TAU, 2.0).from(0.0)
		return
	# Modelo animado (assets/modelos/zombie_psx). La caminata va más rápida
	# en los tipos rápidos; el tipo se conoce en todas las pantallas.
	if modelo and modelo.get_child_count() == 0:
		_crear_modelo(modelo)
	if modelo and tipo_zombie == "basico":
		PS1.aplicar_tinte(modelo, Color("#7f9c6b"), 0.3)
	if not datos.has("color") or not modelo: return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(datos["color"], 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Con el estilo PS1 el color va por un parámetro del material (un
	# overlay no tiembla junto con los vértices y se vería despegado).
	PS1.aplicar_tinte(modelo, Color(datos["color"]), 0.4 if Balance.es_jefe(tipo_zombie) else 0.3)
	if not PS1.activo:
		for m in modelo.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = mat
	# La Mosca Titán lleva una placa al frente: la armadura que obliga a flanquear.
	if tipo_zombie.begins_with("mosca_titan"):
		var placa := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.5, 0.42, 0.08)
		placa.mesh = caja
		placa.position = Vector3(0, 1.2, -0.22)
		var mat_p := StandardMaterial3D.new()
		mat_p.albedo_color = Color("#cbd5e1")
		mat_p.metallic = 0.8
		mat_p.roughness = 0.3
		placa.material_override = mat_p
		add_child(placa)

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
	velocidad = Balance.escalar_velocidad(float(datos["velocidad"]), numero_oleada) * Balance.velocidad_noche(numero_oleada)
	var jugadores := maxi(1, get_tree().get_nodes_in_group("jugador").size())
	if Balance.es_jefe(tipo):
		salud_maxima = int(Balance.vida_jefe(numero_oleada, jugadores) * float(datos.get("fraccion_vida", 1.0)))
	elif tipo == "nodo":
		salud_maxima = int(Balance.dps_esperado(numero_oleada) * float(datos.get("segundos_de_vida", 2.5)))
	else:
		salud_maxima = Balance.escalar_vida(float(datos["vida"]), numero_oleada)
	salud_actual = salud_maxima
	var furia := Balance.furia_noche(numero_oleada)
	dano_ataque_actual = int(Balance.escalar_dano(float(datos["dano"]), numero_oleada) * furia)
	dano_estructuras = int(Balance.escalar_dano(float(datos["dano_estructuras"]), numero_oleada) * furia)

	# Cerebro de jefe (solo servidor: los clientes solo ven moverse al modelo).
	if multiplayer.is_server():
		var script_ia: Script = null
		match tipo:
			"mosca_titan", "mosca_titan_plus": script_ia = load("res://scripts/enemigos/mosca_titan_ia.gd")
			"guardian": script_ia = load("res://scripts/enemigos/guardian_ia.gd")
			"acechador": script_ia = load("res://scripts/enemigos/acechador_ia.gd")
			"hospedero": script_ia = load("res://scripts/enemigos/hospedero_ia.gd")
			"nodo": script_ia = load("res://scripts/enemigos/nodo_ia.gd")
		if script_ia:
			ia = script_ia.new()
			ia.name = "IA"
			add_child(ia)
			ia.iniciar(self, numero_oleada, jugadores)

func _physics_process(delta):
	# ¡FILTRO DE RED! Solo la máquina del Host calcula dónde camina el zombie.
	# Los clientes solo lo ven moverse gracias al MultiplayerSynchronizer.
	if not multiplayer.is_server(): return

	if esta_muerto: return

	tiempo_vivo += delta

	if not is_on_floor():
		velocity.y -= gravedad * delta

	if ia:
		ia.procesar(delta)
		move_and_slide()
		return

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

func detener_movimiento():
	velocity.x = move_toward(velocity.x, 0, velocidad)
	velocity.z = move_toward(velocity.z, 0, velocidad)

# ==========================================================
# 5. SISTEMA DE COMBATE Y HABILIDADES
# ==========================================================
func atacar(objetivo):
	puede_atacar = false
	if not ia:
		if randf() < 0.35: animar_en_red.rpc("mordida", 1.0, 2.6)
		else: animar_en_red.rpc("golpe", 0.9, 1.6)
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

# Igual que recibir_dano_en_red, con la dirección de la bala: la usan los
# jefes con armadura (la Mosca Titán resiste lo que le pega de frente).
@rpc("any_peer", "call_local", "reliable")
func recibir_impacto_en_red(cantidad: int, direccion: Vector3):
	recibir_dano(cantidad, direccion)

func recibir_dano(cantidad: int, direccion: Vector3 = Vector3.ZERO):
	# ¡FILTRO DE RED CRÍTICO! Las balas existen en ambas pantallas, pero
	# solo el Servidor descuenta la vida, registra la muerte y suelta el oro.
	if not multiplayer.is_server(): return

	if esta_muerto: return

	if ia:
		cantidad = ia.modificar_dano(cantidad, direccion)
		if cantidad <= 0: return

	salud_actual -= cantidad
	if ia: ia.al_recibir_dano(cantidad)
	elif salud_actual > 0 and animador:
		# Sacudón al recibir un tiro (como mucho uno por segundo por zombie).
		var ahora := Time.get_ticks_msec() / 1000.0
		if ahora - _t_impacto > 1.0 and not arrastrando:
			_t_impacto = ahora
			animar_en_red.rpc("impacto", 0.35, 2.2)
		# Algunos caen malheridos y siguen arrastrándose.
		if not arrastrando and tipo_zombie in ["basico", "tanque"] and salud_actual < salud_maxima * 0.35 and randf() < 0.35:
			arrastrar_en_red.rpc()

	if salud_actual <= 0:
		esta_muerto = true

		var mundo = get_parent()
		if ia: ia.al_morir()
		if is_instance_valid(mundo) and tipo_zombie != "nodo":
			if mundo.has_method("zombie_eliminado"): mundo.zombie_eliminado()
			if mundo.has_method("spawn_loot"): mundo.spawn_loot(global_position, tipo_zombie)

		# Se queda en el suelo con su animación de muerte y se borra un poco
		# después; al borrarse en el servidor, el MultiplayerSpawner lo borra
		# en los clientes.
		if animador and tipo_zombie != "nodo":
			morir_en_red.rpc()
			get_tree().create_timer(3.0 if Balance.es_jefe(tipo_zombie) else 2.0).timeout.connect(queue_free)
		else:
			queue_free()
