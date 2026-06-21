extends Control

@onready var texto_proximamente = $TextoProximamente

func _ready():
	# Nos aseguramos de que el texto de aviso esté invisible al inicio
	texto_proximamente.modulate.a = 0.0
	texto_proximamente.visible = false

# ==========================================
# SEÑALES DE LOS BOTONES
# ==========================================

func _on_boton_jugar_pressed():
	# ¡Ahora pasamos a la sala de espera multijugador primero!
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn") 
	# OJO: Asegúrate de que la ruta "res://Lobby.tscn" coincida exactamente con donde tienes guardada tu escena del Lobby.

func _on_boton_ranking_pressed():
	# Leemos directamente la variable de nuestro Singleton
	var record_dia = GuardadoGlobal.record_oleada
	var total_muertes = GuardadoGlobal.zombies_totales
	
	var texto_estadisticas = "TUS RÉCORDS:\n\nMejor Día: %s\nZombies Eliminados: %s" % [record_dia, total_muertes]
	
	mostrar_aviso(texto_estadisticas)
func _on_boton_opciones_pressed():
	mostrar_aviso("MENÚ DE OPCIONES")

func _on_boton_salir_pressed():
	# Cierra la aplicación/juego
	get_tree().quit()

# ==========================================
# ANIMACIÓN DEL "PRÓXIMAMENTE"
# ==========================================
func mostrar_aviso(modulo: String):
	texto_proximamente.text = modulo + "\n¡Próximamente!"
	texto_proximamente.visible = true
	
	# Reiniciamos la transparencia por si se toca muchas veces rápido
	texto_proximamente.modulate.a = 1.0 
	
	var tween = create_tween()
	# Espera 1 segundo y luego se desvanece en 0.5 segundos
	tween.tween_interval(1.0)
	tween.tween_property(texto_proximamente, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): texto_proximamente.visible = false)
