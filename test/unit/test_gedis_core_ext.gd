extends "res://addons/gut/test.gd"

var gedis

func before_each():
	gedis = Gedis.new()
	gedis.flushall()

func after_each():
	gedis.free()

func test_move_key_to_different_db():
	gedis.set("mykey", "myvalue")
	assert_true(gedis.move("mykey", 1), "MOVE should return true on success")
	assert_false(gedis.exists("mykey"), "Key should not exist in the source DB")
	gedis.select(1)
	assert_true(gedis.exists("mykey"), "Key should exist in the destination DB")
	assert_eq(gedis.get("mykey"), "myvalue", "Key should have the correct value in the destination DB")

func test_move_non_existent_key():
	assert_false(gedis.move("nonexistent", 1), "MOVE should return false for a non-existent key")

func test_move_key_to_db_where_it_already_exists():
	gedis.set("mykey", "value1")
	gedis.select(1)
	gedis.set("mykey", "value2")
	gedis.select(0)
	assert_false(gedis.move("mykey", 1), "MOVE should return false if the key already exists in the destination")
	assert_eq(gedis.get("mykey"), "value1", "Source key should not be modified")
	gedis.select(1)
	assert_eq(gedis.get("mykey"), "value2", "Destination key should not be modified")