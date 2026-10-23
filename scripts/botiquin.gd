extends Area3D

# GDD: Cura el 25% de la salud
# FIX (revisión de código): esta variable existía pero nunca se usaba —
# el código llamaba curar(0.5) hardcodeado, con un comentario que decía
# "cura el 50%" mientras la variable y el comentario de arriba dicen 25%.
# Ahora se usa la variable. Si el valor correcto es 50% en vez de 25%,
# cambiá el número de esta línea nada más.
var porcentaje_curacion: float = 0.25
var ya_recolectado: bool = false

func _ready():
	body_entered.connect(_al_recoger)

func _process(delta):
	rotate_y(2.0 * delta) # Que gire rápido para que lo veas en la urgencia

# --- FIX (revisión de código) ---
# Mismo problema que caja_municion.gd: cada peer se destruía el botiquín
# SOLO en su propia pantalla al tocarlo, dejando un "fantasma" visible para
# el resto del equipo (o permitiendo curas duplicadas si dos lo tocaban
# casi a la vez). Ahora solo el dueño real del jugador que lo tocó procesa
# la cura, y es el SERVIDOR quien lo destruye de verdad para todos.
func _al_recoger(cuerpo):
	if not cuerpo.is_in_group("jugador"): return
	if not cuerpo.is_multiplayer_authority(): return
	if ya_recolectado: return
	ya_recolectado = true

	if cuerpo.has_method("curar"):
		cuerpo.curar(porcentaje_curacion) # Cura el % definido arriba de su vida máxima

	solicitar_destruir_servidor.rpc_id(1)

# --- FIX (revisión de código) ---
# Faltaba "call_local". Cuando el HOST (id 1) era quien tocaba el botiquín,
# su propio ".rpc_id(1)" apuntaba a sí mismo, y sin call_local Godot bloquea
# eso entero ("RPC on yourself is not allowed"), así que el Host nunca
# lograba destruirlo. Con call_local, si el que llama y el destino son el
# mismo peer, se ejecuta directo en vez de rechazarse.
@rpc("any_peer", "call_local", "reliable")
func solicitar_destruir_servidor():
	if not multiplayer.is_server(): return
	queue_free()
