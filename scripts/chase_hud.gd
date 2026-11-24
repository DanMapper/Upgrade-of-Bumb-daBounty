extends Node2D

# Canvas-space HUD; all graphics are drawn from primitives, no external assets required.
var world
var ink := Color("101b2d")
var muted := Color("a5bacd")
var cyan := Color("69e9e0")
var gold := Color("ffce70")
var red := Color("ff726c")
var white := Color("f5f7ee")
var font: Font = ThemeDB.fallback_font

func _text(value: String, at: Vector2, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, ink)
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _center(value: String, at: Vector2, size: int = 18, color: Color = Color.WHITE) -> void:
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	_text(value, at - Vector2(width / 2.0, 0), size, color)

func _draw() -> void:
	if not is_instance_valid(world) or world.gameplay_manager == null:
		return
	var gm: GameplayManager = world.gameplay_manager
	var player: PlayerShip = world.player
	var pulse: float = 0.5 + 0.5 * sin(gm.elapsed_time * 12.0)
	# World-space markers intentionally use the same coordinates as the grid.
	if world.pickup_time > 0.0:
		var cell: Vector2i = world.pickup_cell
		var point: Vector2 = player.get_cell_position(cell.x, cell.y)
		draw_circle(point, 27, ink)
		draw_arc(point, 26, 0, TAU, 40, white, 2, true)
		draw_arc(point, 31, -PI/2, -PI/2 + TAU * world.pickup_time / 2.7, 48, cyan, 4, true)
		draw_colored_polygon(PackedVector2Array([point + Vector2(5,-19), point + Vector2(-12,3), point + Vector2(-2,3), point + Vector2(-6,19), point + Vector2(13,-5), point + Vector2(3,-5)]), gold)
		var label := "BOOST CELL"
		if gm.cells_collected % 3 == 2:
			if gm.can_repair_hull():
				label = "REPAIR CELL"
			elif gm.collision_count == 0:
				label = "BONUS CELL"
		_center(label, point + Vector2(0,-39), 15, white)
	if world.hazard_time > 0.0:
		var cell: Vector2i = world.hazard_cell
		var point: Vector2 = player.get_cell_position(cell.x, cell.y)
		var box := Rect2(point - Vector2(70, 54), Vector2(140, 108))
		draw_rect(box, Color(1.0, 0.15, 0.1, 0.13 + pulse * 0.12))
		draw_rect(box, red, false, 3.0)
		draw_arc(point, 18 + 40 * clampf(world.hazard_time * gm.difficulty_factor / 1.15, 0, 1), 0, TAU, 48, red, 3, true)
		_center("EVADE!", point + Vector2(0, -61), 20, red)
	if gm.phase == 4 and not gm.is_game_over():
		var target: Vector2 = world.target_ship.position
		var aim_color: Color = cyan if player.grid_col == world.target_ship.grid_col else gold
		draw_arc(target, 52.0, 0, TAU, 40, Color(aim_color, 0.75), 2.0, true)
		draw_arc(target, 60.0, -PI / 2.0, -PI / 2.0 + TAU * maxf(0.001, gm.lock_progress), 40, aim_color, 5.0, true)
		if world.target_switch <= world.TURN_WARNING_TIME:
			var direction := signi(world.next_target_lane - world.target_ship.grid_col)
			var tip := target + Vector2(direction * 77, 0)
			var tail := tip - Vector2(direction * 11, 0)
			var arrow := PackedVector2Array([tail + Vector2(0,-8), tip, tail + Vector2(0,8)])
			draw_polyline(arrow, ink, 7, true)
			draw_polyline(arrow, gold, 3, true)
	if gm.boosting:
		for i in range(9):
			var x: float = 45.0 + float(i % 3) * 26.0
			var y: float = 150.0 + fmod(float(i) * 91.0 + gm.elapsed_time * 850.0, 405.0)
			draw_line(Vector2(x, y), Vector2(x - 16, y + 55), Color(0.41, 0.91, 0.88, 0.45), 2.0, true)
			draw_line(Vector2(1280 - x, y), Vector2(1296 - x, y + 55), Color(0.41, 0.91, 0.88, 0.45), 2.0, true)
	if world.notice_time > 0.0 and not world.notice_positive:
		draw_rect(Rect2(2, 2, 1276, 716), Color(1.0, 0.22, 0.18, world.notice_time * 0.30), false, 10.0)
	var hub := Vector2(84, 643)
	var start := deg_to_rad(135)
	var sweep := deg_to_rad(270)
	draw_circle(hub, 54, ink)
	draw_arc(hub, 51, 0, TAU, 72, white, 2, true)
	draw_arc(hub, 44, start, start + sweep, 64, Color("465468"), 8, true)
	var charge := clampf(gm.energy / 100.0, 0, 1)
	if charge > 0:
		draw_arc(hub, 44, start, start + sweep * charge, 64, gold if gm.boosting else cyan, 8, true)
	_center("%d%%" % roundi(charge * 100), hub + Vector2(0,5), 25, white)
	_center("BOOST", hub + Vector2(0,27), 15, white)
	var hull := gm.max_collisions - gm.collision_count
	_text("HULL  %d/%d" % [hull, gm.max_collisions], hub + Vector2(59,6), 17, red if hull <= 2 else white)
	var seconds := ceili(gm.get_time_remaining())
	_text("FUEL  %d:%02d" % [floori(seconds / 60.0), seconds % 60], hub + Vector2(59,31), 15, red if seconds < 20 else white)
	var objective := "%d m" % ceili(gm.get_distance_remaining())
	if gm.phase == 4:
		objective = "LOCK  %d / %d" % [gm.locks, gm.LOCKS_REQUIRED]
	_center(objective, Vector2(640,47), 22, white)
	for side in [-1,1]:
		for i in range(4):
			var x: float = 640 + side * (80 + i * 14)
			var length := 11 if i == 0 else 5
			draw_line(Vector2(x,40), Vector2(x,40+length), ink, 4, true)
			draw_line(Vector2(x,40), Vector2(x,40+length), gold, 2, true)
	if gm.is_game_over():
		_center(world.phase_notice, Vector2(640,676), 18, white)
	elif gm.elapsed_time < 5:
		_key_hint("WASD / Panah", "Gerak", 316)
		_key_hint("Spasi", "Tahan laser", 510)
		_key_hint("Shift", "Tahan boost", 688)
		_key_hint("Esc", "Jeda", 864)
	elif world.notice_time > 0 and not world.notice.begins_with("DODGE"):
		_center(world.notice, Vector2(640,676), 18, cyan if world.notice_positive else red)
	elif world.phase_notice_time > 0:
		_center(world.phase_notice, Vector2(640,676), 18, white)

func _key_hint(key: String, action: String, x: float) -> void:
	var width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 18
	var cap := Rect2(x, 650, width, 28)
	draw_rect(cap.grow(2), ink)
	draw_rect(cap, white)
	draw_line(cap.position + Vector2(0,26), cap.end - Vector2(0,2), muted, 3)
	draw_string(font, cap.position + Vector2(9,20), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	_text(action, cap.position + Vector2(width + 8,21), 17, white)
