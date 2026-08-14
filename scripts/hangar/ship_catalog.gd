class_name ShipCatalog
extends Object
## Strike-craft roster and hangar upgrade math.
## Meta-progression is buying hulls and ranking their systems — not a player XP level.

const STARTER_ID := "striker"
const MAX_UPGRADE := 5
const CREDITS_PER_SCORE := 10
const UPGRADE_KEYS: PackedStringArray = ["hull", "thrust", "cannon", "core"]
const UPGRADE_COSTS: Array[int] = [400, 900, 1600, 2600, 4000]
const UPGRADE_LABELS := {
	"hull": "Hull",
	"thrust": "Thrusters",
	"cannon": "Cannons",
	"core": "Core",
}
const UPGRADE_HINTS := {
	"hull": "+1 HP per rank",
	"thrust": "+5% speed per rank",
	"cannon": "+8% damage per rank",
	"core": "+4% fire rate per rank",
}

const HULL_HP_PER_RANK := 1
const THRUST_PER_RANK := 0.05
const CANNON_PER_RANK := 0.08
const CORE_PER_RANK := 0.04
const MIN_FIRE_COOLDOWN := 0.08
const BASE_FIRE_COOLDOWN := 0.16

static var _defs: Array[Dictionary] = []


static func all_defs() -> Array[Dictionary]:
	if _defs.is_empty():
		_defs = _build()
	return _defs


static func all_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for def in all_defs():
		ids.append(String(def["id"]))
	return ids


static func get_def(ship_id: String) -> Dictionary:
	for def in all_defs():
		if String(def["id"]) == ship_id:
			return def
	return {}


static func is_upgrade_key(key: String) -> bool:
	return UPGRADE_KEYS.has(key)


static func credits_from_score(score: int) -> int:
	if score <= 0:
		return 0
	return score / CREDITS_PER_SCORE


static func format_credits(amount: int) -> String:
	var s := str(maxi(0, amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func upgrade_cost(current_rank: int) -> int:
	if current_rank < 0 or current_rank >= MAX_UPGRADE:
		return 0
	return UPGRADE_COSTS[current_rank]


static func empty_ranks() -> Dictionary:
	return {"hull": 0, "thrust": 0, "cannon": 0, "core": 0}


static func normalize_ranks(raw: Variant) -> Dictionary:
	var out := empty_ranks()
	if raw is Dictionary:
		for key in UPGRADE_KEYS:
			out[key] = clampi(int(raw.get(key, 0)), 0, MAX_UPGRADE)
	return out


static func parse_ranks(raw: String) -> Dictionary:
	var out := empty_ranks()
	var parts := raw.split(",")
	for i in mini(parts.size(), UPGRADE_KEYS.size()):
		out[UPGRADE_KEYS[i]] = clampi(int(parts[i]), 0, MAX_UPGRADE)
	return out


static func format_ranks(ranks: Dictionary) -> String:
	var n := normalize_ranks(ranks)
	return "%d,%d,%d,%d" % [n["hull"], n["thrust"], n["cannon"], n["core"]]


static func resolve(ship_id: String, ranks: Dictionary = {}) -> Dictionary:
	var def := get_def(ship_id)
	if def.is_empty():
		def = get_def(STARTER_ID)
	var n := normalize_ranks(ranks)
	var hull: int = int(n["hull"])
	var thrust: int = int(n["thrust"])
	var cannon: int = int(n["cannon"])
	var core: int = int(n["core"])
	var cooldown := float(def["fire_cooldown"]) * (1.0 - CORE_PER_RANK * float(core))
	return {
		"id": String(def["id"]),
		"name": String(def["name"]),
		"role": String(def["role"]),
		"blurb": String(def["blurb"]),
		"cost": int(def["cost"]),
		"sprite": String(def["sprite"]),
		"tint": def["tint"],
		"max_hp": int(def["max_hp"]) + hull * HULL_HP_PER_RANK,
		"move_speed": float(def["move_speed"]) * (1.0 + THRUST_PER_RANK * float(thrust)),
		"fire_cooldown": maxf(MIN_FIRE_COOLDOWN, cooldown),
		"bullet_damage": float(def["bullet_damage"]) * (1.0 + CANNON_PER_RANK * float(cannon)),
		"bullet_speed": float(def["bullet_speed"]),
		"lives": int(def["lives"]),
		"start_bombs": int(def["start_bombs"]),
		"start_shields": int(def["start_shields"]),
		"ranks": n,
	}


static func stats_text(spec: Dictionary) -> String:
	var bombs := int(spec.get("start_bombs", 0))
	var shields := int(spec.get("start_shields", 0))
	var extras: PackedStringArray = []
	if bombs > 0:
		extras.append("Bomb ×%d" % bombs)
	if shields > 0:
		extras.append("Shield ×%d" % shields)
	var extra := "   ·   " + "  ".join(extras) if not extras.is_empty() else ""
	return "HP %d    SPD %d    DMG %.2f    ROF %.2fs\nLives ×%d%s" % [
		int(spec.get("max_hp", 7)),
		int(round(float(spec.get("move_speed", 310.0)))),
		float(spec.get("bullet_damage", 1.0)),
		float(spec.get("fire_cooldown", BASE_FIRE_COOLDOWN)),
		int(spec.get("lives", 3)),
		extra,
	]


static func _build() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({
		"id": "striker",
		"name": "Striker",
		"role": "Balanced strike craft",
		"blurb": "Stock hull. Even stats, no tricks — a reliable first sortie.",
		"cost": 0,
		"sprite": "res://assets/sprites/player_ship.svg",
		"tint": Color(1.0, 1.0, 1.0),
		"max_hp": 7,
		"move_speed": 310.0,
		"fire_cooldown": 0.16,
		"bullet_damage": 1.0,
		"bullet_speed": 560.0,
		"lives": 3,
		"start_bombs": 0,
		"start_shields": 0,
	})
	list.append({
		"id": "interceptor",
		"name": "Interceptor",
		"role": "High-speed glass cannon",
		"blurb": "Cuts lanes fast and fires quicker. Hull is thin — don't get greedy.",
		"cost": 2500,
		"sprite": "res://assets/sprites/player_interceptor.svg",
		"tint": Color(0.55, 0.95, 1.0),
		"max_hp": 5,
		"move_speed": 385.0,
		"fire_cooldown": 0.13,
		"bullet_damage": 0.90,
		"bullet_speed": 620.0,
		"lives": 3,
		"start_bombs": 0,
		"start_shields": 0,
	})
	list.append({
		"id": "aegis",
		"name": "Aegis",
		"role": "Armored gunship",
		"blurb": "Extra hull, a spare life, and a shield charge. Heavy on the stick.",
		"cost": 5500,
		"sprite": "res://assets/sprites/player_aegis.svg",
		"tint": Color(1.0, 0.82, 0.45),
		"max_hp": 10,
		"move_speed": 255.0,
		"fire_cooldown": 0.19,
		"bullet_damage": 1.20,
		"bullet_speed": 500.0,
		"lives": 4,
		"start_bombs": 0,
		"start_shields": 1,
	})
	list.append({
		"id": "wraith",
		"name": "Wraith",
		"role": "Raid skirmisher",
		"blurb": "Swept frame with a stocked bomb. Built to dive patterns and leave.",
		"cost": 12000,
		"sprite": "res://assets/sprites/player_wraith.svg",
		"tint": Color(0.78, 0.55, 1.0),
		"max_hp": 6,
		"move_speed": 345.0,
		"fire_cooldown": 0.14,
		"bullet_damage": 1.05,
		"bullet_speed": 580.0,
		"lives": 3,
		"start_bombs": 1,
		"start_shields": 0,
	})
	list.append({
		"id": "dawn",
		"name": "Dawn",
		"role": "Flagship prototype",
		"blurb": "Yard's best remaining hull. Opens with bomb and shield already armed.",
		"cost": 24000,
		"sprite": "res://assets/sprites/player_dawn.svg",
		"tint": Color(1.0, 0.92, 0.55),
		"max_hp": 8,
		"move_speed": 330.0,
		"fire_cooldown": 0.15,
		"bullet_damage": 1.25,
		"bullet_speed": 600.0,
		"lives": 3,
		"start_bombs": 1,
		"start_shields": 1,
	})
	return list