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
var jugador: Node3D
var puede_atacar: bool = true
var esta_muerto: bool = false 
var tiempo_vivo: float = 0.0

# ==========================================================
# 2. NODOS HIJOS (¡NUEVO: CEREBRO DE NAVEGACIÓN!)
# ==========================================================
@onready var agente_nav: NavigationAgent3D = $NavigationAgent3D

func _ready():
	var jugadores_en_mapa = get_tree().get_nodes_in_group("jugador")
	if not jugadores_en_mapa.is_empty():
		jugador = jugadores_en_mapa[0]

# ==========================================================
# 3. NACIMIENTO Y ESCALADO INFINITO (RPG)
# ==========================================================
func nacer(numero_oleada: int, costo: int, tipo: String = "basico"):
	costo_en_presupuesto = costo
	tipo_zombie = tipo 
	rango_ataque = 1.2 * scale.x
	
	# Asignación de Arquetipos
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
		"boss": # Mosca Tyrant
			salud_maxima_base = 1200
			dano_ataque_base = 70
			velocidad = 3.0
			scale = Vector3(2.5, 2.5, 2.5)
		_: # Básico por defecto
			salud_maxima_base = 40
			dano_ataque_base = 15
			velocidad = 1.8
			scale = Vector3(1, 1, 1) 
	
	# --- CÁLCULO MATEMÁTICO DE ESCALADO ---
	# $HP(W) = HP_{Base} \cdot 1.12^{(W-1)}$
	var multiplicador_hp_ola = pow(1.12, numero_oleada - 1)
	
	var cantidad_jugadores = max(1, get_tree().get_nodes_in_group("jugador").size())
	var multiplicador_coop = 1.0 + ((cantidad_jugadores - 1) * 0.60)
	
	salud_maxima = int(salud_maxima_base * multiplicador_hp_ola * multiplicador_coop)
	salud_actual = salud_maxima
	
	# $Daño(W) = Daño_{Base} + (2 \cdot W)$
	dano_ataque_actual = dano_ataque_base + (2 * numero_oleada)

# ==========================================================
# 4. INTELIGENCIA ARTIFICIAL Y FÍSICAS (Pathfinding)
# ==========================================================
func _physics_process(delta):
	if esta_muerto: return # Si está muerto, ignoramos todas las físicas
	
	tiempo_vivo += delta
	
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravedad * delta 

	# Congelamiento por casteo de habilidad
	if esta_cargando_ataque:
		detener_movimiento()
		move_and_slide()
		return 

	# Lógica de Persecución (¡AHORA CON NAVMESH!)
	if is_instance_valid(jugador) and jugador.salud_actual > 0:
		var distancia_real = global_position.distance_to(jugador.global_position)
		
		if distancia_real > rango_ataque: 
			# Alimentamos el cerebro con la posición del jugador
			if agente_nav:
				agente_nav.target_position = jugador.global_position
				var siguiente_paso = agente_nav.get_next_path_position()
				
				var direccion = global_position.direction_to(siguiente_paso)
				direccion.y = 0
				direccion = direccion.normalized()
				
				velocity.x = direccion.x * velocidad
				velocity.z = direccion.z * velocidad
				
				# Rotación suave hacia el siguiente punto de la ruta
				if velocity.length() > 0.1:
					var pos_mirar = Vector3(siguiente_paso.x, global_position.y, siguiente_paso.z)
					look_at(pos_mirar, Vector3.UP)
		else:
			# Alcance de ataque
			detener_movimiento()
			if puede_atacar:
				if tipo_zombie == "explosivo": explotar()
				else: atacar(jugador) 
	else:
		detener_movimiento()

	move_and_slide()
	revisar_colisiones()
		
	# --- LÓGICA DEL JEFE (Limpia y sin duplicados) ---
	if tipo_zombie == "boss" and is_instance_valid(jugador):
		temporizador_habilidad -= delta
		if temporizador_habilidad <= 0.0 and global_position.distance_to(jugador.global_position) <= 8.0:
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
		
	# Seguridad: Si el zombie muere mientras espera, no crashea
	await get_tree().create_timer(cadencia_ataque).timeout
	if is_instance_valid(self) and not esta_muerto:
		puede_atacar = true

func revisar_colisiones():
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		var objeto_chocado = colision.get_collider()
		
		if objeto_chocado and objeto_chocado.is_in_group("barricadas") and puede_atacar:
			atacar(objeto_chocado)

# --- JEFE: GOLPE SÍSMICO ---
func iniciar_golpe_sismico():
	esta_cargando_ataque = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(3.0, 3.0, 3.0), 1.0) 
	
	await get_tree().create_timer(1.0).timeout
	
	# Validación estricta post-espera
	if not is_instance_valid(self) or esta_muerto: return
		
	ejecutar_golpe_sismico()
	scale = Vector3(2.5, 2.5, 2.5)
	esta_cargando_ataque = false

func ejecutar_golpe_sismico():
	var radio_impacto = 6.0 
	var dano_habilidad = int(dano_ataque_actual * 1.5) 
	
	if is_instance_valid(jugador) and global_position.distance_to(jugador.global_position) <= radio_impacto:
		if jugador.has_method("recibir_dano"): jugador.recibir_dano(dano_habilidad)
				
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for defensa in barricadas:
		if is_instance_valid(defensa) and global_position.distance_to(defensa.global_position) <= radio_impacto:
			if defensa.has_method("recibir_dano"): defensa.recibir_dano(dano_habilidad)

# --- ZOMBIE EXPLOSIVO ---
func explotar():
	puede_atacar = false 
	if is_instance_valid(jugador) and jugador.has_method("recibir_dano"):
		jugador.recibir_dano(dano_ataque_actual)
	
	recibir_dano(salud_actual) # Autodestrucción usando el flujo normal de muerte

# ==========================================================
# 6. SISTEMA DE DAÑO Y MUERTE
# ==========================================================
func recibir_dano(cantidad: int):
	if esta_muerto: return 
		
	salud_actual -= cantidad
	
	if salud_actual <= 0:
		esta_muerto = true 
		
		var mundo = get_parent()
		if is_instance_valid(mundo):
			if mundo.has_method("zombie_eliminado"): mundo.zombie_eliminado()
			if mundo.has_method("spawn_loot"): mundo.spawn_loot(global_position, tipo_zombie) 
			
		queue_free()
