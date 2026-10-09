## Utilidades para medir y escalar modelos importados.


## Caja que envuelve todas las mallas visibles, en el espacio local de `root`.
static func local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for pair in _collect(root, Transform3D.IDENTITY):
		var box: AABB = pair[0] * (pair[1] as MeshInstance3D).get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


## Escala `root` para que mida `height` de alto y lo apoya sobre el suelo (y = 0).
static func fit_height(root: Node3D, height: float) -> AABB:
	var box := local_aabb(root)
	if box.size.y <= 0.0001:
		return box
	var s := height / box.size.y
	root.scale = Vector3.ONE * s
	root.position.y -= box.position.y * s
	return AABB(box.position * s, box.size * s)


static func _collect(node: Node, xform: Transform3D) -> Array:
	var out := []
	var here := xform
	if node is Node3D and node != null:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).visible:
		out.append([here, node])
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).visible:
			continue
		out.append_array(_collect(child, here))
	return out
