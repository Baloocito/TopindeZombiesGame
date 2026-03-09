extends Area3D

var valor_oro: int = 0

func _ready():
	# Le decimos al Area3D que avise cuando un cuerpo físico entre en su zona
	body_entered.connect(_al_recoger)

func _process(delta):
	# Para que gire bonita en el suelo
	rotate_y(2.0 * delta)

# Esta función se dispara mágicamente gracias a la máscara de colisión
func _al_recoger(cuerpo: Node3D):
	# Confirmamos que el que nos pisó tiene la etiqueta "jugador"
	if cuerpo.is_in_group("jugador"):
		var mundo = get_parent()
		
		# Le mandamos el dinero a la Billetera Global
		if mundo.has_method("sumar_dinero"):
			mundo.sumar_dinero(valor_oro)
			
		# ¡Nos destruimos para que desaparezca de la pantalla!
		queue_free()
