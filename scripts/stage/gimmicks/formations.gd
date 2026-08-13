extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 1-1: chain formations live on FormationTracker; director only toasts.


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("CHAIN FORMATIONS")