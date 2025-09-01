extends Node

var gedis := Gedis.new()

func _ready():
	gedis.set("a", "cool")
