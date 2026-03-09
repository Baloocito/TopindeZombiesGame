extends CharacterBody3D

# --- STATS BASE ---
var salud_maxima_base: int = 1
var velocidad: float = 2.5
var dano_ataque_base: int = 1
var cadencia_ataque: float = 1.0 # ¡NUEVO! Habíamos perdido esta variable

# --- STATS ESCALADOS ---
var salud_actual: int
var dano_ataque_actual: int

var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")
var jugador: Node3D
var puede_atacar: bool = true
var esta_muerto: bool = false # ¡NUEVO ESCUDO ANTI-BUGS!

# --- VARIABLES DE LOOT ---
var tiempo_vivo: float = 0.0
var costo_en_presupuesto: int = 10
var tipo_zombie: String = "basico"

func _ready():
	var jugadores_en_mapa = get_tree().get_nodes_in_group("jugador")
	if jugadores_en_mapa.size() > 0:
		jugador = jugadores_en_mapa[0]


func nacer(numero_oleada: int, costo: int, tipo: String = "basico"):
	costo_en_presupuesto = costo
	tipo_zombie = tipo 
	
	# 1. CONFIGURAMOS LAS STATS BASE SEGÚN EL TIPO
	if tipo == "corredor":
		salud_maxima_base = 1
		velocidad = 4.0 # Muy rápido
		dano_ataque_base = 1
		scale = Vector3(0.8, 0.8, 0.8) # Un poco más pequeño y escurridizo
		
	elif tipo == "tanque":
		salud_maxima_base = 5 # Resiste 5 balas desde el día 1
		velocidad = 1.2 # Muy lento
		dano_ataque_base = 3 # Destroza barricadas rápido
		scale = Vector3(1.3, 1.3, 1.3) # Robusto y gordo
		
	elif tipo == "boss":
		salud_maxima_base = 15
		velocidad = 1.8 # Velocidad media
		dano_ataque_base = 5
		scale = Vector3(1.8, 1.8, 1.8) # Gigante
		
	else: # basico
		salud_maxima_base = 2
		velocidad = 2.5
		dano_ataque_base = 1
		scale = Vector3(1, 1, 1) # Tamaño normal
	
	# 2. FÓRMULA DE ESCALADO MUNDIAL
	var multiplicador = 1.0 + (0.1 * numero_oleada)
	
	# 3. Aplicamos el escalado a la base que acabamos de elegir
	salud_actual = int(salud_maxima_base * multiplicador)
	dano_ataque_actual = int(dano_ataque_base * multiplicador)
	
func _physics_process(delta):
	# Cronómetro de supervivencia del zombie
	tiempo_vivo += delta
	
	# 1. Gravedad
	if not is_on_floor():
		velocity.y -= gravedad * delta		
	# 2. Persecución
	if jugador:
		var distancia = global_position.distance_to(jugador.global_position)
		if distancia > 1.2: # Cambié a 1.2 para dar un poquito de margen de colisión
			# ... (Tu código de movimiento actual hacia el jugador se queda igual aquí) ...
			var direccion = global_position.direction_to(jugador.global_position)
			direccion.y = 0
			direccion = direccion.normalized()
			velocity.x = direccion.x * velocidad
			velocity.z = direccion.z * velocidad
			look_at(Vector3(jugador.global_position.x, global_position.y, jugador.global_position.z), Vector3.UP)
		else:
			# ¡NUEVO! El zombie te alcanzó
			velocity.x = move_toward(velocity.x, 0, velocidad)
			velocity.z = move_toward(velocity.z, 0, velocidad)
			
			# ¡TE MUERDE!
			if puede_atacar:
				atacar(jugador)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)

	# move_and_slide() mueve al zombie y calcula si chocó contra algo
	move_and_slide()
	
	# 3. Revisar si chocamos con una barricada en este frame
	revisar_colisiones()

func revisar_colisiones():
	# get_slide_collision_count() nos dice contra cuántas cosas estamos empujando
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		var objeto_chocado = colision.get_collider()
		
		# Si lo que tocamos tiene la etiqueta "barricadas"
		if objeto_chocado and objeto_chocado.is_in_group("barricadas"):
			if puede_atacar:
				atacar(objeto_chocado)

func atacar(objetivo):
	puede_atacar = false # Apagamos el ataque
	
	if objetivo.has_method("recibir_dano"):
		# ¡CORREGIDO! Ahora usa el daño escalado por la oleada
		objetivo.recibir_dano(dano_ataque_actual)
		
	# Esperamos un segundo antes de poder volver a morder
	await get_tree().create_timer(cadencia_ataque).timeout
	puede_atacar = true

func recibir_dano(cantidad: int):
	# ¡EL ESCUDO!: Si ya murió por otro perdigón en este exacto frame, ignoramos el golpe
	if esta_muerto:
		return 
		
	# Le restamos la vida
	salud_actual -= cantidad
	
	if salud_actual <= 0:
		# ¡Marcamos su certificado de defunción para que los demás perdigones lo ignoren!
		esta_muerto = true 
		
		var mundo = get_parent()
		
		# 1. Avisamos que morimos (Una sola vez)
		if mundo.has_method("zombie_eliminado"):
			mundo.zombie_eliminado()
			
		# 2. Soltamos el botín
		if mundo.has_method("spawn_loot"):
			mundo.spawn_loot(global_position, tipo_zombie) 
			
		# Nos eliminamos de la memoria
		queue_free()
