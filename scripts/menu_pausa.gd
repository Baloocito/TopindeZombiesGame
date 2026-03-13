extends CanvasLayer

# Esta variable la cambiaremos a 'true' cuando programemos el lobby online
var en_partida_online: bool = false 

func _ready():
	visible = false

func alternar_pausa():
	visible = !visible
	
	if visible:
		# Entramos al menú
		if not en_partida_online:
			get_tree().paused = true # Congelamos el tiempo solo si estamos solos
			print("Juego Pausado (Tiempo Congelado)")
		else:
			print("Menú Abierto (Partida Online - El tiempo sigue)")
	else:
		# Salimos del menú
		get_tree().paused = false # Siempre nos aseguramos de descongelar al salir

# --- SEÑALES DE LOS BOTONES ---

func _on_boton_reanudar_pressed():
	alternar_pausa()

func _on_boton_opciones_pressed():
	print("Abrir menú de opciones...") # Lo conectaremos luego

func _on_boton_abandonar_pressed():
	get_tree().paused = false # Descongelamos antes de cambiar de escena
	get_tree().change_scene_to_file("res://menu_principal.tscn")


func _on_pausa_pressed() -> void:
	pass # Replace with function body.


func _on_boton_pausa_tactil_pressed() -> void:
	pass # Replace with function body.
