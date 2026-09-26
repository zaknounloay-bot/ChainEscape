class_name Haptics
## Tiny wrapper around device vibration so feedback can be tuned (or turned
## off) in one place. Does nothing on desktop.

static var enabled: bool = true


static func light() -> void:
	_vibrate(12)


static func medium() -> void:
	_vibrate(25)


static func _vibrate(ms: int) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
