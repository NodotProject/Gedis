class_name GedisTickTimeSource
extends GedisTimeSource

# Returns the current time as a Unix timestamp with milliseconds.
func get_time() -> int:
	return Time.get_ticks_msec()
