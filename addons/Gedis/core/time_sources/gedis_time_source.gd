class_name GedisTimeSource
extends RefCounted

# Returns the current time as a Unix timestamp in milliseconds.
func get_time() -> int:
	return 0

# Increments the time [Optional]
func tick(_delta) -> void:
	pass
