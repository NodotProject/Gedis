class_name ManualTimeSource
extends GedisTimeSource

var _current_time: int = 0

func get_time() -> int:
	return _current_time

func advance_time(ms: int) -> void:
	_current_time += ms