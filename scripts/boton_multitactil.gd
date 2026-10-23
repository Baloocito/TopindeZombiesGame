extends BaseButton # <--- ¡Este es el único cambio!

func _gui_input(event):
	# Si un dedo FÍSICO (no importa cuál) toca este botón...
	if event is InputEventScreenTouch and event.pressed:
		pressed.emit() # ¡Fuerza al botón a enviar su señal de presionado!
		accept_event() # Le dice a Godot: "Ya me encargué, no hagas nada más"
		
	# Bloqueamos el "ratón fantasma" para que el botón no se presione dos veces
	elif event is InputEventMouseButton:
		accept_event()
 
