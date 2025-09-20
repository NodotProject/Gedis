class_name GedisUtils
var _regex_cache := {}

# ----------------
# Utility functions
# ----------------
func _glob_to_regex(glob: String) -> RegEx:
	if _regex_cache.has(glob):
		return _regex_cache[glob]

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
	_regex_cache[glob] = r
	return r