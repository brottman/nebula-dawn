extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 1-5: singularities. Pull lives on the well itself.


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("SINGULARITIES")


func tick(_delta: float) -> void:
	super.tick(_delta)
	if pulse <= 0.0:
		pulse = rng.randf_range(8.0, 12.0)
		spawn_singularity()