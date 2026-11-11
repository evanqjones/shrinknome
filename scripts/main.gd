extends Node3D

const HEALTH = preload("res://scripts/combat_health.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $FollowCamera
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var combat_status: Label = $HUD/CombatStatus

var enemies: Array[Node3D]

const CAMERA_OFFSET := Vector3(0.0, 3.8, 8.0)
const CAMERA_LOOK_HEIGHT: float = 1.15


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("172332")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d0d0")
	environment.ambient_light_energy = 0.65
	if world_environment.environment == null:
		world_environment.environment = environment
	build_decor()
	var player_health = HEALTH.new()
	player_health.name = "Health"
	player.add_child(player_health)
	player_health.setup(player, player.get_node("Visual"), 8, true)
	player_health.depleted.connect(_on_player_defeated)
	enemies = [$Rock, $Tree, $Robot]
	for index in enemies.size():
		enemies[index].add_to_group("combat_enemies")
		var enemy_health = HEALTH.new()
		enemy_health.name = "Health"
		enemies[index].add_child(enemy_health)
		enemy_health.setup(enemies[index], enemies[index].get_node("Visual"), 2)
		enemy_health.depleted.connect(_on_enemy_defeated.bind(enemies[index]))
		var prompt := Label3D.new()
		prompt.name = "CombatNumber"
		prompt.text = str(index + 1)
		prompt.font_size = 64
		prompt.pixel_size = 0.008
		prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt.no_depth_test = true
		prompt.modulate = Color("ffe28a")
		prompt.outline_modulate = Color("172332")
		var sprite: AnimatedSprite3D = enemies[index].get_node("Visual")
		prompt.position = Vector3(0.0, sprite.position.y + sprite.pixel_size * 32.0 + 0.5, 0.0)
		enemies[index].add_child(prompt)
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3(0.0, CAMERA_LOOK_HEIGHT, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	var target := player.global_position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
		KEY_3: index = 2
	if index >= 0:
		if enemies[index].get_node("Health").health <= 0:
			return
		var active: bool = enemies[index].toggle_engagement()
		var prompt: Label3D = enemies[index].get_node("CombatNumber")
		prompt.modulate = Color("a8ff97") if active else Color("ffe28a")
		combat_status.text = "%s combat: %s" % [enemies[index].name, "ON" if active else "OFF"]


func _on_enemy_defeated(enemy: Node3D) -> void:
	if enemy.get("engaged"):
		enemy.toggle_engagement()
	enemy.set_process(false)
	enemy.get_node("CombatNumber").hide()
	enemy.get_node("Health").hide()
	enemy.get_node("Visual").hide()
	combat_status.text = "%s defeated" % enemy.name


func _on_player_defeated() -> void:
	player.set("defeated", true)
	player.set_physics_process(false)
	player.set_process(false)
	combat_status.text = "Player defeated"


func build_decor() -> void:
	# Shallow stone tiles show that the sprites occupy a real 3D floor.
	for row in range(3):
		for column in range(9):
			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.45, 0.035, 1.2)
			tile.mesh = mesh
			tile.position = Vector3((column - 4) * 1.65, 0.025, (row - 1) * 3.2)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("556a68") if (row + column) % 2 == 0 else Color("485c5b")
			tile.material_override = material
			add_child(tile)
	for location in [Vector3(-8.5, 0.3, -5.5), Vector3(8.5, 0.3, -5.5), Vector3(-8.5, 0.3, 5.5), Vector3(8.5, 0.3, 5.5)]:
		var marker := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = Vector3(0.8, 0.6, 0.8)
		marker.mesh = block
		marker.position = location
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color("778486")
		marker.material_override = stone
		add_child(marker)
