extends CharacterBody3D

# --- STATS BASE ---
var salud_maxima_base: int = 1
var velocidad: float = 2.5
var dano_ataque_base: int = 1
var cadencia_ataque: float = 1.0 # ¡NUEVO! Habíamos perdido esta variable
var rango_ataque: float = 1.5 # Distancia a la que el zombie lanza el golpe
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") # ¡ESTA ES LA LÍNEA MÁGICA!
# --- STATS ESCALADOS ---
var salud_actual: int
var dano_ataque_actual: int

var salud_maxima: int = 40

# --- HABILIDADES DE JEFE ---
var cooldown_habilidad: float = 5.0 # Cada cuántos segundos usa su poder
var temporizador_habilidad: float = 0.0
var esta_cargando_ataque: bool = false

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
	rango_ataque = 1.2 * scale.x
	
	# 1. STATS BASE EXACTAS DEL GDD
	if tipo == "corredor":
		salud_maxima_base = 25
		dano_ataque_base = 8
		velocidad = 4.0
		scale = Vector3(0.8, 0.8, 0.8) # Más pequeño
		
	elif tipo == "explosivo": # ¡NUEVO!
		salud_maxima_base = 60
		dano_ataque_base = 150
		velocidad = 2.5
		scale = Vector3(1.1, 1.1, 1.1)
		# Nota: Para el suicidio/explosión necesitaremos una lógica extra en su ataque luego
		
	elif tipo == "tanque":
		salud_maxima_base = 300
		dano_ataque_base = 40
		velocidad = 1.2
		scale = Vector3(1.4, 1.4, 1.4) # Robusto
		
	elif tipo == "boss": # Mosca Tyrant
		salud_maxima_base = 1200
		dano_ataque_base = 70
		velocidad = 3.0
		scale = Vector3(2.5, 2.5, 2.5) # Gigante
		
	else: # Normal / Básico
		salud_maxima_base = 40
		dano_ataque_base = 15
		velocidad = 1.8
		scale = Vector3(1, 1, 1) 
	
	# ==========================================================
	# 2. FÓRMULAS DE ESCALADO INFINITO Y CO-OP (GDD)
	# ==========================================================
	
	# Fórmula Vida: HP(W) = HP_Base * (1.12)^(W-1)
	var multiplicador_hp_ola = pow(1.12, numero_oleada - 1)
	
	# Ajuste Co-op: La vida aumenta 60% por cada jugador ADICIONAL
	var cantidad_jugadores = get_tree().get_nodes_in_group("jugador").size()
	if cantidad_jugadores == 0: cantidad_jugadores = 1 # Seguridad por si acaso
	var multiplicador_coop = 1.0 + ((cantidad_jugadores - 1) * 0.60)
	
	# Aplicamos la vida final
	var hp_final = salud_maxima_base * multiplicador_hp_ola * multiplicador_coop
	salud_maxima = int(hp_final)
	salud_actual = salud_maxima
	
	# Fórmula Daño: Daño(W) = Daño_Base + (2 * W)
	dano_ataque_actual = dano_ataque_base + (2 * numero_oleada)
	
	# (Opcional) Imprimir en consola para ver cómo escalan en tiempo real
	# print("Nace un ", tipo, " -> HP:", salud_actual, " | Daño:", dano_ataque_actual)
	
func _physics_process(delta):
	# Cronómetro de supervivencia del zombie (si lo usas para algo)
	if "tiempo_vivo" in self: tiempo_vivo += delta
	
	# 1. Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta # O 'gravedad', dependiendo de cómo la llamaste
	# ==========================================================
	# ¡NUEVO! CONGELAMIENTO POR HABILIDAD
	# ==========================================================
	if esta_cargando_ataque:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		move_and_slide()
		return # Cortamos la función aquí para que no persiga ni muerda
	# 2. Persecución
	if is_instance_valid(jugador) and jugador.salud_actual > 0:
		var distancia = global_position.distance_to(jugador.global_position)
		
		# Usamos nuestra nueva variable dinámica en lugar del 1.2 fijo
		if distancia > rango_ataque: 
			var direccion = global_position.direction_to(jugador.global_position)
			direccion.y = 0
			direccion = direccion.normalized()
			
			velocity.x = direccion.x * velocidad
			velocity.z = direccion.z * velocidad
			
			var pos_mirar = Vector3(jugador.global_position.x, global_position.y, jugador.global_position.z)
			look_at(pos_mirar, Vector3.UP)
		else:
			# ¡NUEVO! El zombie te alcanzó
			velocity.x = move_toward(velocity.x, 0, velocidad)
			velocity.z = move_toward(velocity.z, 0, velocidad)
			
			# ¡COMPORTAMIENTOS ESPECIALES DEL GDD!
			if puede_atacar:
				if tipo_zombie == "explosivo":
					explotar() # ¡Boom!
				else:
					atacar(jugador) # Mordisco normal/tanque/boss
	else:
		# Si el jugador muere o no existe, se quedan quietos
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)

	move_and_slide()
	
	# 3. Revisar si chocamos con una barricada en este frame
	if has_method("revisar_colisiones"):
		revisar_colisiones()
		
	# ==========================================================
	# 4. INTELIGENCIA DE LA MOSCA TYRANT (BOSS)
	# ==========================================================
	if tipo_zombie == "boss" and is_instance_valid(jugador):
		temporizador_habilidad -= delta
		
# ==========================================================
	# 4. INTELIGENCIA DE LA MOSCA TYRANT (BOSS)
	# ==========================================================
	if tipo_zombie == "boss" and is_instance_valid(jugador):
		temporizador_habilidad -= delta
		
		if temporizador_habilidad <= 0.0 and global_position.distance_to(jugador.global_position) <= 8.0:
			iniciar_golpe_sismico() # <--- ¡Cambiamos esto para que inicie la carga!
			temporizador_habilidad = cooldown_habilidad
			
	# 3. Revisar si chocamos con una barricada en este frame
	if has_method("revisar_colisiones"):
		revisar_colisiones()
		
# ==========================================================
# ATAQUE ESPECIAL DEL JEFE (MOSCA TYRANT)
# ==========================================================
# ==========================================================
# ATAQUE ESPECIAL DEL JEFE (MOSCA TYRANT)
# ==========================================================
func iniciar_golpe_sismico():
	esta_cargando_ataque = true
	print("¡LA MOSCA TYRANT CARGA SU GOLPE SÍSMICO! (1 Seg para huir)")
	
	# Efecto visual: El Boss se hincha un poco antes de golpear
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(3.0, 3.0, 3.0), 1.0) 
	
	# Esperamos 1 segundo exacto (Tiempo de reacción del jugador)
	await get_tree().create_timer(1.0).timeout
	
	# ¡Seguridad vital! Revisamos si las torretas lo mataron mientras cargaba el ataque
	if not is_inside_tree() or salud_actual <= 0: 
		return
		
	# Si sobrevivió a ese segundo, ¡desata el sismo!
	ejecutar_golpe_sismico()
	
	# Vuelve a su tamaño normal de Boss (2.5) y reanuda la persecución
	scale = Vector3(2.5, 2.5, 2.5)
	esta_cargando_ataque = false

func ejecutar_golpe_sismico():
	print("¡LA MOSCA TYRANT USA GOLPE SÍSMICO!")
	
	var radio_impacto = 6.0 # Qué tan grande es la onda expansiva
	var dano_habilidad = int(dano_ataque_actual * 1.5) # El golpe especial duele un 50% más
	
	# 1. Dañar al Jugador si está en el radio
	if is_instance_valid(jugador):
		var distancia_jugador = global_position.distance_to(jugador.global_position)
		if distancia_jugador <= radio_impacto:
			if jugador.has_method("recibir_dano"):
				jugador.recibir_dano(dano_habilidad)
				print("¡El jugador fue alcanzado por el sismo!")
				
	# 2. Dañar a TODAS las Barricadas y Torretas en el radio
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for defensa in barricadas:
		if is_instance_valid(defensa):
			var distancia_defensa = global_position.distance_to(defensa.global_position)
			if distancia_defensa <= radio_impacto:
				if defensa.has_method("recibir_dano"):
					defensa.recibir_dano(dano_habilidad)
					
	# (Opcional) Si en el futuro tienes partículas de polvo o temblor de cámara, 
	# este es el lugar perfecto para llamarlos.

# ==========================================================
# ATAQUE SUICIDA DEL ZOMBIE EXPLOSIVO
# ==========================================================
func explotar():
	print("¡EL ZOMBIE EXPLOSIVO HA DETONADO!")
	puede_atacar = false # Evita que explote 2 veces en el mismo frame
	
	# 1. Le hacemos el daño masivo al jugador
	if is_instance_valid(jugador) and jugador.has_method("recibir_dano"):
		jugador.recibir_dano(dano_ataque_actual)
		
	# 2. (Opcional) Aquí podrías instanciar un sistema de partículas de explosión
	
	# 3. El zombie muere instantáneamente al explotar, pero sin dar dinero
	# (Puedes llamar a tu función morir() o simplemente destruirlo)
	queue_free()

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
