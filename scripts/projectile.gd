extends Node3D
## Flecha o bola de fuego: vuela en línea recta y daña al primer enemigo que toca.

var velocity := Vector3.ZERO
var damage := 10
var radius := 0.9
var life := 2.5
var stagger := false
var gravity := 0.0
var source: Node3D
## Si es de un enemigo, daña al héroe en vez de a los enemigos.
var hostile := false
## Parte del daño que vuelve como vida al héroe (magia de oscuridad).
var drain := 0.0


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var step := velocity * delta
	global_position += step
	if step.length() > 0.001:
		look_at(global_position + step, Vector3.UP)
	if hostile:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and player.is_alive() and player.global_position.distance_to(global_position - Vector3(0, 1.0, 0)) < radius + 0.4:
			player.take_hit(damage, global_position - velocity.normalized() * 2.0, source)
			queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_alive():
			continue
		if enemy.global_position.distance_to(global_position - Vector3(0, 1.0, 0)) < radius + 0.5:
			enemy.take_hit(damage, global_position - velocity.normalized(), stagger, 0.0)
			if drain > 0.0 and source and source.is_alive():
				var heal := int(damage * drain)
				source.hp = mini(source.max_hp, source.hp + heal)
				source.stats_changed.emit()
			queue_free()
			return
