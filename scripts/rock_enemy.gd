extends Node3D

const SHOCKWAVE = preload("res://scripts/rock_shockwave.gd")

@export var wander_radius: float = 2.0
@export var wander_speed: float = 0.85
@export var chase_speed: float = 5.2
@export var detection_range: float = 4.0
@export var attack_range: float = 1.45

@onready var visual: AnimatedSprite3D = $Visual
@onready var player: CharacterBody3D = get_parent().get_node("Player")

enum State { IDLE, WANDER, CHASE, ATTACK }

var state: State = State.IDLE
var home: Vector3
var wander_target: Vector3
var idle_time: float = 0.0
var attack_cooldown: float = 0.0
var engaged: bool = false
var active_wave: Node3D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	home = global_position
	_install_attack_frames()
	visual.animation_finished.connect(_on_animation_finished)
	visual.frame_changed.connect(_on_frame_changed)
	_enter_idle()


func _process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var toward := player.global_position - global_position
	toward.y = 0.0
	var distance := toward.length()
	if state == State.ATTACK:
		return
	if engaged and distance <= detection_range * 1.5:
		state = State.CHASE
	if state == State.CHASE:
		if distance > detection_range * 1.6:
			_enter_idle()
			return
		_face(toward.x)
		if distance <= attack_range and attack_cooldown <= 0.0:
			state = State.ATTACK
			visual.play("swing_down")
			return
		if distance > attack_range:
			global_position += toward.normalized() * chase_speed * delta
		if visual.animation != "run_raised":
			visual.play("run_raised")
		return
	if state == State.IDLE:
		idle_time -= delta
		if idle_time <= 0.0:
			_choose_wander_target()
		return
	var to_target := wander_target - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.12:
		_enter_idle()
		return
	_face(to_target.x)
	global_position += to_target.normalized() * wander_speed * delta


func engage() -> void:
	engaged = true
	if state != State.ATTACK and global_position.distance_to(player.global_position) <= detection_range * 1.5:
		state = State.CHASE


func toggle_engagement() -> bool:
	if engaged:
		engaged = false
		if is_instance_valid(active_wave):
			active_wave.queue_free()
		active_wave = null
		_enter_idle()
	else:
		engage()
	return engaged


func _face(horizontal: float) -> void:
	if absf(horizontal) > 0.05:
		visual.flip_h = horizontal < 0.0


func _enter_idle() -> void:
	state = State.IDLE
	idle_time = rng.randf_range(0.8, 2.0)
	visual.play("idle")


func _choose_wander_target() -> void:
	state = State.WANDER
	var offset := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(0.6, wander_radius)
	wander_target = home + Vector3(offset.x, 0.0, offset.y)
	visual.play("walk")


func _on_animation_finished() -> void:
	if state == State.ATTACK:
		attack_cooldown = 0.35
		if engaged and player.global_position.distance_to(global_position) <= detection_range * 1.6:
			state = State.CHASE
			visual.play("run_raised")
		else:
			_enter_idle()


func _on_frame_changed() -> void:
	if state != State.ATTACK or visual.animation != "swing_down" or visual.frame != 4:
		return
	var toward := player.global_position - global_position
	toward.y = 0.0
	var club_side := -1.0 if visual.flip_h else 1.0
	var impact := global_position + Vector3(0.9 * club_side, 0.06, 0.0)
	if toward.length_squared() > 0.01:
		impact.z += toward.normalized().z * 0.3
	var wave = SHOCKWAVE.new()
	wave.player = player
	get_parent().add_child(wave)
	wave.global_position = impact
	active_wave = wave


func _install_attack_frames() -> void:
	var frames := visual.sprite_frames
	_add_strip(frames, "run_raised", "res://sprites/animations/rock_run_raised.png", 4, 8.0, true)
	_add_strip(frames, "swing_down", "res://sprites/animations/rock_swing_down.png", 9, 10.0, false)


func _add_strip(frames: SpriteFrames, name: String, path: String, count: int, fps: float, looped: bool) -> void:
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
