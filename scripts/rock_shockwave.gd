extends Node3D

const START_RADIUS: float = 0.18
const HIT_WIDTH: float = 0.25

var duration: float = 0.45
var end_radius: float = 1.65
var knockback_strength: float = 8.5
var ring_color := Color(1.0, 0.75, 0.35, 0.85)

var player: CharacterBody3D
var age: float = 0.0
var has_hit_player: bool = false
var ring: MeshInstance3D
var ring_material: StandardMaterial3D


func _ready() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.72
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 8
	ring = MeshInstance3D.new()
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = ring_color
	ring.material_override = ring_material
	add_child(ring)
	ring.scale = Vector3.ONE * START_RADIUS


func _process(delta: float) -> void:
	age += delta
	var progress := minf(age / duration, 1.0)
	var radius := lerpf(START_RADIUS, end_radius, progress)
	ring.scale = Vector3(radius, maxf(0.09, radius * 0.18), radius)
	ring_material.albedo_color = Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * (1.0 - progress))
	if not has_hit_player and is_instance_valid(player):
		var separation := player.global_position - global_position
		separation.y = 0.0
		if absf(separation.length() - radius) <= HIT_WIDTH + 0.32:
			has_hit_player = true
			player.get_node("Health").take_hit(global_position, knockback_strength)
	if progress >= 1.0:
		queue_free()
