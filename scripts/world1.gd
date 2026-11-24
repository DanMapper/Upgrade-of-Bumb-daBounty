extends Node2D

const TargetShipScene: PackedScene = preload("res://Objects/target_ship.tscn")
const ChaseHud = preload("res://scripts/chase_hud.gd")
@onready var player: PlayerShip = $Player
@onready var obstacle_spawner = $ObstacleCliffSpawner
var gameplay_manager: GameplayManager
var target_ship: TargetShip
var pickup_cell := Vector2i(-1, -1)
var pickup_time: float = 0.0
var pickup_delay: float = 3.0
var hazard_cell := Vector2i(-1, -1)
var hazard_time: float = 0.0
var hazard_delay: float = 2.5
const TURN_WARNING_TIME: float = 0.65
var next_target_lane: int = 0
var target_switch: float = 3.2
var notice: String = ""
var notice_time: float = 0.0
var notice_positive: bool = true
var phase_notice: String = ""
var phase_notice_time: float = 0.0
var hud

func _ready() -> void:
	BGMPlayer.play_bgm(BGMPlayer.GAMEPLAY_BGM)
	$HudTextBox.hide()
	$TextHud/SpeedLabel.hide()
	$TextHud/DistanceLabel.hide()
	$TextHud/CrashLabel.hide()
	gameplay_manager = GameplayManager.new()
	gameplay_manager.name = "GameplayManager"
	add_child(gameplay_manager)
	target_ship = TargetShipScene.instantiate()
	target_ship.name = "TargetShip"
	target_ship.z_index = 0
	add_child(target_ship)
	player.player_hit.connect(gameplay_manager.on_player_hit)
	player.lane_left.connect(obstacle_spawner.on_lane_left)
	player.fired.connect(_on_shot)
	gameplay_manager.player = player
	gameplay_manager.distance_changed.connect(_on_distance_changed)
	gameplay_manager.phase_changed.connect(_on_phase_changed)
	gameplay_manager.target_appeared.connect(_on_target_appeared)
	gameplay_manager.zone_entered.connect(_on_zone_entered)
	gameplay_manager.game_won.connect(_on_game_won)
	gameplay_manager.game_lost.connect(_on_game_lost)
	gameplay_manager.feedback.connect(_on_feedback)
	obstacle_spawner.obstacle_cleared.connect(gameplay_manager.reward)
	gameplay_manager.start_game()
	obstacle_spawner.encounter_factor = 1.10 / gameplay_manager.difficulty_factor
	obstacle_spawner.spawn_timer = 1.0
	hud = ChaseHud.new()
	hud.world = self
	$TextHud.add_child(hud)
	_show_phase("01 / ENTER THE CANYON", 3.5)

func _process(delta: float) -> void:
	if gameplay_manager == null:
		return
	notice_time = maxf(0.0, notice_time - delta)
	phase_notice_time = maxf(0.0, phase_notice_time - delta)
	if not gameplay_manager.is_game_over():
		if gameplay_manager.phase < 4:
			_update_pickup(delta)
		else:
			_update_capture(delta)
	if is_instance_valid(hud):
		hud.queue_redraw()

func _update_pickup(delta: float) -> void:
	if pickup_time > 0.0:
		pickup_time -= delta
		if pickup_time <= 0.0:
			pickup_cell = Vector2i(-1, -1)
			pickup_delay = 3.0
		elif Vector2i(player.grid_col, player.grid_row) == pickup_cell and player.position.distance_to(player.get_cell_position(pickup_cell.x, pickup_cell.y)) < 40.0:
			pickup_cell = Vector2i(-1, -1)
			pickup_time = 0.0
			pickup_delay = randf_range(3.5, 5.0)
			gameplay_manager.reward("CELL")
		return
	pickup_delay -= delta
	if pickup_delay > 0.0:
		return
	var blocked: Array = obstacle_spawner._get_blocked_columns()
	var options: Array[Vector2i] = []
	for col in range(3):
		if col in blocked:
			continue
		for row in range(3):
			if row != player.grid_row:
				options.append(Vector2i(col, row))
	if options.is_empty():
		pickup_delay = 0.5
		return
	pickup_cell = options.pick_random()
	pickup_time = 2.7

func _update_capture(delta: float) -> void:
	# The target periodically changes lanes; lock is earned by sustained aligned fire.
	target_switch -= delta
	if target_switch <= 0.0:
		_switch_target()
	var aligned: bool = player.grid_col == target_ship.grid_col and absf(player.position.x - target_ship.position.x) < 95.0 and Input.is_action_pressed("shoot")
	if gameplay_manager.update_lock(delta, aligned):
		target_ship.take_hit()
		if not gameplay_manager.is_game_over():
			_switch_target()
	if gameplay_manager.is_game_over():
		return
	# A telegraphed cell attack makes the vertical axis useful even during capture.
	if hazard_time > 0.0:
		hazard_time -= delta
		if hazard_time <= 0.0:
			if Vector2i(player.grid_col, player.grid_row) == hazard_cell:
				player.take_hit()
			hazard_cell = Vector2i(-1, -1)
			hazard_delay = 1.6 / gameplay_manager.difficulty_factor
	else:
		hazard_delay -= delta
		if hazard_delay <= 0.0:
			hazard_cell = Vector2i(player.grid_col, player.grid_row)
			hazard_time = 1.15 / gameplay_manager.difficulty_factor

func _plan_target_turn() -> void:
	var lanes: Array[int] = [0, 1, 2]
	lanes.erase(target_ship.grid_col)
	next_target_lane = lanes.pick_random()

func _switch_target() -> void:
	target_ship.grid_col = next_target_lane
	_plan_target_turn()
	target_switch = 3.2

func _on_shot() -> void:
	if gameplay_manager.phase < 4:
		obstacle_spawner.try_lane_shot(player.grid_col)

func _on_distance_changed(_distance: float, _total: float) -> void:
	if is_instance_valid(target_ship):
		target_ship.update_progress(gameplay_manager.get_distance_remaining(), gameplay_manager.FINAL_STRETCH_REMAINING)

func _on_phase_changed(phase: int) -> void:
	match phase:
		2:
			obstacle_spawner.encounter_factor = 0.62 / gameplay_manager.difficulty_factor
			obstacle_spawner.spawn_timer = minf(obstacle_spawner.spawn_timer, 0.8)
			_show_phase("02 / CANYON RUSH", 3.0)
		3:
			_show_phase("03 / TARGET IN SIGHT", 3.0)
		4:
			_show_phase("04 / CAPTURE THE BOUNTY", 3.0)

func _on_target_appeared() -> void:
	target_ship.appear()
	obstacle_spawner.set_final_stretch(true)

func _on_zone_entered(_grace: float) -> void:
	obstacle_spawner.stopped = true
	obstacle_spawner.clear_encounters()
	pickup_cell = Vector2i(-1, -1)
	pickup_time = 0.0
	target_ship.capture_mode = true
	_plan_target_turn()
	target_switch = 3.2

func _on_feedback(message: String, positive: bool) -> void:
	notice = message
	notice_positive = positive
	notice_time = 1.4

func _show_phase(message: String, duration: float) -> void:
	phase_notice = message
	phase_notice_time = duration

func _finish() -> void:
	player.is_dead = true
	obstacle_spawner.stopped = true
	obstacle_spawner.call_deferred("clear_encounters")
	pickup_time = 0.0
	hazard_time = 0.0

func _on_game_won() -> void:
	_finish()
	_show_phase("BOUNTY SECURED", 2.0)
	var config := ConfigFile.new()
	config.load("user://bounty_records.cfg")
	var key: String = DifficultyManager.get_difficulty_name()
	var best: int = maxi(int(config.get_value("scores", key, 0)), gameplay_manager.score)
	config.set_value("scores", key, best)
	config.save("user://bounty_records.cfg")
	SceneTransition.pending_data["clear_time"] = gameplay_manager.elapsed_time
	SceneTransition.pending_data["score"] = gameplay_manager.score
	SceneTransition.pending_data["best_score"] = best
	SceneTransition.pending_data["best_combo"] = gameplay_manager.best_combo
	await get_tree().create_timer(2.0, false).timeout
	BGMPlayer.stop_bgm()
	SceneTransition.goto_scene("res://Objects/clear.tscn")

func _on_game_lost(reason: String) -> void:
	SceneTransition.pending_data["loss"] = {
		"reason": reason, "score": gameplay_manager.score,
		"progress": int(gameplay_manager.get_progress_percent()), "locks": gameplay_manager.locks
	}
	_finish()
	_show_phase("OUT OF FUEL" if reason == "no_time" else "HULL DESTROYED", 2.0)
	await get_tree().create_timer(2.0, false).timeout
	BGMPlayer.stop_bgm()
	SceneTransition.goto_scene("res://Objects/game_over.tscn")

func _on_pause_button_pressed() -> void:
	$PauseMenu.toggle_pause()
