extends Node

const RUTA_GUARDADO = "user://datos_topingames.save"

var record_oleada: int = 1
var zombies_totales: int = 0

func _ready():
	# Apenas se abre el juego, intentamos leer la memoria del celular/PC
	cargar_datos()

func guardar_datos():
	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	
	# Empaquetamos todo en un objeto fácil de leer
	var datos = {
		"record_oleada": record_oleada,
		"zombies_totales": zombies_totales
	}
	
	# Lo transformamos a un string JSON y lo escribimos en el disco duro
	var json_string = JSON.stringify(datos)
	archivo.store_line(json_string)
	archivo.close()
	print("¡Partida Guardada Exitosamente!")

func cargar_datos():
	if not FileAccess.file_exists(RUTA_GUARDADO):
		print("No hay partida previa. Empezamos de cero.")
		return 

	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	var json_string = archivo.get_line()
	archivo.close()

	# Desempaquetamos el JSON
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var datos_recuperados = json.data
		if typeof(datos_recuperados) == TYPE_DICTIONARY:
			# El segundo parámetro (1 y 0) es el valor por defecto por si falla
			record_oleada = datos_recuperados.get("record_oleada", 1)
			zombies_totales = datos_recuperados.get("zombies_totales", 0)
			print("¡Datos Cargados! Récord: Día ", record_oleada)
