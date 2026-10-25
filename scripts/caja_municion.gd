extends PickupBase
# Caja de munición. tipo_municion y cantidad_balas viajan con el spawn
# (MultiplayerSynchronizer del prefab), así el cliente recibe lo mismo que
# el servidor decidió. Antes el cliente siempre recibía "Ligera x30".

const COLORES := {"Ligera": Color(1.0, 0.85, 0.2), "Pesada": Color(1.0, 0.5, 0.1), "Energia": Color(0.3, 0.8, 1.0)}

@export var cantidad_balas: int = 30
@export var tipo_municion: String = "Ligera"

func _ready():
	super._ready()
	_aplicar_color()

# El servidor la configura ANTES de agregarla al mundo, para que el spawn
# lleve los valores correctos a todos los clientes.
func configurar(tipo: String, cantidad: int):
	tipo_municion = tipo
	cantidad_balas = cantidad
	if is_inside_tree(): _aplicar_color()

func _aplicar_color():
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORES.get(tipo_municion, Color.WHITE)
	if has_node("MeshInstance3D"):
		$MeshInstance3D.material_override = material

func al_recoger_local(cuerpo: Node3D) -> void:
	if cuerpo.has_method("recoger_municion"):
		cuerpo.recoger_municion(cantidad_balas, tipo_municion)

func texto_recogida() -> Array:
	return ["+%d %s" % [cantidad_balas, tipo_municion], COLORES.get(tipo_municion, Color.WHITE)]
