extends CharacterBody3D

@export var move_speed: float = 4.0
@export var sword_ring_radius: float = 0.55
@export var combo_window: float = 0.85
@export var min_world_x: float = -13.0
@export var max_world_x: float = 13.0
@export var min_world_z: float = -8.0
@export var max_world_z: float = 8.0
@onready var visual: AnimatedSprite3D = $Visual
@onready var collision: CollisionShape3D = $Collision

const GRAVITY: float = 24.0
const KNOCKBACK_DECAY: float = 7.0
const SWORD_TEXTURE: Texture2D = preload("res://sprites/wooden_sword.png")
const SWING_DURATION: float = 0.34
const SHRINK_SCALE: float = 0.45
const SHRINK_HEIGHT_ADJUSTMENT: float = 0.4675

var knockback_velocity := Vector3.ZERO
var aim_direction := Vector2.LEFT
var sword_pivot: Node3D
var sword: Sprite3D
var combo_index: int = -1
var previous_swing_time: float = -10.0
var swing_elapsed: float = 0.0
var swing_direction: float = 1.0
var swinging: bool = false
var is_shrunk: bool = false
var swing_hit_applied: bool = false
var defeated: bool = false


func _ready() -> void:
	visual.play("idle")
	sword_pivot = Node3D.new()
	sword_pivot.name = "SwordGrip"
	add_child(sword_pivot)
	sword = Sprite3D.new()
	sword.name = "WoodenSword"
	sword.texture = SWORD_TEXTURE
	sword.pixel_size = 0.027
	sword.billboard = 2
	sword.alpha_cut = 1
	sword.texture_filter = 0
	sword.no_depth_test = false
	sword.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sword_pivot.add_child(sword)
	_update_aim()
	_update_sword(0.0)


func _input(event: InputEvent) -> void:
	if defeated:
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_set_shrunk(not is_shrunk)
		get_viewport().set_input_as_handled()
	elif not is_shrunk and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_swing()


func _set_shrunk(shrunk: bool) -> void:
	is_shrunk = shrunk
	var target_scale := SHRINK_SCALE if shrunk else 1.0
	visual.scale = Vector3.ONE * target_scale
	collision.scale = Vector3.ONE * target_scale
	if shrunk:
		global_position.y -= SHRINK_HEIGHT_ADJUSTMENT
	else:
		global_position.y += SHRINK_HEIGHT_ADJUSTMENT
	sword.visible = not shrunk
	if shrunk:
		swinging = false
		knockback_velocity = Vector3.ZERO


func _process(delta: float) -> void:
	_update_aim()
	_update_sword(delta)


func _physics_process(delta: float) -> void:
	var left := Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)
	var input := Vector2(int(right) - int(left), int(down) - int(up)).normalized()

	velocity.x = input.x * move_speed + knockback_velocity.x
	velocity.z = input.y * move_speed + knockback_velocity.z
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	knockback_velocity *= exp(-KNOCKBACK_DECAY * delta)

	global_position.x = clampf(global_position.x, min_world_x, max_world_x)
	global_position.z = clampf(global_position.z, min_world_z, max_world_z)
	if input.length_squared() > 0.0:
		if visual.animation != "walk":
			visual.play("walk")
	elif visual.animation != "idle":
		visual.play("idle")


func _update_aim() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if ground is Vector3:
		var toward := Vector2(ground.x - global_position.x, ground.z - global_position.z)
		if toward.length_squared() > 0.001:
			aim_direction = toward.normalized()
	visual.flip_h = aim_direction.x > 0.0


func _start_swing() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - previous_swing_time > combo_window:
		combo_index = 0
	else:
		combo_index = (combo_index + 1) % 3
	previous_swing_time = now
	swing_direction = 1.0 if combo_index % 2 == 0 else -1.0
	swing_elapsed = 0.0
	swinging = true
	swing_hit_applied = false


func _update_sword(delta: float) -> void:
	var orbit_angle := aim_direction.angle()
	var slash_rotation := 0.0
	if swinging:
		swing_elapsed += delta
		var progress := clampf(swing_elapsed / SWING_DURATION, 0.0, 1.0)
		if progress >= 0.45 and not swing_hit_applied:
			swing_hit_applied = true
			_hit_enemies()
		var orbit_arc := 1.05 if combo_index < 2 else 1.35
		var rotation_arc := 1.4 if combo_index < 2 else 1.7
		if progress < 0.78:
			var stroke := progress / 0.78
			orbit_angle += lerpf(-orbit_arc, orbit_arc, stroke) * swing_direction
			slash_rotation = lerpf(-rotation_arc, rotation_arc, stroke) * swing_direction
		else:
			var recovery := (progress - 0.78) / 0.22
			orbit_angle += orbit_arc * swing_direction * (1.0 - recovery)
			slash_rotation = rotation_arc * swing_direction * (1.0 - recovery)
		if progress >= 1.0:
			swinging = false

	var orbit := Vector2(cos(orbit_angle), sin(orbit_angle)) * sword_ring_radius
	sword_pivot.position = Vector3(orbit.x, -0.12, orbit.y)
	var outward := Vector3(orbit.x, 0.0, orbit.y).normalized()
	sword.position = outward * 0.30
	var camera := get_viewport().get_camera_3d()
	var screen_direction := Vector2(outward.x, -outward.z)
	var mirrored := aim_direction.x < 0.0
	if camera != null:
		var basis := camera.global_transform.basis
		screen_direction = Vector2(outward.dot(basis.x), outward.dot(basis.y))
	sword.flip_h = mirrored
	if screen_direction.length_squared() > 0.001:
		# Keep the grip at the pivot and rotate the blade through each swing.
		var mirror_rotation := -PI / 2.0 if mirrored else 0.0
		sword.rotation.z = screen_direction.angle() - PI / 4.0 + mirror_rotation + slash_rotation


func apply_knockback(from_position: Vector3, strength: float) -> void:
	if is_shrunk:
		return
	var away := global_position - from_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	knockback_velocity = away.normalized() * strength


func _hit_enemies() -> void:
	var forward := Vector3(aim_direction.x, 0.0, aim_direction.y)
	for candidate in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy: Node3D = candidate
		var toward := enemy.global_position - global_position
		toward.y = 0.0
		if toward.length_squared() > 3.24 or toward.length_squared() < 0.001:
			continue
		if toward.normalized().dot(forward) < 0.2:
			continue
		var enemy_health: Node = enemy.get_node("Health")
		if enemy_health.health > 0:
			enemy_health.take_hit(global_position, 5.5)
