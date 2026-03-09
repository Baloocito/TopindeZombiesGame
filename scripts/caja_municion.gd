extends Area3D

var cantidad_balas: int = 0 # Lo que recarga por defecto

func _ready():
	body_entered.connect(_al_recoger)

func _process(delta):
	rotate_y(1.5 * delta) # Que gire para llamar la atención

func _al_recoger(cuerpo: Node3D):
	if cuerpo.is_in_group("jugador"):
		if cuerpo.has_method("recoger_municion"):
			# Le pasamos las balas al jugador
			cuerpo.recoger_municion(cantidad_balas)
		
		# Destruimos la caja física
		queue_free()
