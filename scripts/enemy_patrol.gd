extends Node3D

@export var patrol_distance: float = 1.8
@export var move_speed: float = 1.1
@export var pause_seconds: float = 1.2
@export var start_direction: int = 1
@export var artwork_faces_right: bool = false
@onready var visual: AnimatedSprite3D = $Visual
@onready var player: CharacterBody3D = get_parent().get_node("Player")

var origin_x: float
var direction: int
var pause_remaining: float = 0.0
var engaged: bool = false


func _ready() -> void:
	origin_x = position.x
	direction = 1 if start_direction >= 0 else -1
	update_facing()
	visual.play("walk")


func _process(delta: float) -> void:
	if engaged:
		var toward := player.global_position - global_position
		toward.y = 0.0
		if toward.length() > 1.25:
			global_position += toward.normalized() * move_speed * delta
			visual.flip_h = toward.x < 0.0 if artwork_faces_right else toward.x > 0.0
			if visual.animation != "walk":
				visual.play("walk")
		elif visual.animation != "idle":
			visual.play("idle")
		return
	if pause_remaining > 0.0:
		pause_remaining -= delta
		if pause_remaining <= 0.0:
			direction *= -1
			update_facing()
			visual.play("walk")
		return

	position.x += direction * move_speed * delta
	if absf(position.x - origin_x) >= patrol_distance:
		position.x = origin_x + direction * patrol_distance
		pause_remaining = pause_seconds
		visual.play("idle")


func update_facing() -> void:
	visual.flip_h = direction < 0 if artwork_faces_right else direction > 0


func engage() -> void:
	engaged = true
