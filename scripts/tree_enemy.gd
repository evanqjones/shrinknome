extends Node3D

const LEAF_AOE = preload("res://scripts/tree_leaf_aoe.gd")

@export var patrol_distance: float = 1.6
@export var move_speed: float = 0.95
@export var pause_seconds: float = 1.0
@export var start_direction: int = -1
@export var chase_speed: float = 2.6
@export var notice_range: float = 6.2
@export var attack_range: float = 1.55

@onready var visual: AnimatedSprite3D = $Visual
@onready var player: CharacterBody3D = get_parent().get_node("Player")

enum State { PATROL, CHASE, CAST, LEAVES }

var state: State = State.PATROL
var origin_x: float
var direction: int
var pause_remaining: float = 0.0
var engaged: bool = false
var active_effect: Node3D


func _ready() -> void:
	origin_x = position.x
	direction = 1 if start_direction >= 0 else -1
	_add_cast_frames()
	visual.animation_finished.connect(_on_cast_finished)
	_face(float(direction))
	visual.play("walk")


func _process(delta: float) -> void:
	if state == State.CAST or state == State.LEAVES:
		return
	var toward := player.global_position - global_position
	toward.y = 0.0
	var distance := toward.length()
	if engaged and distance <= notice_range * 1.5:
		state = State.CHASE
	if state == State.CHASE:
		if distance > notice_range * 1.5:
			state = State.PATROL
			visual.play("walk")
			return
		_face(toward.x)
		if distance <= attack_range:
			state = State.CAST
			visual.play("cast")
			return
		global_position += toward.normalized() * chase_speed * delta
		if visual.animation != "walk":
			visual.play("walk")
		return
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


func engage() -> void:
	engaged = true
	if state == State.PATROL and global_position.distance_to(player.global_position) <= notice_range * 1.5:
		state = State.CHASE


func toggle_engagement() -> bool:
	if engaged:
		engaged = false
		if is_instance_valid(active_effect):
			active_effect.cancel()
		active_effect = null
		state = State.PATROL
		pause_remaining = 0.0
		visual.play("walk")
	else:
		engage()
	return engaged


func _face(horizontal: float) -> void:
	if absf(horizontal) > 0.05:
		visual.flip_h = horizontal > 0.0


func _on_cast_finished() -> void:
	if state != State.CAST:
		return
	state = State.LEAVES
	visual.play("idle")
	var effect = LEAF_AOE.new()
	effect.player = player
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.finished.connect(_on_leaves_finished)
	active_effect = effect


func _on_leaves_finished() -> void:
	active_effect = null
	var toward := player.global_position - global_position
	toward.y = 0.0
	if engaged and toward.length() <= notice_range * 1.5:
		state = State.CHASE
		visual.play("walk")
	else:
		state = State.PATROL
		visual.play("walk")


func _add_cast_frames() -> void:
	var frames := visual.sprite_frames
	if frames.has_animation("cast"):
		frames.remove_animation("cast")
	frames.add_animation("cast")
	frames.set_animation_speed("cast", 8.0)
	frames.set_animation_loop("cast", false)
	var sheet: Texture2D = load("res://sprites/animations/tree_cast.png")
	for index in range(4):
		var tile := AtlasTexture.new()
		tile.atlas = sheet
		tile.region = Rect2(index * 64, 0, 64, 64)
		tile.filter_clip = true
		frames.add_frame("cast", tile)
