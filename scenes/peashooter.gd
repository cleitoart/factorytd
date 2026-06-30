extends Node2D

@export var max_health: float = 10.0
var health: float = max_health

var is_active: bool = true
var row: int = -1
var col: int = -1
var shoot_cooldown: float = 1.5
var cooldown_timer: float = 0.0
var base_scale: Vector2 = Vector2(4, 4)

var bullet_scene = preload("res://scenes/bullet.tscn")

func _ready() -> void:
	base_scale = scale
	add_to_group("peashooters")
	add_to_group("turrets") # Kept for compatibility with test.gd
	add_to_group("buildings")
	health = max_health
	$AnimationPlayer.play("idle")

func _process(delta: float) -> void:
	if not is_active:
		return
		
	if cooldown_timer > 0:
		cooldown_timer -= delta
	else:
		# Check if there is an enemy in our row to the right
		var main = get_tree().current_scene
		if main and main.has_method("has_enemy_in_row_ahead_of"):
			if main.has_enemy_in_row_ahead_of(row, position.x):
				shoot()
				cooldown_timer = shoot_cooldown

func shoot() -> void:
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		bullet.position = position + Vector2(60, -52) # Aligned with peashooter mouth at scale 4
		bullet.row = row
		get_parent().add_child(bullet)
		
		# Shoot kickback animation effect
		var tween = create_tween()
		tween.tween_property(self, "scale", base_scale * Vector2(0.85, 1.15), 0.07)
		tween.tween_property(self, "scale", base_scale, 0.07)

func set_active(_value: bool) -> void:
	is_active = true
	if not $AnimationPlayer.is_playing():
		$AnimationPlayer.play("idle")
	modulate = Color.WHITE

func take_damage(amount: float) -> void:
	health -= amount
	# Flash effect when hit
	var flash_mod = modulate
	modulate = Color(1.5, 1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", flash_mod if not is_active else Color.WHITE, 0.15)
	
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
