extends Node2D

@export var max_hp: float = 5.0
var hp: float = max_hp
@export var speed: float = 60.0
@export var dps: float = 2.0 # Damage per second to buildings

var row: int = -1
var is_eating: bool = false
var target_building: Node2D = null

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp

func _process(delta: float) -> void:
	var main = get_tree().current_scene
	
	if target_building and is_instance_valid(target_building):
		is_eating = true
		target_building.take_damage(dps * delta)
		# Chewing/eating wobble animation
		$Sprite2D.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.2
		$Sprite2D.position.x = sin(Time.get_ticks_msec() * 0.01) * 2.0
	else:
		is_eating = false
		target_building = null
		$Sprite2D.rotation = 0.0
		# Walking wobble effect
		$Sprite2D.position.y = sin(Time.get_ticks_msec() * 0.01) * 3.0
		
		position.x -= speed * delta
		
		# Check if we hit the left edge (hurt the player)
		if position.x < 150:
			if main and main.has_method("damage_player"):
				main.damage_player(1)
			queue_free()
			return
			
		# Look for a building to eat in our row
		if main and main.has_method("get_building_at_row_closest_to"):
			var b = main.get_building_at_row_closest_to(row, position.x)
			# Enemy moves left, so it eats a building to its left (b.position.x < position.x)
			if b and b.position.x < position.x and abs(b.position.x - position.x) < 55:
				target_building = b

func take_damage(amount: float) -> void:
	hp -= amount
	# White flash effect
	$Sprite2D.modulate = Color(2.0, 2.0, 2.0)
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	
	if hp <= 0:
		die()

func die() -> void:
	set_process(false)
	
	# Death wobble and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "rotation", -PI/2, 0.2) # fall backwards
	tween.tween_property($Sprite2D, "position", $Sprite2D.position + Vector2(20, 10), 0.2)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.chain().tween_callback(queue_free)
