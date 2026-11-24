extends Node
class_name GameplayManager

signal distance_changed(distance: float, total: float)
signal speed_changed(speed: float, top_speed: float)
signal time_changed(elapsed: float, max_time: float)
signal collision_happened(count: int, max_count: int)
signal target_appeared
signal zone_entered(grace_seconds: float)
signal game_won
signal game_lost(reason: String)
signal phase_changed(phase: int)
signal feedback(message: String, positive: bool)

const START_GAP: float = 4500.0
const ACTIVATION_RADIUS: float = 900.0
const TOTAL_DISTANCE: float = START_GAP - ACTIVATION_RADIUS
const FINAL_STRETCH_REMAINING: float = 850.0
const MAX_GAME_TIME: float = 135.0
const TARGET_SPEED: float = 100.0
const STARTING_SPEED: float = 115.0
const TOP_SPEED: float = 160.0
const BOOST_SPEED: float = 205.0
const HIT_PENALTY_DISTANCE: float = 140.0
const LOCKS_REQUIRED: int = 3

enum GameState { ACCELERATING, CRUISING, ENTERING_ZONE, WON, LOST }
var game_state: GameState = GameState.ACCELERATING
var max_collisions: int = 7
var distance_traveled: float = 0.0
var current_speed: float = STARTING_SPEED
var elapsed_time: float = 0.0
var collision_count: int = 0
var player: PlayerShip
var is_active: bool = false
var energy: float = 45.0
var boosting: bool = false
var score: int = 0
var cells_collected: int = 0
var combo: int = 0
var best_combo: int = 0
var phase: int = 1
var locks: int = 0
var lock_progress: float = 0.0
var difficulty_factor: float = 1.0
var _boost_depleted: bool = false

func start_game() -> void:
	max_collisions = DifficultyManager.get_max_collisions()
	match DifficultyManager.current_difficulty:
		DifficultyManager.Difficulty.EASY: difficulty_factor = 0.8
		DifficultyManager.Difficulty.HARD: difficulty_factor = 1.25
	is_active = true
	distance_changed.emit(distance_traveled, TOTAL_DISTANCE)
	speed_changed.emit(current_speed, TOP_SPEED)
	time_changed.emit(elapsed_time, MAX_GAME_TIME)

func _process(delta: float) -> void:
	if not is_active or is_game_over():
		return
	elapsed_time += delta
	time_changed.emit(elapsed_time, MAX_GAME_TIME)
	if elapsed_time >= MAX_GAME_TIME:
		_trigger_game_lost("no_time")
		return
	if not Input.is_physical_key_pressed(KEY_SHIFT):
		_boost_depleted = false
	boosting = game_state != GameState.ENTERING_ZONE and Input.is_physical_key_pressed(KEY_SHIFT) and energy > 0.0 and not _boost_depleted
	if boosting:
		energy = maxf(0.0, energy - 24.0 * delta)
		if energy <= 0.0:
			_boost_depleted = true
	else:
		energy = minf(100.0, energy + 1.5 * delta)
	var desired_speed: float = BOOST_SPEED if boosting else TOP_SPEED
	current_speed = move_toward(current_speed, desired_speed, 45.0 * delta)
	if game_state != GameState.ENTERING_ZONE:
		game_state = GameState.CRUISING if current_speed >= TOP_SPEED else GameState.ACCELERATING
	speed_changed.emit(current_speed, BOOST_SPEED)
	_update_player_speed_multiplier()
	if game_state == GameState.ENTERING_ZONE:
		return
	distance_traveled = clampf(distance_traveled + (current_speed - TARGET_SPEED) * delta, 0.0, TOTAL_DISTANCE)
	if phase == 1 and distance_traveled >= TOTAL_DISTANCE * 0.35:
		phase = 2
		phase_changed.emit(phase)
	if phase < 3 and get_distance_remaining() <= FINAL_STRETCH_REMAINING:
		phase = 3
		phase_changed.emit(phase)
		target_appeared.emit()
	distance_changed.emit(distance_traveled, TOTAL_DISTANCE)
	if distance_traveled >= TOTAL_DISTANCE:
		game_state = GameState.ENTERING_ZONE
		boosting = false
		phase = 4
		phase_changed.emit(phase)
		zone_entered.emit(0.0)

func on_player_hit() -> void:
	if is_game_over():
		return
	collision_count += 1
	combo = 0
	energy = maxf(0.0, energy - 12.0)
	lock_progress = 0.0
	current_speed = STARTING_SPEED
	if game_state != GameState.ENTERING_ZONE:
		distance_traveled = maxf(0.0, distance_traveled - HIT_PENALTY_DISTANCE)
	collision_happened.emit(collision_count, max_collisions)
	distance_changed.emit(distance_traveled, TOTAL_DISTANCE)
	feedback.emit("HULL HIT  /  COMBO LOST", false)
	if collision_count >= max_collisions:
		_trigger_game_lost("no_lives")

func can_repair_hull() -> bool:
	return collision_count > 0 and DifficultyManager.current_difficulty != DifficultyManager.Difficulty.HARD

func reward(kind: String) -> void:
	if is_game_over():
		return
	combo += 1
	best_combo = maxi(best_combo, combo)
	var multiplier: int = mini(4, 1 + int(combo / 4.0))
	var points: int = 50
	var gain: float = 8.0
	match kind:
		"CLOSE CALL":
			points = 100
			gain = 14.0
		"BLAST":
			points = 120
			gain = 16.0
		"CELL":
			points = 150
			gain = 32.0
			cells_collected += 1
			if cells_collected % 3 == 0:
				if can_repair_hull():
					collision_count -= 1
					collision_happened.emit(collision_count, max_collisions)
					kind = "HULL +1"
				elif collision_count == 0:
					points += 150
					kind = "PERFECT CARGO"
	energy = minf(100.0, energy + gain)
	score += points * multiplier
	feedback.emit("%s  +%d  /  x%d" % [kind, points * multiplier, multiplier], true)

func update_lock(delta: float, aligned: bool) -> bool:
	if game_state != GameState.ENTERING_ZONE:
		return false
	if aligned:
		lock_progress += delta / (0.85 * difficulty_factor)
	else:
		lock_progress = maxf(0.0, lock_progress - delta * 0.85)
	if lock_progress < 1.0:
		return false
	locks += 1
	lock_progress = 0.0
	score += 300
	feedback.emit("LOCK %d/%d  +300" % [locks, LOCKS_REQUIRED], true)
	if locks >= LOCKS_REQUIRED:
		_trigger_game_won()
	return true

func _update_player_speed_multiplier() -> void:
	if is_instance_valid(player):
		player.speed_multiplier = clampf(current_speed / TOP_SPEED, 0.65, 1.28)

func _trigger_game_won() -> void:
	game_state = GameState.WON
	is_active = false
	score += maxi(0, int(MAX_GAME_TIME - elapsed_time)) * 10
	game_won.emit()

func _trigger_game_lost(reason: String) -> void:
	game_state = GameState.LOST
	is_active = false
	game_lost.emit(reason)

func get_distance_remaining() -> float:
	return TOTAL_DISTANCE - distance_traveled

func get_progress_percent() -> float:
	return clampf(distance_traveled / TOTAL_DISTANCE, 0.0, 1.0) * 100.0

func get_time_remaining() -> float:
	return maxf(0.0, MAX_GAME_TIME - elapsed_time)

func get_speed_percent() -> float:
	return clampf(current_speed / BOOST_SPEED, 0.0, 1.0) * 100.0

func is_game_over() -> bool:
	return game_state == GameState.WON or game_state == GameState.LOST
