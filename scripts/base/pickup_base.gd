extends Area3D
class_name PickupBase
# ==========================================================
# BASE DE TODO OBJETO RECOGIBLE (moneda, munición, botiquín, plano)
# ==========================================================
# Reglas de red (Manual v2 §0.H, aprendidas a fuerza de bugs):
#  - Solo el dueño del personaje que lo toca pide recogerlo (rpc_id(1)).
#  - Solo el SERVIDOR lo destruye, y solo una vez aunque dos lo toquen a la vez.
#  - Lo que afecta a todo el equipo (oro, planos) lo decide el servidor.
# Cada pickup sobreescribe solo los dos ganchos de abajo.

var ya_recolectado: bool = false          # bloqueo local: no mandar el pedido dos veces
var _procesado_en_servidor: bool = false  # bloqueo del servidor: no premiar dos veces

func _ready():
	if not body_entered.is_connected(_al_entrar_cuerpo):
		body_entered.connect(_al_entrar_cuerpo)

func _al_entrar_cuerpo(cuerpo: Node3D):
	if puede_recoger(cuerpo):
		recolectar(cuerpo)

func puede_recoger(cuerpo: Node3D) -> bool:
	if ya_recolectado or not is_instance_valid(cuerpo): return false
	if not cuerpo.is_in_group("jugador"): return false
	if not cuerpo.is_multiplayer_authority(): return false
	if "esta_caido" in cuerpo and cuerpo.esta_caido: return false
	return true

func recolectar(cuerpo: Node3D):
	ya_recolectado = true
	al_recoger_local(cuerpo)
	var aviso := texto_recogida()
	if not aviso.is_empty():
		EstiloUI.texto_flotante(cuerpo.global_position, aviso[0], aviso[1])
	_solicitar_recoleccion.rpc_id(1)

# [texto, color] que se muestra flotando al recogerlo (vacío = nada).
func texto_recogida() -> Array:
	return []

@rpc("any_peer", "call_local", "reliable")
func _solicitar_recoleccion():
	if not multiplayer.is_server() or _procesado_en_servidor: return
	_procesado_en_servidor = true
	al_recoger_servidor(multiplayer.get_remote_sender_id())
	queue_free()

# Efecto personal en la pantalla de quien lo recoge (munición, curación).
func al_recoger_local(_cuerpo: Node3D) -> void:
	pass

# Efecto de equipo, decidido por el servidor (oro, planos).
func al_recoger_servidor(_id_remitente: int) -> void:
	pass

func mundo() -> Node:
	return get_tree().current_scene
