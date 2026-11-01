class_name DescubrimientoLan
extends Node
## Encuentra partidas en la misma red Wi-Fi sin escribir IPs.
##
## El anfitrión grita "¡aquí hay una sala!" por broadcast UDP cada segundo y
## quien busca partida escucha ese grito. Así la sala aparece sola en la lista
## del lobby. La conexión del juego sigue siendo ENet en PUERTO_RED (7000);
## esto solo sirve para encontrarse, en un puerto aparte.

signal salas_cambiaron(salas: Array)

const PUERTO := 7001
const FIRMA := "TOPINZ1"
const INTERVALO := 1.0   # cada cuánto se anuncia la sala
const CADUCA := 3.5      # sin noticias por este tiempo, la sala desaparece de la lista

var _anunciando := false
var _info := {}
var _envio := PacketPeerUDP.new()
var _escucha := PacketPeerUDP.new()
var _escuchando := false
var _salas := {}   # ip -> { ip, nombre, jugadores, maximo, clave, visto }
var _t := 0.0


## Empieza a escuchar anuncios. Devuelve false si el puerto no se pudo abrir
## (otra copia del juego en el mismo equipo ya lo está usando).
func escuchar() -> bool:
	if _escuchando:
		return true
	_escucha.set_broadcast_enabled(true)
	_escuchando = _escucha.bind(PUERTO, "*") == OK
	return _escuchando


func dejar_de_escuchar() -> void:
	if _escuchando:
		_escucha.close()
	_escuchando = false
	if not _salas.is_empty():
		_salas.clear()
		salas_cambiaron.emit([])


## El anfitrión anuncia su sala. info: { nombre, jugadores, maximo, clave }.
func anunciar(info: Dictionary) -> void:
	_info = info
	if not _anunciando:
		_envio.set_broadcast_enabled(true)
		_anunciando = true
		_t = INTERVALO  # el primer anuncio sale de inmediato


func actualizar_anuncio(info: Dictionary) -> void:
	_info.merge(info, true)


func dejar_de_anunciar() -> void:
	_anunciando = false
	_envio.close()


func _exit_tree() -> void:
	dejar_de_anunciar()
	dejar_de_escuchar()


func _process(delta: float) -> void:
	if _anunciando:
		_t += delta
		if _t >= INTERVALO:
			_t = 0.0
			_enviar()
	if _escuchando:
		_recibir()


func _enviar() -> void:
	var msg := "%s|%s|%d|%d|%d" % [
		FIRMA,
		String(_info.get("nombre", "Sala")).replace("|", " "),
		int(_info.get("jugadores", 1)),
		int(_info.get("maximo", 2)),
		1 if _info.get("clave", false) else 0,
	]
	var bytes := msg.to_utf8_buffer()
	for destino in destinos_broadcast():
		_envio.set_dest_address(destino, PUERTO)
		_envio.put_packet(bytes)


func _recibir() -> void:
	var cambio := false
	var ahora := Time.get_ticks_msec() / 1000.0
	while _escucha.get_available_packet_count() > 0:
		var texto := _escucha.get_packet().get_string_from_utf8()
		var ip := _escucha.get_packet_ip()
		var partes := texto.split("|")
		if partes.size() < 5 or partes[0] != FIRMA or ip == "":
			continue
		var nueva := not _salas.has(ip)
		var antes: Dictionary = _salas.get(ip, {})
		var sala := {
			"ip": ip,
			"nombre": partes[1],
			"jugadores": int(partes[2]),
			"maximo": int(partes[3]),
			"clave": partes[4] == "1",
			"visto": ahora,
		}
		if nueva or antes.get("jugadores") != sala.jugadores or antes.get("nombre") != sala.nombre:
			cambio = true
		_salas[ip] = sala
	for ip in _salas.keys():
		if ahora - float(_salas[ip].visto) > CADUCA:
			_salas.erase(ip)
			cambio = true
	if cambio:
		salas_cambiaron.emit(_salas.values())


## IPs IPv4 privadas de este equipo (la de la Wi-Fi, normalmente 192.168.x.x).
static func ips_locales() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.contains(":"):
			continue
		var p := ip.split(".")
		if p.size() != 4:
			continue
		var a := int(p[0])
		var b := int(p[1])
		if a == 192 and b == 168 or a == 10 or a == 172 and b >= 16 and b <= 31:
			out.append(ip)
	return out


## Broadcast general y el de cada red local (x.y.z.255): algunos routers y
## teléfonos solo dejan pasar uno de los dos.
static func destinos_broadcast() -> Array:
	var out := ["255.255.255.255"]
	for ip in ips_locales():
		var p: PackedStringArray = ip.split(".")
		out.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	return out
