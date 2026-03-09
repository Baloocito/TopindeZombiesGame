extends Area3D

# GDD: Cura el 25% de la salud
var porcentaje_curacion: float = 0.25 

func _ready():
	body_entered.connect(_al_recoger)

func _process(delta):
	rotate_y(2.0 * delta) # Que gire rápido para que lo veas en la urgencia

func _al_recoger(cuerpo: Node3D):
	if cuerpo.is_in_group("jugador"):
		# ¡MAGIA TÁCTICA! Solo lo recogemos si nos falta vida
		if cuerpo.salud_actual < cuerpo.salud_maxima:
			if cuerpo.has_method("curar"):
				cuerpo.curar(porcentaje_curacion)
			
			# Destruimos el botiquín del suelo
			queue_free()
		else:
			print("Vida al máximo. Guardando botiquín para después.")
