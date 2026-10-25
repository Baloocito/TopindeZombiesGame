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

# ==========================================================
# PARTIDA EN CURSO (Fase 1: guardado al cerrar cada noche)
# ==========================================================
# Solo la guarda el anfitrión. Se sobrescribe al terminar cada noche y se
# borra con el Game Over.
const RUTA_PARTIDA := "user://partida_guardada.json"

func guardar_partida(datos: Dictionary) -> void:
	var f := FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(datos, "\t"))

func existe_partida() -> bool:
	return FileAccess.file_exists(RUTA_PARTIDA)

func cargar_partida() -> Dictionary:
	if not existe_partida(): return {}
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PARTIDA))
	return datos if typeof(datos) == TYPE_DICTIONARY else {}

func borrar_partida() -> void:
	if existe_partida():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PARTIDA))
