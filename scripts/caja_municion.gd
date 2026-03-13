extends Area3D

var cantidad_balas: int = 30
var tipo_municion: String = "Ligera"

func configurar(tipo: String, cantidad: int):
	tipo_municion = tipo
	cantidad_balas = cantidad
	
	# 1. Creamos un material nuevo para pintarla
	var material = StandardMaterial3D.new()
	
	# 2. Elegimos el color según tu GDD
	if tipo == "Ligera":
		material.albedo_color = Color(0, 0, 1) # Azul puro
	elif tipo == "Pesada":
		material.albedo_color = Color(0, 1, 0) # Verde puro
	elif tipo == "Energia":
		material.albedo_color = Color(1, 0, 0) # Rojo puro
	else:
		material.albedo_color = Color(1, 1, 1) # Blanco por si hay error
		
	var modelo_visual = $MeshInstance3D
	
	if modelo_visual:
		modelo_visual.material_override = material

# Señal cuando el jugador la pisa
func _on_body_entered(body):
	if body.is_in_group("jugador"):
		if body.has_method("recoger_municion"):
			body.recoger_municion(cantidad_balas, tipo_municion)
			queue_free() # Destruimos la caja
