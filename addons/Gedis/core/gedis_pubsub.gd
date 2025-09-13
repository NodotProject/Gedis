extends RefCounted
class_name GedisPubSub

var _gedis: Gedis

signal pubsub_message(channel, message)
signal psub_message(pattern, channel, message)

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
					subscriber.emit_signal("pubsub_message", channel, message)
	# Emit a single Gedis-level pubsub notification for all listeners connected to this Gedis instance.
	if _gedis._core._subscribers.has(channel) and _gedis._core._subscribers[channel].size() > 0:
		emit_signal("pubsub_message", channel, message)
	# Pattern subscribers (back-compat + Gedis-level)
	for pattern in _gedis._core._psubscribers.keys():
		# Use simple glob matching: convert to RegEx
		var rx = _gedis._utils._glob_to_regex(pattern)
		if rx.search(channel) != null:
			for subscriber in _gedis._core._psubscribers[pattern]:
				if is_instance_valid(subscriber):
					if subscriber.has_signal("psub_message"):
						subscriber.emit_signal("psub_message", pattern, channel, message)
			# Emit one Gedis-level pattern message for this matching pattern
			emit_signal("psub_message", pattern, channel, message)

func subscribe(channel: String, subscriber: Object) -> void:
	var arr: Array = _gedis._core._subscribers.get(channel, [])
	# avoid duplicates
	for s in arr:
		if s == subscriber:
			return
	arr.append(subscriber)
	_gedis._core._subscribers[channel] = arr

func unsubscribe(channel: String, subscriber: Object) -> void:
	if not _gedis._core._subscribers.has(channel):
		return
	var arr: Array = _gedis._core._subscribers[channel]
	for i in range(arr.size()):
		if arr[i] == subscriber:
			arr.remove_at(i)
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

func punsubscribe(pattern: String, subscriber: Object) -> void:
	if not _gedis._core._psubscribers.has(pattern):
		return
	var arr: Array = _gedis._core._psubscribers[pattern]
	for i in range(arr.size()):
		if arr[i] == subscriber:
			arr.remove_at(i)
			break
	if arr.is_empty():
		_gedis._core._psubscribers.erase(pattern)
	else:
		_gedis._core._psubscribers[pattern] = arr