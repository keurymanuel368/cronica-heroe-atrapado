## Convierte los materiales de un modelo al estilo anime (cel-shading):
## sombras en bandas duras y un contorno oscuro alrededor de la figura.

const OUTLINE_COLOR := Color(0.09, 0.07, 0.12)

static var _outline_cache: Dictionary = {}


static func apply(root: Node, outline_width: float = 0.02, tint: Color = Color.WHITE) -> void:
	for mesh_instance in _meshes(root):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var source: Material = mesh_instance.get_active_material(i)
			mesh_instance.set_surface_override_material(i, _toonify(source, outline_width, tint))


static func _toonify(source: Material, outline_width: float, tint: Color = Color.WHITE) -> Material:
	var mat: StandardMaterial3D
	if source is StandardMaterial3D:
		mat = source.duplicate()
	else:
		mat = StandardMaterial3D.new()
	mat.albedo_color *= tint
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.85
	mat.metallic = 0.0
	if outline_width > 0.0:
		mat.next_pass = _outline(outline_width)
	return mat


static func _outline(width: float) -> StandardMaterial3D:
	if _outline_cache.has(width):
		return _outline_cache[width]
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.albedo_color = OUTLINE_COLOR
	o.grow = true
	o.grow_amount = width
	_outline_cache[width] = o
	return o


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		found.append(root)
	for child in root.get_children():
		found.append_array(_meshes(child))
	return found
