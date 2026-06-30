extends Node2D

@export var max_health: float = 10.0
var health: float = max_health
var row: int = -1
var col: int = -1

# Sun generation parameters
var sun_cooldown: float = 18.0
var sun_timer: float = 7.0 # First sun spawns after 7 seconds
var sun_scene = preload("res://scenes/sun.tscn")
var is_glowing: bool = false

func _ready() -> void:
	add_to_group("sunflowers")
	add_to_group("generators") # Kept for backward compatibility if needed
	add_to_group("buildings")
	health = max_health
	$AnimationPlayer.play("idle")

func _process(delta: float) -> void:
	sun_timer -= delta
	
	# Visual cue: glow yellow 1 second before generating sun
	if sun_timer <= 1.0 and not is_glowing:
		is_glowing = true
		var tween = create_tween()
		tween.set_loops(2)
		tween.tween_property(self, "modulate", Color(1.4, 1.4, 0.7), 0.25)
		tween.tween_property(self, "modulate", Color.WHITE, 0.25)
		
	if sun_timer <= 0:
		spawn_sun()
		sun_timer = sun_cooldown
		is_glowing = false
		modulate = Color.WHITE

func spawn_sun() -> void:
	if sun_scene:
		var sun = sun_scene.instantiate()
		get_parent().add_child(sun)
		sun.start_sunflower_hop(position)

func take_damage(amount: float) -> void:
	health -= amount
	# Flash effect when hit
	var orig_mod = modulate
	modulate = Color(1.5, 1.5, 1.5) # Flash brighter
	var tween = create_tween()
	tween.tween_property(self, "modulate", orig_mod, 0.15)
	
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
