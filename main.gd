# Example script showing how to create and use Gedis instances
# This script can be attached to any node or used as an autoload

extends Node

var my_gedis: Gedis
var shared_gedis: Gedis

func _ready():
	# Create Gedis instances - they will automatically register with the debugger
	my_gedis = Gedis.new()
	my_gedis.set_instance_name("PlayerData")
	
	shared_gedis = Gedis.new()
	shared_gedis.set_instance_name("GameState")
	
	# Add some sample data
	setup_sample_data()
	
func setup_sample_data():
	# Add some sample data to demonstrate the plugin
	my_gedis.set("player:name", "Alice")
	my_gedis.set("player:level", "10")
	my_gedis.set("player:score", "1500")
	
	# Hash example
	my_gedis.hset("player:stats", "health", "100")
	my_gedis.hset("player:stats", "mana", "50")
	my_gedis.hset("player:stats", "strength", "15")
	
	# List example
	my_gedis.lpush("player:inventory", "sword")
	my_gedis.lpush("player:inventory", "potion")
	my_gedis.lpush("player:inventory", "key")
	
	# Set example
	my_gedis.sadd("player:achievements", "first_kill")
	my_gedis.sadd("player:achievements", "level_10")
	
	# Shared game state
	shared_gedis.set("game:state", "playing")
	shared_gedis.set("game:players_online", "42")
	shared_gedis.hset("game:config", "max_players", "100")
	shared_gedis.hset("game:config", "difficulty", "normal")
	
	# Set expiration on some keys (5 minutes)
	my_gedis.expire("player:score", 300)
	shared_gedis.expire("game:players_online", 60)

func _exit_tree():
	# Clean up instances - they will automatically unregister from the debugger
	if my_gedis:
		my_gedis.queue_free()
	if shared_gedis:
		shared_gedis.queue_free()
