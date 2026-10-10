## Efectos pequeños de combate: números de daño que flotan y se desvanecen.


static func number(parent: Node, pos: Vector3, text: String, color: Color, size := 64) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 14
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.04, 0.1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tween.chain().tween_callback(label.queue_free)
