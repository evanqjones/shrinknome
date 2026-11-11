extends Node3D

const MISSILE = preload("res://scripts/robot_missile.gd")
@export var min_world_x: float = -13.0
@export var max_world_x: float = 13.0
@export var min_world_z: float = -8.0
@export var max_world_z: float = 8.0

@export var patrol_distance: float = 2.0
@export var move_speed: float = 1.25
@export var pause_seconds: float = 1.6
@export var start_direction: int = -1
@export var follow_speed: float = 2.6
@export var notice_range: float = 11.0
@export var follow_distance: float = 4.5
@export var distance_margin: float = 0.4
@export var launch_distance: float = 6.5
@export var minimum_follow_seconds: float = 0.85

@onready var visual: AnimatedSprite3D = $Visual
@onready var player: CharacterBody3D = get_parent().get_node("Player")

enum State { PATROL, TRACK, LAUNCH, WAIT_MISSILE }

var state: State = State.PATROL
var origin_x: float
var direction: int
var pause_remaining: float = 0.0
var follow_remaining: float = 0.0
var missile_spawned: bool = false
var engaged: bool = false
var active_missile: Node3D


func _ready() -> void:
	origin_x = position.x
	direction = 1 if start_direction >= 0 else -1
	_add_attack_frames()
	visual.frame_changed.connect(_on_frame_changed)
	visual.animation_finished.connect(_on_animation_finished)
	_face(float(direction))
	visual.play("walk")


func _process(delta: float) -> void:
	if state == State.LAUNCH or state == State.WAIT_MISSILE:
		return
	var toward := player.global_position - global_position
	toward.y = 0.0
	var distance := toward.length()
	if state == State.PATROL:
		if engaged and distance <= notice_range:
			_begin_tracking()
		else:
			_patrol(delta)
		return
	if distance > notice_range * 1.5:
		_resume_patrol()
		return
	_face(toward.x)
	var move_sign := 0.0
	if distance > follow_distance + distance_margin:
		move_sign = 1.0
	elif distance < follow_distance - distance_margin:
		move_sign = -1.0
	if move_sign != 0.0 and distance > 0.01:
		var step := minf(follow_speed * delta, absf(distance - follow_distance))
		var movement := toward.normalized() * move_sign * step
		global_position.x = clampf(global_position.x + movement.x, min_world_x, max_world_x)
		global_position.z = clampf(global_position.z + movement.z, min_world_z, max_world_z)
		if visual.animation != "walk":
			visual.play("walk")
	elif visual.animation != "idle":
		visual.play("idle")
	follow_remaining -= delta
	if follow_remaining <= 0.0 and distance <= launch_distance and distance >= follow_distance - distance_margin:
		state = State.LAUNCH
		missile_spawned = false
		visual.play("launch")


func engage() -> void:
	engaged = true
	if state == State.PATROL and global_position.distance_to(player.global_position) <= notice_range:
		_begin_tracking()


func toggle_engagement() -> bool:
	if engaged:
		engaged = false
		if is_instance_valid(active_missile):
			active_missile.queue_free()
		active_missile = null
		_resume_patrol()
	else:
		engage()
	return engaged


func _begin_tracking() -> void:
	state = State.TRACK
	follow_remaining = minimum_follow_seconds
	visual.play("walk")


func _resume_patrol() -> void:
	origin_x = position.x
	pause_remaining = 0.0
	state = State.PATROL
	visual.play("walk")


func _patrol(delta: float) -> void:
	if pause_remaining > 0.0:
		pause_remaining -= delta
		if pause_remaining <= 0.0:
			direction *= -1
			_face(float(direction))
			visual.play("walk")
		return
	position.x += direction * move_speed * delta
	if absf(position.x - origin_x) >= patrol_distance:
		position.x = origin_x + direction * patrol_distance
		pause_remaining = pause_seconds
		visual.play("idle")


func _face(horizontal: float) -> void:
	if absf(horizontal) > 0.05:
		visual.flip_h = horizontal > 0.0


func _on_frame_changed() -> void:
	if state != State.LAUNCH or visual.animation != "launch" or visual.frame != 4 or missile_spawned:
		return
	missile_spawned = true
	var toward := player.global_position - global_position
	toward.y = 0.0
	var shot = MISSILE.new()
	shot.player = player
	shot.direction = toward.normalized() if toward.length_squared() > 0.01 else Vector3.FORWARD
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector3(0.0, 1.55, 0.0) + shot.direction * 0.35
	shot.exploded.connect(_on_missile_exploded)
	active_missile = shot


func _on_animation_finished() -> void:
	if state == State.LAUNCH:
		state = State.WAIT_MISSILE
		visual.play("idle_no_missile")


func _on_missile_exploded() -> void:
	active_missile = null
	if engaged and global_position.distance_to(player.global_position) <= notice_range * 1.5:
		_begin_tracking()
	else:
		_resume_patrol()


func _add_attack_frames() -> void:
	_add_strip("launch", "res://sprites/animations/robot_launch.png", 6, 10.0, false)
	_add_strip("idle_no_missile", "res://sprites/animations/robot_idle_no_missile.png", 4, 4.0, true)


func _add_strip(name: String, path: String, count: int, fps: float, looped: bool) -> void:
	var frames := visual.sprite_frames
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, looped)
	var sheet: Texture2D = load(path)
	for index in range(count):
		var tile := AtlasTexture.new()
		tile.atlas = sheet
		tile.region = Rect2(index * 64, 0, 64, 64)
		tile.filter_clip = true
		frames.add_frame(name, tile)
