extends Area3D

var arma_id_contenida: String = ""
var tier_del_plano: int = 1
var ya_recolectado: bool = false

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

# --- FIX (revisión de código) ---
# Bug doble acá:
# 1. Igual que la munición/botiquín: cada peer se destruía el plano SOLO en
#    su propia pantalla, dejando un "fantasma" visible para el resto.
# 2. Peor todavía -- "planos_desbloqueados" es la lista de planos de TODO EL
#    EQUIPO (vive en mundo.gd, no en el jugador). Se estaba modificando SOLO
#    en la pantalla de quien tocaba el plano: para el resto del equipo ese
#    plano nunca aparecía en su Mesa de Trabajo, aunque lo hubiera recogido
#    un compañero. Ahora: el que lo toca (y solo el dueño real de ese
#    jugador) le avisa al servidor, el servidor reparte el plano a TODOS
#    (mundo.agregar_plano_para_todos, mismo patrón que ya usamos para el
#    oro) y recién ahí se destruye el objeto para todos.
func _on_body_entered(body):
	if not body.is_in_group("jugador"): return
	if not body.is_multiplayer_authority(): return
	if ya_recolectado: return
	if arma_id_contenida == "": return
	ya_recolectado = true
	solicitar_recoger_plano_servidor.rpc_id(1)

# --- FIX (revisión de código) ---
# Faltaba "call_local". Cuando el HOST (id 1) era quien tocaba el plano, su
# propio ".rpc_id(1)" apuntaba a sí mismo, y sin call_local Godot bloquea eso
# entero ("RPC on yourself is not allowed by selected mode") -- por eso el
# Host no podía recoger objetos. Con call_local, si el que llama y el
# destino son el mismo peer, se ejecuta directo en vez de rechazarse.
@rpc("any_peer", "call_local", "reliable")
func solicitar_recoger_plano_servidor():
	if not multiplayer.is_server(): return
	var mundo = get_tree().current_scene
	if mundo.has_method("agregar_plano_para_todos") and arma_id_contenida != "":
		mundo.agregar_plano_para_todos.rpc(arma_id_contenida)
	queue_free()
