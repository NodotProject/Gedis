class_name GedisTimeSource
extends RefCounted

var instance: Gedis

# Returns the current time as a Unix timestamp in milliseconds.
func get_time() -> int:
	return 0

# Increments the time [Optional]
func tick(_delta) -> void:
	instance.purge_expired()
