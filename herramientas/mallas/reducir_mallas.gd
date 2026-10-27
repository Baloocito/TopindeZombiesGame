extends SceneTree
# ==========================================================
# REDUCE LOS POLÍGONOS DE LOS MODELOS DE TRIPO (≈50.000 triángulos)
# ==========================================================
# Uso (desde la carpeta del proyecto):
#   godot --headless -s herramientas/mallas/reducir_mallas.gd
# Por cada modelo de la lista genera "<modelo>_lp.res" al lado del .fbx: la
# misma malla con menos triángulos (y menos vértices), con sus huesos y pesos.
# ModelosPSX.personaje() la usa sola si existe. Volver a correrlo cuando se
# cambie un modelo.

const MODELOS := {
	"KH/leo/leo": 6000, "KH/frank/frank": 6000, "KH/miyuki/miyuki": 6000, "KH/momo/momo": 6000,
	"KH/tanque/tanque": 3000,
}

func _init():
	for base in MODELOS.keys():
		var escena = load("res://assets/modelos/" + base + ".fbx")
		if not escena:
			print("NO ENCONTRADO ", base); continue
		var n: Node = escena.instantiate()
		var mi := n.find_child("*", true, false) as MeshInstance3D
		for m in n.find_children("*", "MeshInstance3D", true, false):
			mi = m; break
		var nueva := reducir(mi.mesh, MODELOS[base])
		var ruta: String = "res://assets/modelos/" + base + "_lp.res"
		ResourceSaver.save(nueva, ruta, ResourceSaver.FLAG_COMPRESS)
		print("REDUCIDO ", base, ": ", _tris(mi.mesh), " -> ", _tris(nueva), " triángulos")
		n.free()
	quit()

func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a = m.surface_get_arrays(s)
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t

func reducir(malla: Mesh, objetivo: int) -> ArrayMesh:
	var salida := ArrayMesh.new()
	var por_superficie := objetivo / maxi(1, malla.get_surface_count())
	for s in malla.get_surface_count():
		var arr: Array = malla.surface_get_arrays(s)
		if arr[Mesh.ARRAY_INDEX] == null:
			var idx := PackedInt32Array()
			for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(): idx.append(i)
			arr[Mesh.ARRAY_INDEX] = idx
		var formato: int = malla.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "", formato)
		im.generate_lods(25.0, 60.0, [])
		# El nivel de detalle más cercano al objetivo (sin bajar de él).
		var mejor: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for l in im.get_surface_lod_count(0):
			var ind := im.get_surface_lod_indices(0, l)
			if ind.size() / 3 >= por_superficie and ind.size() < mejor.size(): mejor = ind
		salida.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compactar(arr, mejor), [], {}, formato)
	return salida

# Deja solo los vértices que usa `indices` (menos vértices = menos piel que calcular).
func _compactar(arr: Array, indices: PackedInt32Array) -> Array:
	var mapa := {}
	var orden := PackedInt32Array()
	var nuevos := PackedInt32Array()
	nuevos.resize(indices.size())
	for i in indices.size():
		var v := indices[i]
		if not mapa.has(v):
			mapa[v] = orden.size()
			orden.append(v)
		nuevos[i] = mapa[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nv := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for c in Mesh.ARRAY_MAX:
		var dato = arr[c]
		if dato == null or c == Mesh.ARRAY_INDEX: continue
		var por_vertice: int = dato.size() / nv
		var nuevo = dato.duplicate()
		nuevo.resize(orden.size() * por_vertice)
		for j in orden.size():
			for k in por_vertice:
				nuevo[j * por_vertice + k] = dato[orden[j] * por_vertice + k]
		out[c] = nuevo
	out[Mesh.ARRAY_INDEX] = nuevos
	return out
