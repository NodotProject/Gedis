@tool
extends VBoxContainer

var pub_sub_tree: Tree
var _pubsub_events = []

func _ready() -> void:
	pub_sub_tree = $TabContainer/PubSub/PubSubTree
	if pub_sub_tree:
		_populate_pubsub_tree()

func _parse_message(message: String, data: Array) -> void:
	_pubsub_events.append({"message": message, "data": data})
	_populate_pubsub_events()

func _populate_pubsub_events():
	var events_tree = $TabContainer/PubSub/PubSubEventsTree
	events_tree.clear()
	var root = events_tree.create_item()
	for event in _pubsub_events:
		var event_item = events_tree.create_item(root)
		event_item.set_text(0, event.message)
		event_item.set_text(1, JSON.stringify(event.data))

func _populate_pubsub_tree():
	if not pub_sub_tree:
		return
	pub_sub_tree.clear()

func _update_pubsub_tree(channels_data, patterns_data):
	if not pub_sub_tree:
		pub_sub_tree = $TabContainer/PubSub/PubSubTree
		if not pub_sub_tree:
			return

	pub_sub_tree.clear()
	var root = pub_sub_tree.create_item()

	for channel_info in channels_data:
		var channel_name = channel_info["name"]
		var subscribers = channel_info["subscribers"]
		var channel_item = PubSubTree.create_item(root)
		channel_item.set_text(0, channel_name)
		for sub in subscribers:
			var sub_item = PubSubTree.create_item(channel_item)
			sub_item.set_text(0, str(sub))

	for pattern_info in patterns_data:
		var pattern_name = pattern_info["name"]
		var subscribers = pattern_info["subscribers"]
		var pattern_item = PubSubTree.create_item(root)
		pattern_item.set_text(0, pattern_name + " (pattern)")
		for sub in subscribers:
			var sub_item = PubSubTree.create_item(pattern_item)
			sub_item.set_text(0, str(sub))
