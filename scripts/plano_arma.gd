extends Area3D

var arma_id_contenida: String = ""
var tier_del_plano: int = 1

@onready var luz = $OmniLight3D
@onready var malla = $MeshInstance3D
var tiempo_flotacion: float = 0.0

func _ready():
	# Conectamos la señal para cuando el jugador lo toque
	body_entered.connect(_on_body_entered)

func _process(delta):
	# ¡Efecto holográfico! Gira y flota suavemente arriba y abajo
	tiempo_flotacion += delta
	position.y += sin(tiempo_flotacion * 4.0) * 0.005 
	rotation.y += 2.0 * delta 

func generar_plano(tier_maximo: int, es_elite: bool):
	var mundo = get_tree().current_scene
	if not "bd_armas" in mundo: return
	
	var armas_validas = []
	for id in mundo.bd_armas.keys():
		var arma = mundo.bd_armas[id]
		
		# Prohibido soltar la pistola inicial. 
		# ¡Pero AHORA SÍ permitimos soltar planos que ya tienes!
		if id == "pistola": 
			continue 
		
		if es_elite and arma.tier == tier_maximo: 
			armas_validas.append(id)
		elif not es_elite and arma.tier <= tier_maximo: 
			armas_validas.append(id)
			
	if armas_validas.is_empty():
		queue_free()
		return
		
	arma_id_contenida = armas_validas.pick_random()
	tier_del_plano = mundo.bd_armas[arma_id_contenida].tier
	configurar_color_por_tier()

func configurar_color_por_tier():
	var color_tier = Color.WHITE
	match tier_del_plano:
		1: color_tier = Color(0.8, 0.8, 0.8) # Común (Blanco/Gris)
		2: color_tier = Color(0.1, 0.9, 0.1) # Poco Común (Verde Neón)
		3: color_tier = Color(0.1, 0.5, 1.0) # Raro (Azul Brillante)
		4: color_tier = Color(0.9, 0.2, 0.9) # Épico/Legendario (Morado)
		
	if luz: luz.light_color = color_tier
	if malla and malla.material_override:
		malla.material_override.albedo_color = color_tier
		malla.material_override.emission = color_tier

func _on_body_entered(body):
	if body.is_in_group("jugador"):
		var mundo = get_tree().current_scene
		if "planos_desbloqueados" in mundo and arma_id_contenida != "":
			# Ahora ACUMULA todos los planos que recojas
			mundo.planos_desbloqueados.append(arma_id_contenida)
			print("¡PLANO RECOGIDO!: ", mundo.bd_armas[arma_id_contenida].nombre)
				
		queue_free()
