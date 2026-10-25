extends JefeIA
# Nodo de energía del Hospedero (fase 3): no se mueve ni ataca. Al romperse
# avisa al Hospedero, que decide si queda expuesto.

var hospedero: Node = null

func procesar(_delta: float):
	z.velocity.x = 0.0
	z.velocity.z = 0.0

func al_recibir_dano(_cantidad: int):
	pass

func al_morir():
	if is_instance_valid(hospedero) and hospedero.has_method("nodo_destruido"):
		hospedero.nodo_destruido(z)
