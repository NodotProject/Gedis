extends "res://addons/gut/test.gd"

const Gedis = preload("res://addons/Gedis/gedis.gd")

var gedis: Gedis

func before_each():
	gedis = Gedis.new()
	add_child(gedis)

func after_each():
	gedis.flushall()
	gedis.queue_free()

func test_zadd_new_members():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 5)
	
	var result = gedis.zrangebyscore("myzset", 0, 100)
	assert_eq(result, ["member3", "member1", "member2"], "Members should be sorted by score")

func test_zadd_existing_member_updates_score():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member1", 30)
	
	var result = gedis.zrangebyscore("myzset", 0, 100)
	assert_eq(result, ["member2", "member1"], "Existing member score should be updated and re-sorted")

func test_zrem_member():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zrem("myzset", "member1")
	
	var result = gedis.zrangebyscore("myzset", 0, 100)
	assert_eq(result, ["member2"], "Member should be removed from the sorted set")

func test_zrem_non_existent_member():
	gedis.zadd("myzset", "member1", 10)
	gedis.zrem("myzset", "non_existent")
	
	var result = gedis.zrangebyscore("myzset", 0, 100)
	assert_eq(result, ["member1"], "Set should be unchanged when removing a non-existent member")

func test_zrangebyscore():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	gedis.zadd("myzset", "member4", 40)
	
	var result = gedis.zrangebyscore("myzset", 15, 35)
	assert_eq(result, ["member2", "member3"], "Should return members within the score range")

func test_zrangebyscore_empty_result():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 40)
	
	var result = gedis.zrangebyscore("myzset", 20, 30)
	assert_true(result.is_empty(), "Should return an empty array for a range with no members")

func test_zpopready():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	
	var ready_members = gedis.zpopready("myzset", 25)
	assert_eq(ready_members, ["member1", "member2"], "Should pop members with scores less than or equal to the given value")
	
	var remaining_members = gedis.zrangebyscore("myzset", 0, 100)
	assert_eq(remaining_members, ["member3"], "Popped members should be removed from the set")

func test_zpopready_empty_set():
	var ready_members = gedis.zpopready("myzset", 100)
	assert_true(ready_members.is_empty(), "Should return an empty array when popping from an empty set")

func test_empty_zset_operations():
	assert_true(gedis.zrangebyscore("myzset", 0, 100).is_empty(), "Range query on empty set should be empty")
	assert_true(gedis.zpopready("myzset", 100).is_empty(), "Pop on empty set should be empty")
	gedis.zrem("myzset", "non_existent") # Should not crash
	assert_true(gedis.zrangebyscore("myzset", 0, 100).is_empty(), "Removing from empty set should result in an empty set")