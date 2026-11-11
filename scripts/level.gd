extends "res://scripts/main.gd"

const HEALTH_COMPONENT = preload("res://scripts/combat_health.gd")
const LEVEL_CAMERA_OFFSET := Vector3(0.0, 5.2, 9.8)

@onready var goal: Area3D = $PotGoal
@onready var win_label: Label = $HUD/WinLabel
@onready var shrink_hint: Label = $HUD/ShrinkHint

var won: bool = false


func _ready() -> void:
	super._ready()
	for entry in [["Rock2", 1], ["Tree2", 2], ["Robot2", 3]]:
		var enemy: Node3D = get_node(entry[0])
		enemies.append(enemy)
		enemy.add_to_group("combat_enemies")
		var health = HEALTH_COMPONENT.new()
		health.name = "Health"
		enemy.add_child(health)
		var sprite: AnimatedSprite3D = enemy.get_node("Visual")
		health.setup(enemy, sprite, 2)
		health.depleted.connect(_on_enemy_defeated.bind(enemy))
		var prompt := Label3D.new()
		prompt.name = "CombatNumber"
		prompt.text = str(entry[1])
		prompt.font_size = 64
		prompt.pixel_size = 0.008
		prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt.no_depth_test = true
		prompt.modulate = Color("ffe28a")
		prompt.outline_modulate = Color("172332")
		prompt.position = Vector3(0.0, sprite.position.y + sprite.pixel_size * 32.0 + 0.5, 0.0)
		enemy.add_child(prompt)
	for enemy in enemies:
		enemy.get_node("CombatNumber").hide()
		enemy.engage()
	goal.body_entered.connect(_on_goal_body_entered)
	shrink_hint.hide()
	$HUD/Controls.text = "WASD: Move   Mouse: Aim / attack   Space: Shrink"
	camera.global_position = player.global_position + LEVEL_CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP)


func build_decor() -> void:
	pass


func _process(delta: float) -> void:
	var target := player.global_position + LEVEL_CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	var near_log := absf(player.global_position.x + 34.0) < 5.0 or absf(player.global_position.x - 24.0) < 5.0
	near_log = near_log and absf(player.global_position.z) < 4.4 and not won
	shrink_hint.visible = near_log
	if near_log:
		shrink_hint.text = "Stay small to pass under the log" if player.is_shrunk else "Press SPACE to shrink under the log"


func _unhandled_key_input(_event: InputEvent) -> void:
	pass


func _on_goal_body_entered(body: Node3D) -> void:
	if body != player or won:
		return
	won = true
	win_label.show()
	combat_status.text = "You reached the pot of gold!"
	player.set("defeated", true)
	player.set_physics_process(false)
	player.set_process(false)
