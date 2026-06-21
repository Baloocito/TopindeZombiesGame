extends CharacterBody3D

# ==========================================================
# 1. ESTADÍSTICAS Y CONFIGURACIÓN BASE
# ==========================================================
@export_category("Identidad")
var tipo_zombie: String = "basico"
var costo_en_presupuesto: int = 10

@export_category("Estadísticas de Combate")
var salud_maxima_base: int = 40
var velocidad: float = 1.8
var dano_ataque_base: int = 15
var cadencia_ataque: float = 1.0 
var rango_ataque: float = 1.5 

var salud_maxima: int = 40
var salud_actual: int
var dano_ataque_actual: int

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
		if is_instance_valid(jug) and jug.salud_actual > 0:
			var dist = global_position.distance_to(jug.global_position)
			if dist < distancia_minima:
				distancia_minima = dist
				presa_cercana = jug
				
	return presa_cercana

# ==========================================================
# 3. NACIMIENTO Y ESCALADO INFINITO (RPG)
# ==========================================================
func nacer(numero_oleada: int, costo: int, tipo: String = "basico"):
	costo_en_presupuesto = costo
	tipo_zombie = tipo 
	rango_ataque = 1.2 * scale.x
	
	match tipo:
		"corredor":
			salud_maxima_base = 25
			dano_ataque_base = 8
			velocidad = 4.0
			scale = Vector3(0.8, 0.8, 0.8)
		"explosivo":
			salud_maxima_base = 60
			dano_ataque_base = 150
			velocidad = 2.5
			scale = Vector3(1.1, 1.1, 1.1)
		"tanque":
			salud_maxima_base = 300
			dano_ataque_base = 40
			velocidad = 1.2
			scale = Vector3(1.4, 1.4, 1.4)
		"boss": 
			salud_maxima_base = 1200
			dano_ataque_base = 70
			velocidad = 3.0
			scale = Vector3(2.5, 2.5, 2.5)
		_: 
			salud_maxima_base = 40
			dano_ataque_base = 15
			velocidad = 1.8
			scale = Vector3(1, 1, 1) 
	
	var multiplicador_hp_ola = pow(1.12, numero_oleada - 1)
	var cantidad_jugadores = max(1, get_tree().get_nodes_in_group("jugador").size())
	var multiplicador_coop = 1.0 + ((cantidad_jugadores - 1) * 0.60)
	
	salud_maxima = int(salud_maxima_base * multiplicador_hp_ola * multiplicador_coop)
	salud_actual = salud_maxima
	dano_ataque_actual = dano_ataque_base + (2 * numero_oleada)

# ==========================================================
# 4. INTELIGENCIA ARTIFICIAL Y FÍSICAS
# ==========================================================
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
	jugador_objetivo = buscar_presa_mas_cercana()

	if is_instance_valid(jugador_objetivo):
		var distancia_real = global_position.distance_to(jugador_objetivo.global_position)
		
		if distancia_real > rango_ataque: 
			if agente_nav:
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
	if is_instance_valid(objetivo) and objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano_ataque_actual)
		
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
	
	if is_instance_valid(jugador_objetivo) and global_position.distance_to(jugador_objetivo.global_position) <= radio_impacto:
		if jugador_objetivo.has_method("recibir_dano"): jugador_objetivo.recibir_dano(dano_habilidad)
				
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for defensa in barricadas:
		if is_instance_valid(defensa) and global_position.distance_to(defensa.global_position) <= radio_impacto:
			if defensa.has_method("recibir_dano"): defensa.recibir_dano(dano_habilidad)

func explotar():
	puede_atacar = false 
	if is_instance_valid(jugador_objetivo) and jugador_objetivo.has_method("recibir_dano"):
		jugador_objetivo.recibir_dano(dano_ataque_actual)
	
	recibir_dano(salud_actual)

# ==========================================================
# 6. SISTEMA DE DAÑO Y MUERTE (BLINDADO EN RED)
# ==========================================================
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
