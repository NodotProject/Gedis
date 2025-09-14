extends RefCounted
class_name GedisPubSub

var _gedis: Gedis

signal pubsub_message(channel, message)
signal psub_message(pattern, channel, message)

signal subscribed(channel, subscriber)
signal unsubscribed(channel, subscriber)

func _init(gedis: Gedis):
	_gedis = gedis

# --------
# Pub/Sub
# --------
func publish(channel: String, message) -> void:
	# Backwards-compatible delivery:
	# 1) If subscriber objects registered via subscribe/psubscribe expect direct signals,
	#    call their 'pubsub_message'/'psub_message' on the subscriber object.
	# 2) Emit a single Gedis-level signal so external code can connect to this Gedis instance.
	# This avoids emitting the same Gedis signal multiple times (which would cause duplicate callbacks).
	# Direct subscribers (back-compat)
	if _gedis._core._subscribers.has(channel):
		for subscriber in _gedis._core._subscribers[channel]:
			if is_instance_valid(subscriber):
				# deliver directly to subscriber object if it exposes the signal
				if subscriber.has_signal("pubsub_message"):
					subscriber.pubsub_message.emit(channel, message)
	# Emit a single Gedis-level pubsub notification for all listeners connected to this Gedis instance.
	if _gedis._core._subscribers.has(channel) and _gedis._core._subscribers[channel].size() > 0:
		pubsub_message.emit(channel, message)
	# Pattern subscribers (back-compat + Gedis-level)
	for pattern in _gedis._core._psubscribers.keys():
		# Use simple glob matching: convert to RegEx
		var rx = _gedis._utils._glob_to_regex(pattern)
		if rx.search(channel) != null:
			for subscriber in _gedis._core._psubscribers[pattern]:
				if is_instance_valid(subscriber):
					if subscriber.has_signal("psub_message"):
						subscriber.psub_message.emit(pattern, channel, message)
			# Emit one Gedis-level pattern message for this matching pattern
			psub_message.emit(pattern, channel, message)

func subscribe(channel: String, subscriber: Object) -> void:
	var arr: Array = _gedis._core._subscribers.get(channel, [])
	# avoid duplicates
	for s in arr:
		if s == subscriber:
			return
	arr.append(subscriber)
	_gedis._core._subscribers[channel] = arr
	subscribed.emit(channel, subscriber)

func unsubscribe(channel: String, subscriber: Object) -> void:
	if not _gedis._core._subscribers.has(channel):
		return
	var arr: Array = _gedis._core._subscribers[channel]
	for i in range(arr.size()):
		if arr[i] == subscriber:
			arr.remove_at(i)
			unsubscribed.emit(channel, subscriber)
			break
	if arr.is_empty():
		_gedis._core._subscribers.erase(channel)
	else:
		_gedis._core._subscribers[channel] = arr

func psubscribe(pattern: String, subscriber: Object) -> void:
	var arr: Array = _gedis._core._psubscribers.get(pattern, [])
	for s in arr:
		if s == subscriber:
			return
	arr.append(subscriber)
	_gedis._core._psubscribers[pattern] = arr
	subscribed.emit(pattern, subscriber)

func punsubscribe(pattern: String, subscriber: Object) -> void:
	if not _gedis._core._psubscribers.has(pattern):
		return
	var arr: Array = _gedis._core._psubscribers[pattern]
	for i in range(arr.size()):
		if arr[i] == subscriber:
			arr.remove_at(i)
			unsubscribed.emit(pattern, subscriber)
			break
	if arr.is_empty():
		_gedis._core._psubscribers.erase(pattern)
	else:
		_gedis._core._psubscribers[pattern] = arr

# -----------
# Introspection
# -----------
func list_channels() -> Array:
	return _gedis._core._subscribers.keys()

func list_subscribers(channel: String) -> Array:
	return _gedis._core._subscribers.get(channel, [])

func list_patterns() -> Array:
	return _gedis._core._psubscribers.keys()

func list_pattern_subscribers(pattern: String) -> Array:
	return _gedis._core._psubscribers.get(pattern, [])
