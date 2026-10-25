extends PickupBase
# Botiquín: cura un porcentaje de la vida máxima de quien lo recoge.

var porcentaje_curacion: float = 0.25

func _process(delta):
	rotate_y(2.0 * delta)

func al_recoger_local(cuerpo: Node3D) -> void:
	if cuerpo.has_method("curar"):
		cuerpo.curar(porcentaje_curacion)
