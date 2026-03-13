extends Area3D

# GDD: Cura el 25% de la salud
var porcentaje_curacion: float = 0.25 

func _ready():
	body_entered.connect(_al_recoger)

func _process(delta):
	rotate_y(2.0 * delta) # Que gire rápido para que lo veas en la urgencia

func _al_recoger(cuerpo):
	if cuerpo.is_in_group("jugador"):
		# Verificamos que el jugador tenga la función que actualiza la barra
		if cuerpo.has_method("curar"):
			cuerpo.curar(0.5) # Cura el 50% de su vida máxima actual (stat_salud_maxima)
			queue_free() # Destruimos el botiquín
