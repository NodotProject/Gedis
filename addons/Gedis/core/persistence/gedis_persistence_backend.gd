class_name GedisPersistenceBackend

# Base class for persistence backends.
# All backends should inherit from this class and implement the `save` and `load` methods.

func save(data: Dictionary, options: Dictionary) -> int:
	# This method should be implemented by the child class.
	# It should save the data to the persistence layer and return OK or FAILED.
	push_error("save() not implemented in the persistence backend.")
	return FAILED


func load(options: Dictionary) -> Dictionary:
	# This method should be implemented by the child class.
	# It should load the data from the persistence layer and return it as a Dictionary.
	push_error("load() not implemented in the persistence backend.")
	return {}