extends Node2D

var gedis := Gedis.new()
const ITEM_LIST = ["Gem", "Coin", "Sword"]

var score_label: Label
var inventory_label: Label
var leaderboard_label: Label
var powerup_label: Label

func _ready():
	score_label = $ScoreLabel
	inventory_label = $InventoryLabel
	leaderboard_label = $LeaderboardLabel
	powerup_label = $PowerupLabel
	gedis.set_value("score", 0)
	
	randomize()
	update_labels()
	
	# Connect signals
	$ClickButton.pressed.connect(_on_ClickButton_pressed)
	$PowerupButton.pressed.connect(_on_PowerupButton_pressed)
	$SaveButton.pressed.connect(_on_SaveButton_pressed)
	$LoadButton.pressed.connect(_on_LoadButton_pressed)
	
	_subscribe_to_updates()

func _subscribe_to_updates():
	# Subscribe to channels
	gedis.subscribe("score_updated", self)
	gedis.subscribe("powerup_status_changed", self)
	if not gedis.pubsub_message.is_connected(_on_gedis_message):
		gedis.pubsub_message.connect(_on_gedis_message)

func _on_gedis_message(channel, _payload):
	if channel == "score_updated" or channel == "powerup_status_changed":
		update_labels()

func _on_ClickButton_pressed():
	var points = 1
	if gedis.exists("powerup:double_points"):
		points = 2
	
	gedis.incr("score", points)
	
	# 10% chance to find an item
	if randf() < 0.1:
		var item = ITEM_LIST[randi() % ITEM_LIST.size()]
		gedis.sadd("inventory", item)
	
	gedis.zadd("leaderboard", "Player", gedis.get_value("score"))
	gedis.publish("score_updated", null)

func _on_PowerupButton_pressed():
	gedis.setex("powerup:double_points", 10, true)
	gedis.publish("powerup_status_changed", null)

func _on_SaveButton_pressed():
	gedis.save("user://savegame.json")

func _on_LoadButton_pressed():
	if gedis.load("user://savegame.json") == OK:
		_subscribe_to_updates()
		gedis.publish("score_updated", null)
		gedis.publish("powerup_status_changed", null)
	else:
		print("Failed to load savegame.")

func update_labels(_payload = null):
	score_label.text = "Score: " + str(int(gedis.get_value("score")))
	
	var inventory_items = gedis.smembers("inventory")
	inventory_label.text = "Inventory: " + var_to_str(inventory_items)
	
	var leaderboard = gedis.zrevrange("leaderboard", 0, INF, true)
	leaderboard_label.text = "Leaderboard:\n"
	for entry in leaderboard:
		leaderboard_label.text += str(entry[0]) + ": " + str(int(entry[1])) + "\n"

	if gedis.exists("powerup:double_points"):
		powerup_label.text = "Power-up: Active"
	else:
		powerup_label.text = "Power-up: Inactive"
