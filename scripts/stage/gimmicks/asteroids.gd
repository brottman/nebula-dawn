extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 1-2: split/block lives on asteroid enemies; director only toasts.


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("SPLITTING ROCKS")