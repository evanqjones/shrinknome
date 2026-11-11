extends Node3D


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_speed("explode", 10.0)
	frames.set_animation_loop("explode", false)
	var sheet: Texture2D = load("res://sprites/animations/robot_explosion.png")
	for index in range(17):
		var tile := AtlasTexture.new()
		tile.atlas = sheet
		tile.region = Rect2(index * 350, 0, 350, 498)
		tile.filter_clip = true
		frames.add_frame("explode", tile)
	var visual := AnimatedSprite3D.new()
	visual.sprite_frames = frames
	visual.pixel_size = 0.00675
	visual.billboard = 2
	visual.alpha_cut = 1
	visual.texture_filter = 0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.animation_finished.connect(queue_free)
	visual.play("explode")
