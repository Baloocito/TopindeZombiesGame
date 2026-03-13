extends StaticBody3D

# --- ESTADÍSTICAS ---
var salud_maxima: int = 100
var salud_actual: int
# Identificador para la tienda y las reparaciones
var tipo_estructura: String = ""
# --- SISTEMA DE COMBATE ---
var arma_equipada: ArmaData = null # Empieza sin arma
var balas_cargadas: int = 0
var objetivo_actual: Node3D = null
var temporizador_disparo: float = 0.0
var enemigos_en_rango: Array = []

# --- REFERENCIAS ---
@onready var cabezal = $Cabezal
@onready var punto_disparo = $Cabezal/PuntoDisparo
@export var bala_escena: PackedScene # ¡Arrastra tu bala.tscn aquí en el editor!

func _ready():
	salud_actual = salud_maxima

func _physics_process(delta):
	# 1. Limpiamos la lista por si un zombie murió por otra causa (ej: el jugador lo mató)
	enemigos_en_rango = enemigos_en_rango.filter(func(enemigo): return is_instance_valid(enemigo) and enemigo.salud_actual > 0)

	# 2. Buscar objetivo si no tenemos
	if not is_instance_valid(objetivo_actual) or objetivo_actual.salud_actual <= 0:
		buscar_nuevo_objetivo()

	# 3. Apuntar y disparar (Solo si tiene arma y balas)
	if is_instance_valid(objetivo_actual) and arma_equipada and balas_cargadas > 0:
		apuntar_a_objetivo()
		
		temporizador_disparo += delta
		var tiempo_entre_balas = 1.0 / arma_equipada.cadencia
		if temporizador_disparo >= tiempo_entre_balas:
			disparar()

func apuntar_a_objetivo():
	# 1. Calculamos la posición del zombie a la misma altura de la torreta
	var pos_objetivo = objetivo_actual.global_position
	var pos_mirar = Vector3(pos_objetivo.x, cabezal.global_position.y, pos_objetivo.z)
	
	# 2. Godot apunta usando la "espalda" de tu modelo (-Z)
	cabezal.look_at(pos_mirar, Vector3.UP)
	
	# 3. ¡EL TRUCO!: Lo giramos 180 grados (PI en radianes) sobre su propio eje Y
	# para que el cañón real (+Z) quede mirando al zombie.
	cabezal.rotate_y(PI)
	

func disparar():
	temporizador_disparo = 0.0
	balas_cargadas -= 1
	
	if not bala_escena: return
	
	# La torreta respeta la dispersión y los perdigones del arma que le diste
	var dispersion_rad = 0.0
	if arma_equipada.dispersion > 0.0:
		dispersion_rad = deg_to_rad(arma_equipada.dispersion)
		
	for i in range(arma_equipada.balas_por_disparo):
		var nueva_bala = bala_escena.instantiate()
		get_tree().current_scene.add_child(nueva_bala)
		nueva_bala.global_transform = punto_disparo.global_transform
		
		if dispersion_rad > 0.0:
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)
			
		if "dano" in nueva_bala:
			nueva_bala.dano = arma_equipada.dano

# --- SISTEMA DE VISIÓN (Señales) ---
func _on_area_deteccion_body_entered(body):
	print("ALGO ENTRÓ EN EL RADAR: ", body.name) # <-- Añade esto para espiar
	if body.is_in_group("enemigos"):
		enemigos_en_rango.append(body)

func _on_area_deteccion_body_exited(body):
	if body in enemigos_en_rango:
		enemigos_en_rango.erase(body)
		if objetivo_actual == body:
			objetivo_actual = null

func buscar_nuevo_objetivo():
	if enemigos_en_rango.size() > 0:
		objetivo_actual = enemigos_en_rango[0] # Fija al zombie que lleva más tiempo en su zona
	else:
		objetivo_actual = null

# --- SISTEMA DE DAÑO Y REPARACIÓN ---
func recibir_dano(cantidad: int):
	salud_actual -= cantidad
	if salud_actual <= 0:
		var mundo = get_parent()
		if mundo.has_method("generar_chatarra"):
			mundo.generar_chatarra(global_position)
		queue_free()

func obtener_costo_reparacion(precio_base_nuevo: int) -> int:
	if salud_actual >= salud_maxima: return 0
	var porcentaje_dano = 1.0 - (float(salud_actual) / float(salud_maxima))
	# Repararla cuesta la mitad que una nueva, proporcional al daño
	return int((precio_base_nuevo * 0.5) * porcentaje_dano)

func reparar_completamente():
	salud_actual = salud_maxima
	
	# --- INTERACCIÓN TÁCTIL ---
func _input_event(camera, event, position, normal, shape_idx):
	# Si es de día y tocamos la torreta con el clic izquierdo o el dedo
	var es_clic = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var es_toque = event is InputEventScreenTouch and event.pressed
	
	if es_clic or es_toque:
		var mundo = get_tree().current_scene
		# Le avisamos al mundo que abra nuestro panel de control
		if mundo.has_method("abrir_menu_inspector"):
			mundo.abrir_menu_inspector(self) # "self" significa "Yo, esta torreta exacta"
