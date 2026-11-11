extends Node3D

const IMPACT_RING = preload("res://scripts/rock_shockwave.gd")

signal finished

const EFFECT_FPS: float = 10.0

var player: CharacterBody3D
var impact_spawned: bool = false
var leaves: AnimatedSprite3D
var active_ring: Node3D


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("leaves")
	frames.set_animation_speed("leaves", EFFECT_FPS)
	frames.set_animation_loop("leaves", false)
	var sheet: Texture2D = load("res://sprites/animations/tree_leaf_circle.png")
	for index in range(8):
		var tile := AtlasTexture.new()
		tile.atlas = sheet
		tile.region = Rect2(index * 64, 0, 64, 64)
		tile.filter_clip = true
		frames.add_frame("leaves", tile)
	leaves = AnimatedSprite3D.new()
	leaves.sprite_frames = frames
	leaves.pixel_size = 0.07
	leaves.position.y = 0.07
	leaves.rotation.x = -PI / 2.0
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaves.alpha_cut = 1
	leaves.texture_filter = 0
	add_child(leaves)
	leaves.frame_changed.connect(_on_frame_changed)
	leaves.animation_finished.connect(_on_animation_finished)
	leaves.play("leaves")


func _on_frame_changed() -> void:
	if impact_spawned or leaves.frame != 3:
		return
	impact_spawned = true
	var ring = IMPACT_RING.new()
	ring.player = player
	ring.end_radius = 2.4
	ring.knockback_strength = 6.0
	ring.ring_color = Color(0.25, 0.95, 0.38, 0.9)
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.14, 0.0)
	active_ring = ring


func cancel() -> void:
	if is_instance_valid(active_ring):
		active_ring.queue_free()
	queue_free()


func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
