extends Node3D

const EXPLOSION = preload("res://scripts/robot_explosion.gd")
const IMPACT_RING = preload("res://scripts/rock_shockwave.gd")

signal exploded

const LIFETIME: float = 1.5
const START_SPEED: float = 3.0
const ACCELERATION: float = 2.5
const TURN_RATE: float = 1.5
const HIT_RADIUS: float = 0.78

var player: CharacterBody3D
var direction := Vector3.FORWARD
var age: float = 0.0
var has_exploded: bool = false
var visual: AnimatedSprite3D


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 12.0)
	frames.set_animation_loop("fly", true)
	var sheet: Texture2D = load("res://sprites/animations/robot_missile_fly.png")
	for index in range(4):
		var tile := AtlasTexture.new()
		tile.atlas = sheet
		tile.region = Rect2(index * 64, 0, 64, 64)
		tile.filter_clip = true
		frames.add_frame("fly", tile)
	visual = AnimatedSprite3D.new()
	visual.sprite_frames = frames
	visual.pixel_size = 0.05915
	visual.billboard = 2
	visual.alpha_cut = 1
	visual.texture_filter = 0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.play("fly")


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		_explode()
		return
	if is_instance_valid(player):
		var desired := player.global_position - global_position
		desired.y = 0.0
		if desired.length_squared() > 0.01:
			direction = direction.lerp(desired.normalized(), minf(TURN_RATE * delta, 1.0)).normalized()
	var speed := START_SPEED + ACCELERATION * age
	global_position += direction * speed * delta
	if absf(direction.x) > 0.05:
		visual.flip_h = direction.x > 0.0
	if is_instance_valid(player):
		var separation := player.global_position - global_position
		separation.y = 0.0
		if separation.length() <= HIT_RADIUS:
			_explode()


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	var blast = EXPLOSION.new()
	get_parent().add_child(blast)
	blast.global_position = global_position
	var ring = IMPACT_RING.new()
	ring.player = player
	ring.duration = 0.35
	ring.end_radius = 1.25
	ring.knockback_strength = 5.0
	get_parent().add_child(ring)
	ring.global_position = Vector3(global_position.x, 0.11, global_position.z)
	exploded.emit()
	queue_free()
