class_name GedisUtils

# ----------------
# Utility functions
# ----------------
func _glob_to_regex(glob: String) -> RegEx:
	var escaped := ""
	for ch in glob:
		match ch:
			".":
				escaped += "\\."
			"*":
				escaped += ".*"
			"?":
				escaped += "."
			"+":
				escaped += "\\+"
			"(":
				escaped += "\\("
			")":
				escaped += "\\)"
			"[":
				escaped += "\\["
			"]":
				escaped += "\\]"
			"^":
				escaped += "\\^"
			"$":
				escaped += "\\$"
			"|":
				escaped += "\\|"
			"\\":
				escaped += "\\\\"
			_:
				escaped += ch
	var r := RegEx.new()
	r.compile("^%s$" % escaped)
	return r