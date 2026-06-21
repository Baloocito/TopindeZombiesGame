extends StaticBody3D

@export_category("Propiedades de la Estructura")
var tipo_estructura: String = ""
@export var salud_maxima: int = 500 
# ¡IMPORTANTE!: Usamos @export para que el Synchronizer pueda ver esta variable
@export var salud_actual: int 

var tween_dano: Tween 

func _ready():
	if not is_in_group("barricadas"):
		add_to_group("barricadas")
	
	# El Host es el único que inicializa la vida real
	if multiplayer.is_server():
		salud_actual = salud_maxima

func recibir_dano(cantidad: int):
	# Solo el Servidor procesa la lógica de daño
	if not multiplayer.is_server(): return
	
	salud_actual -= cantidad
	
	# La animación visual se ejecutará en todos gracias al MultiplayerSynchronizer
	# que replicará el cambio de 'salud_actual' y 'scale'
	animar_dano()
	
	if salud_actual <= 0:
		destruir.rpc() # Avisamos a todos que destruyan el objeto

# Nueva función para centralizar la animación que verán todos
func animar_dano():
	if tween_dano: tween_dano.kill()
	tween_dano = create_tween()
	var proporcion = max(0.4, float(salud_actual) / float(salud_maxima))
	var escala_base = Vector3(1, 1, 1) * (0.6 + (0.4 * proporcion))
	tween_dano.tween_property(self, "scale", escala_base * 0.8, 0.05)
	tween_dano.tween_property(self, "scale", escala_base, 0.15).set_trans(Tween.TRANS_BOUNCE)

@rpc("call_local", "reliable")
func destruir():
	# Esta función se ejecuta en TODOS a la vez al recibir la orden del servidor
	var mundo = get_parent()
	if is_instance_valid(mundo):
		if mundo.has_method("celdas_ocupadas"):
			# ... tu lógica de borrar de la grilla ...
			pass
		if mundo.has_method("generar_chatarra") and multiplayer.is_server():
			mundo.generar_chatarra(global_position)
	queue_free()

# --- REPARACIÓN ---
func reparar_completamente():
	if not multiplayer.is_server(): return
	salud_actual = salud_maxima
	# La animación ocurrirá en todos porque el synchronizer replicará la salud_actual
