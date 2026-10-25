extends Label
class_name MedidorRendimiento
# ==========================================================
# MEDIDOR DE RENDIMIENTO (Fase 1)
# ==========================================================
# Muestra FPS, tiempo de frame, zombies vivos y nodos en escena, para medir
# en el teléfono cuántos zombies aguanta (Manual v3 §11: tope de 70).
# Visible en builds de depuración (el APK de prueba); oculto en la versión
# final. En PC se alterna con F3.

var _acumulado := 0.0
var _peor_frame_ms := 0.0

func _ready():
	name = "MedidorRendimiento"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.is_debug_build()
	position = Vector2(8, 150)
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible

func _process(delta):
	_peor_frame_ms = maxf(_peor_frame_ms, delta * 1000.0)
	_acumulado += delta
	if _acumulado < 0.5 or not visible: return
	_acumulado = 0.0
	var zombies := get_tree().get_nodes_in_group("enemigos").size()
	text = "FPS %d | peor frame %.0f ms\nZombies %d | Nodos %d | %s" % [
		Engine.get_frames_per_second(), _peor_frame_ms, zombies,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		_rol()]
	_peor_frame_ms = 0.0

func _rol() -> String:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return "Sin conexión"
	return "Servidor" if multiplayer.is_server() else "Cliente"
