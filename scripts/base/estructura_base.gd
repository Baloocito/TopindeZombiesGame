extends StaticBody3D
class_name EstructuraBase
# ==========================================================
# BASE DE TODA ESTRUCTURA CONSTRUIBLE (barricadas y torreta)
# ==========================================================
# El servidor es la autoridad de la vida. La destrucción es una RPC para
# TODOS: antes la torreta solo se borraba en el servidor y quedaba como
# fantasma en las demás pantallas, y ninguna estructura liberaba su casilla
# (no se podía volver a construir en ese lugar).
#
# Las estructuras se crean en cada peer por RPC (no por MultiplayerSpawner),
# así que mundo.gd les da un nombre fijo según su casilla: así el
# MultiplayerSynchronizer encuentra el mismo nodo en todas las pantallas.

@export var tipo_estructura: String = ""
@export var salud_maxima: int = 500
@export var salud_actual: int = 500

var _destruida: bool = false

func _ready():
	if not is_in_group("barricadas"):
		add_to_group("barricadas")

# Daño desde zombies (corre en el servidor).
func recibir_dano(cantidad: int):
	if not multiplayer.is_server() or _destruida: return
	salud_actual -= cantidad
	al_recibir_dano()
	if salud_actual <= 0:
		_destruida = true
		destruir.rpc()

func al_recibir_dano() -> void:
	pass

@rpc("authority", "call_local", "reliable")
func destruir():
	var mundo = get_tree().current_scene
	if mundo:
		if mundo.has_method("liberar_celda"):
			mundo.liberar_celda(global_position)
		if multiplayer.is_server() and mundo.has_method("generar_chatarra"):
			mundo.generar_chatarra(global_position)
	queue_free()

func reparar_completamente():
	if not multiplayer.is_server(): return
	salud_actual = salud_maxima

func obtener_costo_reparacion(precio_base_nuevo: int) -> int:
	if salud_actual >= salud_maxima: return 0
	var porcentaje_dano = 1.0 - (float(salud_actual) / float(salud_maxima))
	return int((precio_base_nuevo * 0.5) * porcentaje_dano)
