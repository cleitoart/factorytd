extends Node2D

@export var speed: float = 600.0
@export var damage: float = 1.0
var row: int = -1

func _ready() -> void:
	add_to_group("bullets")

func _process(delta: float) -> void:
	position.x += speed * delta
	
	if position.x > 1950:
		queue_free()
		return
		
	# Check for collision with an enemy on the same row
	var main = get_tree().current_scene
	if main and main.has_method("get_enemy_in_row_ahead_of"):
		var enemy = main.get_enemy_in_row_ahead_of(row, position.x)
		# If the bullet passes the enemy's X position (or close to it)
		if enemy and position.x >= enemy.position.x - 20:
			enemy.take_damage(damage)
			# Tiny splash effect
			spawn_splash()
			queue_free()

func spawn_splash() -> void:
	# Simple visual impact effect: create a brief fading spark
	var spark = Sprite2D.new()
	spark.texture = preload("res://assets/sprites/Bullet.png")
	spark.position = position
	spark.scale = scale * 1.5
	spark.modulate = Color(2.0, 2.0, 1.0) # Bright yellow-ish highlight
	get_parent().add_child(spark)
	
	var tween = spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2.ZERO, 0.1)
	tween.tween_property(spark, "modulate", Color(1, 1, 1, 0), 0.1)
	tween.chain().tween_callback(spark.queue_free)
