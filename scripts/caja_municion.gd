extends Area3D

var cantidad_balas: int = 30
var tipo_municion: String = "Ligera"
var ya_recolectada: bool = false

func configurar(tipo: String, cantidad: int):
	tipo_municion = tipo
	cantidad_balas = cantidad
	
	# 1. Creamos un material nuevo para pintarla
	var material = StandardMaterial3D.new()
	
	# 2. Elegimos el color según tu GDD
	if tipo == "Ligera":
		material.albedo_color = Color(0, 0, 1) # Azul puro
	elif tipo == "Pesada":
		material.albedo_color = Color(0, 1, 0) # Verde puro
	elif tipo == "Energia":
		material.albedo_color = Color(1, 0, 0) # Rojo puro
	else:
		material.albedo_color = Color(1, 1, 1) # Blanco por si hay error
		
	var modelo_visual = $MeshInstance3D
	
	if modelo_visual:
		modelo_visual.material_override = material

# --- FIX (revisión de código) ---
# Antes esto se ejecutaba en la pantalla de CUALQUIER peer donde la física
# detectara el toque (incluido, potencialmente, un peer que no era el dueño
# del jugador que tocó la caja), y cada uno hacía queue_free() SOLO en su
# propia pantalla. Resultado: para el resto del equipo la caja seguía ahí
# parada (un "fantasma"), y si dos jugadores la tocaban casi a la vez podían
# cobrar munición los dos. Ahora: solo el dueño real del jugador que la tocó
# procesa el pickup (igual que moneda.gd), y es el SERVIDOR quien la destruye
# de verdad -- así desaparece una sola vez, para todos.
func _on_body_entered(body):
	if not body.is_in_group("jugador"): return
	if not body.is_multiplayer_authority(): return
	if ya_recolectada: return
	ya_recolectada = true

	if body.has_method("recoger_municion"):
		body.recoger_municion(cantidad_balas, tipo_municion)

	solicitar_destruir_servidor.rpc_id(1)

# --- FIX (revisión de código) ---
# Faltaba "call_local". Cuando el HOST (id 1) era quien tocaba la caja, su
# propio ".rpc_id(1)" apuntaba a sí mismo, y sin call_local Godot bloquea eso
# entero ("RPC on yourself is not allowed"), así que el Host nunca lograba
# destruir la caja ni sumar la munición. Con call_local, si el que llama y el
# destino son el mismo peer, se ejecuta directo en vez de rechazarse.
@rpc("any_peer", "call_local", "reliable")
func solicitar_destruir_servidor():
	if not multiplayer.is_server(): return
	queue_free()
