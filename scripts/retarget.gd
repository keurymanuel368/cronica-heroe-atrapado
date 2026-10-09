extends RefCounted
## Copia las animaciones de un esqueleto (el de KayKit, que trae 75
## animaciones) a otro con proporciones distintas (el héroe anime de VRoid).
## Para cada hueso toma cuánto giró respecto a su pose de reposo, en
## coordenadas del mundo, y aplica ese mismo giro al hueso equivalente.

## hueso de KayKit -> hueso de VRoid (VRM)
const BONE_MAP := {
	"hips": "J_Bip_C_Hips",
	"spine": "J_Bip_C_Spine",
	"chest": "J_Bip_C_Chest",
	"head": "J_Bip_C_Head",
	"upperarm.l": "J_Bip_L_UpperArm",
	"lowerarm.l": "J_Bip_L_LowerArm",
	"wrist.l": "J_Bip_L_Hand",
	"upperarm.r": "J_Bip_R_UpperArm",
	"lowerarm.r": "J_Bip_R_LowerArm",
	"wrist.r": "J_Bip_R_Hand",
	"upperleg.l": "J_Bip_L_UpperLeg",
	"lowerleg.l": "J_Bip_L_LowerLeg",
	"foot.l": "J_Bip_L_Foot",
	"toes.l": "J_Bip_L_ToeBase",
	"upperleg.r": "J_Bip_R_UpperLeg",
	"lowerleg.r": "J_Bip_R_LowerLeg",
	"foot.r": "J_Bip_R_Foot",
	"toes.r": "J_Bip_R_ToeBase",
}

var source: Skeleton3D
var target: Skeleton3D
## Pares [hueso origen, hueso destino], ordenados de padres a hijos.
var _pairs: Array = []
## Todos los huesos del destino ordenados de padres a hijos, y a qué hueso
## de origen corresponde cada uno (-1 si no tiene).
var _order: Array[int] = []
var _from: Dictionary = {}
var _src_rest: Dictionary = {}
var _tgt_rest: Dictionary = {}
## Giro extra hacia abajo de los brazos: las animaciones vienen de un
## personaje chibi de cuerpo ancho y dejarían los brazos muy abiertos.
const ARM_DROP_DEG := 35.0
var _extra: Dictionary = {}
var _hip_scale := 1.0
var _src_hips := -1
var _tgt_hips := -1


func _init(src: Skeleton3D, tgt: Skeleton3D) -> void:
	source = src
	target = tgt
	for s_name in BONE_MAP:
		var s := source.find_bone(s_name)
		var t := target.find_bone(BONE_MAP[s_name])
		if s < 0 or t < 0:
			continue
		_pairs.append([s, t])
		_src_rest[s] = source.get_bone_global_rest(s).basis.orthonormalized()
		_tgt_rest[t] = target.get_bone_global_rest(t).basis.orthonormalized()
	for pair in _pairs:
		_from[pair[1]] = pair[0]
	for side in [["J_Bip_L_UpperArm", 1.0], ["J_Bip_R_UpperArm", -1.0]]:
		var b := target.find_bone(side[0])
		var rest_dir := target.get_bone_global_rest(target.find_bone(side[0].replace("UpperArm", "LowerArm"))).origin - target.get_bone_global_rest(b).origin
		var axis := rest_dir.cross(Vector3.DOWN).normalized()
		_extra[b] = Basis(axis, deg_to_rad(ARM_DROP_DEG))
	for b in target.get_bone_count():
		_order.append(b)
	_order.sort_custom(func(a, b): return _depth(target, a) < _depth(target, b))
	_src_hips = source.find_bone("hips")
	_tgt_hips = target.find_bone("J_Bip_C_Hips")
	var src_h := source.get_bone_global_rest(_src_hips).origin.y
	var tgt_h := target.get_bone_global_rest(_tgt_hips).origin.y
	_hip_scale = tgt_h / src_h if src_h > 0.0 else 1.0


func apply() -> void:
	var src_basis := source.global_transform.basis.orthonormalized()
	var tgt_basis := target.global_transform.basis.orthonormalized()
	var to_target := tgt_basis.inverse() * src_basis

	# Rotación global de cada hueso del destino, calculada aquí mismo para no
	# depender de la caché del esqueleto mientras se modifica.
	var globals := {}
	for t in _order:
		var parent := target.get_bone_parent(t)
		var parent_global: Basis = globals[parent] if parent >= 0 else Basis()
		if _from.has(t):
			var s: int = _from[t]
			var src_pose := source.get_bone_global_pose(s).basis.orthonormalized()
			var delta: Basis = src_pose * (_src_rest[s] as Basis).inverse()
			var rest_basis: Basis = _tgt_rest[t]
			if _extra.has(t):
				rest_basis = (_extra[t] as Basis) * rest_basis
			var wanted := (to_target * delta * to_target.inverse()) * rest_basis
			target.set_bone_pose_rotation(t, (parent_global.inverse() * wanted).get_rotation_quaternion())
			globals[t] = wanted
		else:
			globals[t] = parent_global * Basis(target.get_bone_pose_rotation(t))

	# Sube y baja la cadera igual que la animación original, a escala.
	var src_off := source.get_bone_global_pose(_src_hips).origin - source.get_bone_global_rest(_src_hips).origin
	var off := to_target * src_off * _hip_scale
	var rest := target.get_bone_rest(_tgt_hips).origin
	var parent_h := target.get_bone_parent(_tgt_hips)
	var parent_basis: Basis = globals[parent_h] if parent_h >= 0 else Basis()
	target.set_bone_pose_position(_tgt_hips, rest + parent_basis.inverse() * off)


static func _depth(skel: Skeleton3D, bone: int) -> int:
	var d := 0
	var p := skel.get_bone_parent(bone)
	while p >= 0:
		d += 1
		p = skel.get_bone_parent(p)
	return d
