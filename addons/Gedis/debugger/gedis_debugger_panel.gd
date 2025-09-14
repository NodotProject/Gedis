@tool
extends VBoxContainer

@export var pub_sub_tree: Tree
@export var fetch_pubsub_button: Button
@export var instance_selector: OptionButton

var plugin

func _ready() -> void:
	_populate_pubsub_tree()
	fetch_pubsub_button.pressed.connect(_on_fetch_pubsub_pressed)

func _on_fetch_pubsub_pressed():
	if plugin:
		var selected_id = instance_selector.get_item_id(instance_selector.selected)
		plugin.send_message_to_game("request_instance_data", [selected_id, "pubsub"])

func _populate_pubsub_tree():
	if not pub_sub_tree:
		return
	pub_sub_tree.clear()
