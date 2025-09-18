class_name GedisUnixTimeSource
extends GedisTimeSource

# Returns the current time as a Unix timestamp with milliseconds.
func get_time() -> int:
	return Time.get_unix_time_from_system() * 1000
