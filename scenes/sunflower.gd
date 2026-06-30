extends Node2D

@export var max_health: float = 10.0
var health: float = max_health
var row: int = -1
var col: int = -1

func _ready() -> void:
	add_to_group("sunflowers")
	add_to_group("generators") # Kept for compatibility with test.gd
	add_to_group("buildings")
	health = max_health
	$AnimationPlayer.play("idle")

func take_damage(amount: float) -> void:
	health -= amount
	# Flash effect when hit
	modulate = Color(1.5, 1.5, 1.5) # Flash brighter
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if health <= 0:
		die()

func die() -> void:
	var main = get_tree().current_scene
	if main and main.has_method("remove_building"):
		main.remove_building(self)
	
	# Death animation (shrink and fade)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.chain().tween_callback(queue_free)
