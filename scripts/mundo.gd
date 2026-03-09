extends Node3D

# --- ESTADOS DEL JUEGO ---
var modo_construccion: bool = false
var fase_combate: bool = false 
var oleada_actual: int = 1     
var zombies_vivos: int = 0     

@onready var texto_game_over = $InterfazUI/TextoGameOver
@onready var boton_reiniciar = $InterfazUI/BotonReiniciar
@export var caja_municion_escena: PackedScene 
@export var botiquin_escena: PackedScene 

# --- SISTEMA DE ECONOMÍA Y CONSTRUCCIÓN ---
var dinero_global: int = 0 
var reparaciones_usadas: int = 0 
var modificador_suerte: float = 0.0 

@onready var texto_dinero = $InterfazUI/TextoDinero
@export var moneda_escena: PackedScene
@onready var boton_reparar = $InterfazUI/BotonReparar 

# Estadísticas de la "Valla de Madera" 
var barricadas_construidas: int = 0
const PRECIO_BASE_BARRICADA: int = 150
const INFLACION_BARRICADA: float = 0.10 

# --- REFERENCIAS ---
@onready var boton_construir = $InterfazUI/BotonConstruir
@onready var holograma = $Holograma
@onready var texto_estado = $InterfazUI/TextoEstado 
@onready var boton_iniciar = $InterfazUI/BotonIniciar 
@onready var texto_anuncio = $InterfazUI/TextoAnuncio 

@export var barricada_escena: PackedScene
const TAMAÑO_GRILLA: float = 2.0 
var celdas_ocupadas: Dictionary = {}

func _ready():
	holograma.visible = false
	texto_anuncio.modulate.a = 0.0 
	texto_estado.visible = false
	fase_preparacion()
	
# --- EL SISTEMA DE ANIMACIÓN (TWEENS) ---
func animar_textos(mensaje_gigante: String, mensaje_pequeno: String):
	texto_anuncio.text = mensaje_gigante
	texto_estado.text = mensaje_pequeno
	
	texto_estado.visible = false
	texto_anuncio.modulate.a = 0.0 
	
	var tween = get_tree().create_tween()
	tween.tween_property(texto_anuncio, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(texto_anuncio, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): texto_estado.visible = true)

# --- SISTEMA DE ECONOMÍA ---
func obtener_precio_barricada() -> int:
	var multiplicador = 1.0 + (INFLACION_BARRICADA * barricadas_construidas)
	return int(PRECIO_BASE_BARRICADA * multiplicador)
	
func sumar_dinero(cantidad: int):
	dinero_global += cantidad
	texto_dinero.text = "$ " + str(dinero_global)
	actualizar_boton_reparacion()

# --- LÓGICA DE OLEADAS ---
func fase_preparacion():
	fase_combate = false
	animar_textos("DÍA " + str(oleada_actual) + "\n¡Prepárate!", "Fase: Día " + str(oleada_actual))
	boton_iniciar.visible = true
	boton_construir.visible = true
	
	reparaciones_usadas = 0 
	if boton_reparar:
		boton_reparar.visible = true
		actualizar_boton_reparacion() 
	
func iniciar_oleada():
	fase_combate = true
	modo_construccion = false 
	holograma.visible = false
	
	animar_textos("¡NOCHE ETERNA!\nOleada " + str(oleada_actual), "Oleada: " + str(oleada_actual))
	
	boton_iniciar.visible = false
	boton_construir.visible = false 
	if boton_reparar:
		boton_reparar.visible = false
	
	zombies_vivos = $GeneradorZombies.preparar_oleada(oleada_actual)
	print("La horda atacará con ", zombies_vivos, " enemigos.")
	
	$GeneradorZombies.iniciar_generacion()
	
func zombie_eliminado():
	zombies_vivos -= 1
	if zombies_vivos <= 0:
		oleada_actual += 1
		fase_preparacion()

# --- LÓGICA DE CONSTRUCCIÓN ---
func alternar_modo_construccion():
	if fase_combate:
		return 
		
	modo_construccion = !modo_construccion 
	
	if modo_construccion:
		boton_construir.text = "Cancelar Construcción"
		holograma.visible = true
	else:
		boton_construir.text = "Modo Construcción"
		holograma.visible = false

func _process(delta):
	if not modo_construccion or fase_combate:
		return
		
	var pos_pantalla = get_viewport().get_mouse_position()
	var camara = get_viewport().get_camera_3d()
	if not camara: return
		
	var origen_rayo = camara.project_ray_origin(pos_pantalla)
	var direccion_rayo = camara.project_ray_normal(pos_pantalla)
	var plano_suelo = Plane(Vector3.UP, 0)
	var punto_interseccion = plano_suelo.intersects_ray(origen_rayo, direccion_rayo)
	
	if punto_interseccion != null:
		var x_cuadricula = snapped(punto_interseccion.x, TAMAÑO_GRILLA)
		var z_cuadricula = snapped(punto_interseccion.z, TAMAÑO_GRILLA)
		holograma.global_position = Vector3(x_cuadricula, 1.0, z_cuadricula)
		
		var costo_actual = obtener_precio_barricada()
		if dinero_global >= costo_actual:
			holograma.material_override.albedo_color = Color(0, 1, 0, 0.5) 
		else:
			holograma.material_override.albedo_color = Color(1, 0, 0, 0.5)
			
func _unhandled_input(event):
	if not modo_construccion or fase_combate:
		return
		
	var es_clic_raton = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var es_toque_pantalla = event is InputEventScreenTouch and event.pressed
	
	if es_clic_raton or es_toque_pantalla:
		construir_barricada()

func construir_barricada():
	if not barricada_escena: return
	
	var costo_actual = obtener_precio_barricada()
	if dinero_global < costo_actual:
		print("¡Bancarrota! Necesitas $", costo_actual)
		return 
		
	var pos_llave = Vector3(snapped(holograma.global_position.x, 0.1), 1.0, snapped(holograma.global_position.z, 0.1))
	if celdas_ocupadas.has(pos_llave):
		return
		
	sumar_dinero(-costo_actual)
	barricadas_construidas += 1
	print("Barricada construida. Próxima costará: $", obtener_precio_barricada())
		
	var nueva_barricada = barricada_escena.instantiate()
	add_child(nueva_barricada)
	nueva_barricada.global_position = holograma.global_position
	celdas_ocupadas[pos_llave] = true
	actualizar_boton_reparacion()

# --- SISTEMA DE BOTÍN Y CHATARRA ---
func spawn_loot(pos_muerte: Vector3, tipo_zombie: String):
	var bounty: int = 0
	var oro_base: int = 0
	var prob_oro: float = 0.0
	
	if tipo_zombie == "basico":
		bounty = 10; oro_base = 20; prob_oro = 40.0
	elif tipo_zombie == "corredor":
		bounty = 15; oro_base = 40; prob_oro = 50.0
	elif tipo_zombie == "tanque":
		bounty = 50; oro_base = 150; prob_oro = 100.0
	elif tipo_zombie == "boss":
		bounty = 500; oro_base = 2000; prob_oro = 100.0
		
	# 1. Pago directo a la billetera
	sumar_dinero(bounty)
	
	# ==========================================================
	# 2. SISTEMA DE DROPS DE CONSUMIBLES (PITY SYSTEM INTEGRADO)
	# ==========================================================
	var tirada_base = randf_range(1.0, 100.0)
	var dado_loot = tirada_base + modificador_suerte
	var solto_consumible: bool = false
	
	# GDD: 71 - 85 -> Caja de balas
	if dado_loot >= 71.0 and dado_loot < 86.0:
		solto_consumible = true
		if caja_municion_escena:
			var caja = caja_municion_escena.instantiate()
			var offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			caja.global_position = pos_muerte + offset
			
			# ¡Seguridad máxima!: Buscamos al jugador antes de darle valores a la caja
			var jugadores_en_mapa = get_tree().get_nodes_in_group("jugador")
			if jugadores_en_mapa.size() > 0:
				var jugador = jugadores_en_mapa[0]
				if jugador.arma_actual:
					caja.cantidad_balas = jugador.arma_actual.tamano_cargador * 2
					print("¡Drop Munición! (Suerte acumulada era: +", modificador_suerte, ")")
			
			# Añadimos al final para evitar errores de carga
			add_child(caja) 
			
	# GDD: 86 - 95 -> Curación y Supervivencia
	elif dado_loot >= 86.0 and dado_loot < 96.0:
		solto_consumible = true
		if botiquin_escena:
			var botiquin = botiquin_escena.instantiate()
			var offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			botiquin.global_position = pos_muerte + offset
			add_child(botiquin)
			print("¡Drop Épico! (Botiquín Express generado)")
		
	# GDD: 96 - 100+ -> Ítem Especial
	elif dado_loot >= 96.0:
		solto_consumible = true
		print("¡Drop Legendario! (Aquí caerá Arma Nueva o Torreta próximamente)")

	# --- RESOLUCIÓN DEL PITY SYSTEM ---
	if solto_consumible:
		modificador_suerte = 0.0 # Se reinicia la suerte al recibir un premio
	else:
		modificador_suerte += 0.5 # Aumenta la probabilidad de que el siguiente zombie suelte algo

	# ==========================================================
	# 3. TIRADA DEL ORO FÍSICO (Independiente de los consumibles)
	# ==========================================================
	var tirada_oro = randf_range(1.0, 100.0)
	if tirada_oro <= prob_oro:
		var multiplicador_inflacion = 1.0 + (0.15 * (oleada_actual - 1))
		var oro_final = int(oro_base * multiplicador_inflacion)
		
		if moneda_escena:
			var nueva_moneda = moneda_escena.instantiate()
			add_child(nueva_moneda)
			var offset_aleatorio = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			nueva_moneda.global_position = pos_muerte + offset_aleatorio
			nueva_moneda.valor_oro = oro_final
			
			
func generar_chatarra(posicion_destruccion: Vector3):
	if moneda_escena:
		var chatarra = moneda_escena.instantiate()
		add_child(chatarra)
		chatarra.global_position = posicion_destruccion
		chatarra.valor_oro = 20
		print("Barricada destruida. ¡Chatarra de $20 soltada!")

# --- SISTEMA DE REPARACIÓN GLOBAL DINÁMICA ---
func obtener_costo_reparacion() -> int:
	var costo_total = 0
	var precio_nueva = obtener_precio_barricada() 
	
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for barricada in barricadas:
		if barricada.has_method("obtener_costo_reparacion"):
			costo_total += barricada.obtener_costo_reparacion(precio_nueva)
			
	return costo_total

func actualizar_boton_reparacion():
	if not boton_reparar: return
	
	var costo = obtener_costo_reparacion()
	var usos_restantes = 1 - reparaciones_usadas 
	
	if costo == 0:
		boton_reparar.text = "Base Intacta"
		boton_reparar.disabled = true
	else:
		boton_reparar.text = "Reparar Todo ($" + str(costo) + ")\nUsos: " + str(usos_restantes) + "/1"
		
		if dinero_global < costo or usos_restantes <= 0:
			boton_reparar.disabled = true
		else:
			boton_reparar.disabled = false

func ejecutar_reparacion_global():
	var costo = obtener_costo_reparacion()
	
	if costo == 0 or dinero_global < costo or reparaciones_usadas >= 1:
		return
		
	sumar_dinero(-costo)
	reparaciones_usadas += 1
	
	var barricadas = get_tree().get_nodes_in_group("barricadas")
	for barricada in barricadas:
		if barricada.has_method("reparar_completamente"):
			barricada.reparar_completamente()
			
	print("¡Base reparada al 100% por $", costo, "!")
	actualizar_boton_reparacion()
	
# --- SISTEMA DE GAME OVER ---
func _on_boton_reiniciar_pressed():
	get_tree().reload_current_scene()

func ejecutar_game_over():
	print("¡El jugador ha muerto!")
	$GeneradorZombies/TimerSpawn.stop()
	
	texto_game_over.visible = true
	boton_reiniciar.visible = true
	
	boton_iniciar.visible = false
	boton_construir.visible = false
	if boton_reparar: boton_reparar.visible = false
