extends Node3D

signal depleted

const RECOIL_DURATION: float = 0.32
const RECOIL_HEIGHT: float = 0.28
const RECOIL_TILT: float = 0.30

var max_health: int = 2
var health: int = 2
var actor: Node3D
var visual: AnimatedSprite3D
var is_player: bool = false
var knockback_velocity := Vector3.ZERO
var flash_remaining: float = 0.0
var pending_depletion: bool = false
var bar: Sprite3D
var flash_sprite: Sprite3D
var white_frames: Dictionary = {}
var displayed_frame: String = ""
var recoil_elapsed: float = RECOIL_DURATION
var recoil_side: float = 1.0
var ground_y: float = 0.0
var visual_rotation_z: float = 0.0
var dodge_hint: Label3D
var dodge_hint_remaining: float = 0.0


func setup(owner_actor: Node3D, owner_visual: AnimatedSprite3D, amount: int, player_bar: bool = false) -> void:
	actor = owner_actor
	visual = owner_visual
	max_health = amount
	health = amount
	is_player = player_bar
	ground_y = actor.global_position.y
	visual_rotation_z = visual.rotation.z
	position.y = 1.35 if is_player else visual.position.y + visual.pixel_size * 32.0 + 0.1
	if is_player:
		dodge_hint = Label3D.new()
		dodge_hint.name = "DamageDodgeHint"
		dodge_hint.text = "SHRINK TO DODGE!"
		dodge_hint.position = Vector3(0.0, 2.15, 0.0)
		dodge_hint.font_size = 42
		dodge_hint.pixel_size = 0.01
		dodge_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dodge_hint.no_depth_test = true
		dodge_hint.modulate = Color("ffe36b")
		dodge_hint.outline_modulate = Color("172332")
		dodge_hint.visible = false
		actor.add_child(dodge_hint)
	flash_sprite = Sprite3D.new()
	flash_sprite.name = "WhiteFlash"
	flash_sprite.position = visual.position - position
	flash_sprite.pixel_size = visual.pixel_size
	flash_sprite.billboard = visual.billboard
	flash_sprite.alpha_cut = visual.alpha_cut
	flash_sprite.texture_filter = visual.texture_filter
	flash_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_sprite.shaded = false
	flash_sprite.visible = false
	add_child(flash_sprite)
	bar = Sprite3D.new()
	bar.name = "HealthBar"
	bar.pixel_size = 0.024
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.no_depth_test = true
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	_refresh_bar()


func _process(delta: float) -> void:
	if dodge_hint_remaining > 0.0:
		dodge_hint_remaining = maxf(0.0, dodge_hint_remaining - delta)
		if dodge_hint_remaining == 0.0:
			dodge_hint.hide()
	if flash_remaining > 0.0:
		_update_flash_frame()
		flash_remaining -= delta
		if flash_remaining <= 0.0 and is_instance_valid(visual):
			flash_sprite.hide()
			visual.show()
	if not is_player and knockback_velocity.length_squared() > 0.001:
		actor.global_position += knockback_velocity * delta
		knockback_velocity *= exp(-10.0 * delta)
	if not is_player and recoil_elapsed < RECOIL_DURATION:
		recoil_elapsed = minf(recoil_elapsed + delta, RECOIL_DURATION)
		var progress := recoil_elapsed / RECOIL_DURATION
		var arc := sin(PI * progress)
		actor.global_position.y = ground_y + arc * RECOIL_HEIGHT
		visual.rotation.z = visual_rotation_z + recoil_side * arc * RECOIL_TILT
		flash_sprite.rotation.z = visual.rotation.z
	if pending_depletion and flash_remaining <= 0.0 and (is_player or recoil_elapsed >= RECOIL_DURATION):
		pending_depletion = false
		depleted.emit()


func take_hit(from_position: Vector3, strength: float = 6.0) -> bool:
	if health <= 0 or (is_player and actor.is_shrunk):
		return false
	health -= 1
	_refresh_bar()
	flash_remaining = 0.14
	_update_flash_frame()
	visual.hide()
	flash_sprite.show()
	if is_player:
		dodge_hint_remaining = 1.4
		dodge_hint.show()
		actor.apply_knockback(from_position, strength)
	else:
		var away := actor.global_position - from_position
		away.y = 0.0
		if away.length_squared() < 0.001:
			away = Vector3.FORWARD
		knockback_velocity = away.normalized() * maxf(strength, 7.0)
		recoil_side = -1.0 if away.x < 0.0 else 1.0
		recoil_elapsed = 0.0
	if health == 0:
		pending_depletion = true
		if not is_player:
			actor.set_process(false)
	return true


func _update_flash_frame() -> void:
	var key := "%s:%d" % [visual.animation, visual.frame]
	flash_sprite.flip_h = visual.flip_h
	flash_sprite.flip_v = visual.flip_v
	flash_sprite.scale = visual.scale
	flash_sprite.rotation.z = visual.rotation.z
	if key == displayed_frame:
		return
	displayed_frame = key
	if not white_frames.has(key):
		var source: Texture2D = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
		var image := source.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
		white_frames[key] = ImageTexture.create_from_image(image)
	flash_sprite.texture = white_frames[key]


func _refresh_bar() -> void:
	var image := Image.create(42, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("10151c"))
	image.fill_rect(Rect2i(1, 1, 40, 6), Color("6b2424"))
	var width := int(40.0 * float(health) / float(max_health))
	if width > 0:
		image.fill_rect(Rect2i(1, 1, width, 6), Color("62df72") if is_player else Color("efb04e"))
	bar.texture = ImageTexture.create_from_image(image)
