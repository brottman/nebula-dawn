extends Node
## Global gameplay signals so systems stay loosely coupled.

signal score_changed(new_score: int)
signal player_hp_changed(current: int, maximum: int)
signal player_died
signal mission_won
signal mission_lost
signal wave_started(wave_index: int, total_waves: int, label: String)
signal wave_cleared(wave_index: int)
signal boss_spawned(boss: Node)
signal boss_hp_changed(current: float, maximum: float)
signal boss_defeated
signal pickup_collected(kind: String)
signal weapon_changed(weapon_name: String)
signal weapon_tier_changed(slot: String, level: int, chips: int, chips_needed: int, extras: String)
signal enemy_killed(is_hazard: bool, is_boss: bool)
signal player_hull_hit
signal screen_shake(amount: float, duration: float)
signal formation_cleared(center: Vector2, size: int)
signal overdrive_changed(current: float, maximum: float)
signal overdrive_activated
signal gimmick_toast(text: String)
signal player_lives_changed(lives: int)
signal bomb_stock_changed(bombs: int)
## Graze/combo scoring (combo = kills+grazes within a short window).
signal graze_occurred
signal combo_changed(combo: int)
## Brief Engine.time_scale freeze for impact (juice).
signal hitstop_requested(seconds: float)
