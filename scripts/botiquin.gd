extends PickupBase
# Botiquín: cura un porcentaje de la vida máxima de quien lo recoge.

var porcentaje_curacion: float = 0.25

func _ready():
	super._ready()
	# Modelo del PSX Asset Pack 3 en vez de la cápsula.
	var modelo := ModelosPSX.objeto("First_aid_kit_variant_one", 0.8)
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false
		modelo.position.y = $MeshInstance3D.position.y - 0.25
	add_child(modelo)

func _process(delta):
	rotate_y(2.0 * delta)

func al_recoger_local(cuerpo: Node3D) -> void:
	if cuerpo.has_method("curar"):
		cuerpo.curar(porcentaje_curacion)

func texto_recogida() -> Array:
	return ["+%d%% vida" % int(porcentaje_curacion * 100), Color("#4ade80")]
