class_name GedisProcessDeltaTimeSource
extends GedisTimeSource

var current_time: int = 0

func _init() -> void:
	current_time = Time.get_unix_time_from_system() * 1000

func tick(delta: float) -> void:
	current_time += int(delta * 1000)
	instance.purge_expired()

# Returns the current time as a Unix timestamp with milliseconds.
func get_time() -> int:
	return current_time
