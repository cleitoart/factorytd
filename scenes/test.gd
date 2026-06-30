extends Node2D

var grid: Dictionary = {} # Maps Vector2i(col, row) -> Node2D (building)
var turrets_list: Array = [] # List of turrets in placement order for energy priority

# Grid settings (5 rows x 12 columns)
const CELL_WIDTH: float = 132.0
const CELL_HEIGHT: float = 165.0
const GRID_START_X: float = 210.0
const GRID_START_Y: float = 194.0

# Preloads
var turret_scene = preload("res://scenes/Peashooter.tscn")
var generator_scene = preload("res://scenes/sunflower.tscn")
var enemy_scene = preload("res://scenes/enemy.tscn")

# Game state
enum ToolType { TURRET, GENERATOR, SHOVEL }
var selected_tool: ToolType = ToolType.TURRET

var player_lives: int = 5
var max_lives: int = 5
var total_energy_generated: int = 0
var total_energy_consumed: int = 0

# UI references
@onready var turret_btn = $UI/Panel/VBoxContainer/HBoxContainer/TurretBtn
@onready var generator_btn = $UI/Panel/VBoxContainer/HBoxContainer/GeneratorBtn
@onready var shovel_btn = $UI/Panel/VBoxContainer/HBoxContainer/ShovelBtn
@onready var energy_label = $UI/Panel/VBoxContainer/HBoxContainer2/EnergyLabel
@onready var lives_label = $UI/Panel/VBoxContainer/HBoxContainer2/LivesLabel
@onready var game_over_screen = $UI/GameOverScreen
@onready var placement_highlight = $PlacementHighlight

func _ready() -> void:
	# Hide Game Over screen at start
	game_over_screen.hide()
	
	# Configure placement highlight
	placement_highlight.size = Vector2(CELL_WIDTH - 10, CELL_HEIGHT - 10)
	placement_highlight.pivot_offset = placement_highlight.size / 2
	placement_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Wait for child nodes to be ready, then snap existing ones to grid
	await get_tree().process_frame
	setup_existing_buildings()
	update_energy()
	update_ui_buttons()

func setup_existing_buildings() -> void:
	for child in get_children():
		if child.is_in_group("turrets") or child.is_in_group("generators"):
			# Find grid cell coordinates based on the editor placement position
			var col = clamp(round((child.position.x - GRID_START_X) / CELL_WIDTH), 0, 11)
			var row = clamp(round((child.position.y - GRID_START_Y) / CELL_HEIGHT), 0, 4)
			
			var cell = Vector2i(col, row)
			if not grid.has(cell):
				# Snap it to the center of the calculated cell
				child.position = Vector2(
					GRID_START_X + col * CELL_WIDTH,
					GRID_START_Y + row * CELL_HEIGHT
				)
				child.row = row
				child.col = col
				grid[cell] = child
				
				if child.is_in_group("turrets"):
					turrets_list.append(child)
			else:
				# Cell already occupied, free the duplicate
				child.queue_free()

func _process(_delta: float) -> void:
	update_placement_preview()

func update_placement_preview() -> void:
	if player_lives <= 0:
		placement_highlight.hide()
		return
		
	var mouse_pos = get_local_mouse_position()
	
	# Calculate cell
	var col = round((mouse_pos.x - GRID_START_X) / CELL_WIDTH)
	var row = round((mouse_pos.y - GRID_START_Y) / CELL_HEIGHT)
	
	if col >= 0 and col < 12 and row >= 0 and row < 5:
		placement_highlight.show()
		# Position highlight centered at cell
		placement_highlight.position = Vector2(
			GRID_START_X + col * CELL_WIDTH,
			GRID_START_Y + row * CELL_HEIGHT
		) - placement_highlight.size / 2
		
		var cell = Vector2i(col, row)
		if grid.has(cell):
			if selected_tool == ToolType.SHOVEL:
				placement_highlight.color = Color(1.0, 0.2, 0.2, 0.45) # Red highlight for removal
			else:
				placement_highlight.color = Color(0.9, 0.1, 0.1, 0.3) # Dim red if occupied
		else:
			if selected_tool == ToolType.SHOVEL:
				placement_highlight.color = Color(0.6, 0.6, 0.6, 0.25) # Gray highlight if nothing to shovel
			else:
				placement_highlight.color = Color(0.2, 1.0, 0.2, 0.45) # Green highlight for placement
	else:
		placement_highlight.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player_lives <= 0:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		
		var col = round((mouse_pos.x - GRID_START_X) / CELL_WIDTH)
		var row = round((mouse_pos.y - GRID_START_Y) / CELL_HEIGHT)
		
		if col >= 0 and col < 12 and row >= 0 and row < 5:
			var cell = Vector2i(col, row)
			handle_grid_click(cell)

func handle_grid_click(cell: Vector2i) -> void:
	var cell_pos = Vector2(
		GRID_START_X + cell.x * CELL_WIDTH,
		GRID_START_Y + cell.y * CELL_HEIGHT
	)
	
	if selected_tool == ToolType.SHOVEL:
		if grid.has(cell):
			var building = grid[cell]
			remove_building(building)
			building.queue_free()
	else:
		if not grid.has(cell):
			var new_building = null
			if selected_tool == ToolType.TURRET:
				new_building = turret_scene.instantiate()
				new_building.scale = Vector2(4, 4)
				new_building.add_to_group("turrets")
				new_building.add_to_group("buildings")
				turrets_list.append(new_building)
			elif selected_tool == ToolType.GENERATOR:
				new_building = generator_scene.instantiate()
				new_building.scale = Vector2(4, 4)
				new_building.add_to_group("generators")
				new_building.add_to_group("buildings")
				
			if new_building:
				new_building.position = cell_pos
				new_building.row = cell.y
				new_building.col = cell.x
				add_child(new_building)
				grid[cell] = new_building
				
				# Play place scale pop-in animation
				new_building.scale = Vector2.ZERO
				var tween = create_tween()
				tween.tween_property(new_building, "scale", Vector2(4, 4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				
				call_deferred("update_energy")

func remove_building(building: Node2D) -> void:
	var cell = Vector2i(building.col, building.row)
	if grid.has(cell) and grid[cell] == building:
		grid.erase(cell)
		
	if building in turrets_list:
		turrets_list.erase(building)
		
	# Defer update to allow frame to clear the node
	call_deferred("update_energy")

func update_energy() -> void:
	var active_generators = 0
	for cell in grid:
		var b = grid[cell]
		if is_instance_valid(b) and b.is_in_group("generators"):
			active_generators += 1
			
	total_energy_generated = active_generators * 50
	total_energy_consumed = 0
	
	# Power turrets in order of placement
	for turret in turrets_list:
		if is_instance_valid(turret):
			if total_energy_consumed + 30 <= total_energy_generated:
				turret.set_active(true)
				total_energy_consumed += 30
			else:
				turret.set_active(false)
				
	# Update energy display
	energy_label.text = "⚡ Power Grid: " + str(total_energy_consumed) + "W / " + str(total_energy_generated) + "W"

func update_ui_buttons() -> void:
	# Clean flat styles with bright colors for selected tools
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.2, 0.7, 0.3)
	selected_style.set_corner_radius_all(10)
	
	var default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.2, 0.2, 0.25)
	default_style.set_corner_radius_all(10)
	
	turret_btn.add_theme_stylebox_override("normal", selected_style if selected_tool == ToolType.TURRET else default_style)
	generator_btn.add_theme_stylebox_override("normal", selected_style if selected_tool == ToolType.GENERATOR else default_style)
	shovel_btn.add_theme_stylebox_override("normal", selected_style if selected_tool == ToolType.SHOVEL else default_style)

# Tool Selection Buttons Click Handlers
func _on_turret_btn_pressed() -> void:
	selected_tool = ToolType.TURRET
	update_ui_buttons()

func _on_generator_btn_pressed() -> void:
	selected_tool = ToolType.GENERATOR
	update_ui_buttons()

func _on_shovel_btn_pressed() -> void:
	selected_tool = ToolType.SHOVEL
	update_ui_buttons()

# Combat helpers
func has_enemy_in_row_ahead_of(r: int, x_pos: float) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.row == r and enemy.position.x > x_pos and enemy.hp > 0:
			return true
	return false

func get_enemy_in_row_ahead_of(r: int, x_pos: float) -> Node2D:
	var target_enemy: Node2D = null
	var min_x: float = 99999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.row == r and enemy.position.x > x_pos and enemy.hp > 0:
			if enemy.position.x < min_x:
				min_x = enemy.position.x
				target_enemy = enemy
	return target_enemy

func get_building_at_row_closest_to(r: int, x_pos: float) -> Node2D:
	var target_building: Node2D = null
	var max_x: float = -99999.0
	for cell in grid:
		var b = grid[cell]
		if is_instance_valid(b) and b.row == r and b.position.x < x_pos:
			if b.position.x > max_x:
				max_x = b.position.x
				target_building = b
	return target_building

# Spawning enemies
func _on_spawn_timer_timeout() -> void:
	if player_lives <= 0:
		return
		
	# Choose a random row from 0 to 4
	var row = randi() % 5
	var spawn_pos = Vector2(
		1920.0 + 50.0, # Just off screen to the right
		GRID_START_Y + row * CELL_HEIGHT
	)
	
	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_pos
	enemy.row = row
	add_child(enemy)
	
	# Spawn scale transition
	enemy.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(enemy, "scale", Vector2(4, 4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Damage Player / Lives System
func damage_player(amount: int) -> void:
	player_lives = max(0, player_lives - amount)
	lives_label.text = "❤️ Lives: " + str(player_lives)
	
	# Camera shake or screen flash when hit
	var screen_flash = ColorRect.new()
	screen_flash.size = Vector2(1920, 1080)
	screen_flash.color = Color(1, 0, 0, 0.3)
	add_child(screen_flash)
	var tween = create_tween()
	tween.tween_property(screen_flash, "color", Color(1, 0, 0, 0), 0.3)
	tween.chain().tween_callback(screen_flash.queue_free)
	
	if player_lives <= 0:
		trigger_game_over()

func trigger_game_over() -> void:
	game_over_screen.show()
	# Slow down the game time to create a dramatic death sequence
	Engine.time_scale = 0.3
	# Wait a bit then freeze game completely
	await get_tree().create_timer(1.0).timeout
	get_tree().paused = true

func _on_restart_btn_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
