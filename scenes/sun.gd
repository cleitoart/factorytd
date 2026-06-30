extends Node2D

var fall_speed: float = 120.0
var target_y: float = 0.0
var is_falling: bool = false
var is_collected: bool = false
var lifetime: float = 10.0

func _ready() -> void:
	# Add slight scaling variance for natural feel
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(4, 4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func start_falling(start_pos: Vector2, end_y: float) -> void:
	position = start_pos
	target_y = end_y
	is_falling = true

func start_sunflower_hop(start_pos: Vector2) -> void:
	position = start_pos
	is_falling = false
	
	# Parabolic hop animation
	var random_offset_x = randf_range(-80.0, 80.0)
	var random_offset_y = randf_range(30.0, 70.0)
	var end_pos = start_pos + Vector2(random_offset_x, random_offset_y)
	
	var tween = create_tween()
	tween.set_parallel(true)
	# Horizontal movement
	tween.tween_property(self, "position:x", end_pos.x, 0.6).set_trans(Tween.TRANS_LINEAR)
	# Vertical hop arc
	var peak_y = start_pos.y - 50.0
	var y_tween = create_tween()
	y_tween.tween_property(self, "position:y", peak_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(self, "position:y", end_pos.y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Rotate slowly while hopping
	tween.tween_property(self, "rotation", randf_range(-PI, PI), 0.6)
	
	tween.chain().tween_callback(start_ground_timer)

func start_ground_timer() -> void:
	# Fade out and delete if not collected
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5).set_delay(lifetime - 1.5)
	tween.chain().tween_callback(queue_free)

func _process(delta: float) -> void:
	if is_collected:
		return
		
	if is_falling:
		position.y += fall_speed * delta
		rotation += 1.2 * delta
		if position.y >= target_y:
			position.y = target_y
			is_falling = false
			start_ground_timer()
			
	# Hover detection
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.distance_to(global_position) < 60.0:
		collect()

func collect() -> void:
	if is_collected:
		return
	is_collected = true
	
	# Stop all existing tweens on this object
	# Create collection flight animation
	var main = get_tree().current_scene
	
	# Target position (UI Sun Counter) - fly towards the top-left area
	var ui_sun_pos = Vector2(480.0, 60.0) 
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", ui_sun_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.55)
	tween.tween_property(self, "rotation", rotation + PI * 2, 0.55)
	
	# Success callback
	tween.chain().tween_callback(func():
		if main and main.has_method("add_sun"):
			main.add_sun(25)
		queue_free()
	)
