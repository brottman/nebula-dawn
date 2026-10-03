extends Node
## Instantiates one StageGimmick per mission `gimmick_id`.

const GIMMICKS := {
	&"formations": "res://scripts/stage/gimmicks/formations.gd",
	&"asteroids": "res://scripts/stage/gimmicks/asteroids.gd",
	&"nebula": "res://scripts/stage/gimmicks/nebula.gd",
	&"hive": "res://scripts/stage/gimmicks/hive.gd",
	&"gravity": "res://scripts/stage/gimmicks/gravity.gd",
	&"mirrors": "res://scripts/stage/gimmicks/mirrors.gd",
	&"ion": "res://scripts/stage/gimmicks/ion.gd",
	&"phantoms": "res://scripts/stage/gimmicks/phantoms.gd",
	&"scrap": "res://scripts/stage/gimmicks/scrap.gd",
	&"flare": "res://scripts/stage/gimmicks/flare.gd",
}

var mission: MissionData
var player: Node
var pool: ProjectilePool
var entities: Node2D
var formation_tracker: Node
var rng := RandomNumberGenerator.new()

var _gimmick: StringName = &""
var _active: Node


func setup(p_player: Node, p_pool: ProjectilePool, p_entities: Node2D, tracker: Node) -> void:
	player = p_player
	pool = p_pool
	entities = p_entities
	formation_tracker = tracker
	rng.randomize()
	if not EventBus.boss_spawned.is_connected(_on_boss_spawned):
		EventBus.boss_spawned.connect(_on_boss_spawned)
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)


func begin(data: MissionData) -> void:
	mission = data
	_activate_gimmick(data.gimmick_id if data else &"")


func stop() -> void:
	_gimmick = &""
	mission = null
	_clear_active()


func _activate_gimmick(g: StringName) -> void:
	_clear_active()
	_gimmick = g
	var path: String = GIMMICKS.get(g, "")
	if path == "":
		return
	var script: Script = load(path)
	if script == null:
		push_error("Missing gimmick script: %s" % path)
		return
	var node := Node.new()
	node.set_script(script)
	node.name = String(g).capitalize()
	add_child(node)
	_active = node
	if _active.has_method("bind"):
		_active.bind(self)
	if _active.has_method("begin"):
		_active.begin()


func _clear_active() -> void:
	if _active and is_instance_valid(_active):
		if _active.has_method("cleanup"):
			_active.cleanup()
		_active.queue_free()
	_active = null
	if player and player.has_method("clear_zone_effects"):
		player.clear_zone_effects()
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _active == null or not is_instance_valid(_active) or mission == null:
		return
	if _active.has_method("tick"):
		_active.tick(delta)


func _on_boss_spawned(boss: Node) -> void:
	if _active and is_instance_valid(_active) and _active.has_method("on_boss_spawned"):
		_active.on_boss_spawned(boss)


func _on_boss_defeated() -> void:
	if _active and is_instance_valid(_active) and _active.has_method("on_boss_defeated"):
		_active.on_boss_defeated()