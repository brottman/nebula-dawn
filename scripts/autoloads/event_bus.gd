extends Node
## Global gameplay signals so systems stay loosely coupled.

signal score_changed(new_score: int)
signal player_hp_changed(current: int, maximum: int)
signal player_died
signal mission_won
signal mission_lost
signal wave_started(wave_index: int, total_waves: int)
signal wave_cleared(wave_index: int)
signal boss_spawned(boss: Node)
signal boss_hp_changed(current: float, maximum: float)
signal boss_defeated
signal pickup_collected(kind: String)
signal weapon_changed(weapon_name: String)
signal screen_shake(amount: float, duration: float)
