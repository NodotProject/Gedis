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
	
	var result = gedis.zrange("myzset", 0, 100)
	assert_eq(result, ["member3", "member1", "member2"], "Members should be sorted by score")

func test_zadd_existing_member_updates_score():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member1", 30)
	
	var result = gedis.zrange("myzset", 0, 100)
	assert_eq(result, ["member2", "member1"], "Existing member score should be updated and re-sorted")

func test_zrem_member():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zrem("myzset", "member1")
	
	var result = gedis.zrange("myzset", 0, 100)
	assert_eq(result, ["member2"], "Member should be removed from the sorted set")

func test_zrem_non_existent_member():
	gedis.zadd("myzset", "member1", 10)
	gedis.zrem("myzset", "non_existent")
	
	var result = gedis.zrange("myzset", 0, 100)
	assert_eq(result, ["member1"], "Set should be unchanged when removing a non-existent member")

func test_zrange():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	gedis.zadd("myzset", "member4", 40)
	
	var result = gedis.zrange("myzset", 15, 35)
	assert_eq(result, ["member2", "member3"], "Should return members within the score range")

func test_zrange_empty_result():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 40)
	
	var result = gedis.zrange("myzset", 20, 30)
	assert_true(result.is_empty(), "Should return an empty array for a range with no members")

func test_zpopready():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	
	var ready_members = gedis.zpopready("myzset", 25)
	assert_eq(ready_members, ["member1", "member2"], "Should pop members with scores less than or equal to the given value")
	
	var remaining_members = gedis.zrange("myzset", 0, 100)
	assert_eq(remaining_members, ["member3"], "Popped members should be removed from the set")

func test_zpopready_empty_set():
	var ready_members = gedis.zpopready("myzset", 100)
	assert_true(ready_members.is_empty(), "Should return an empty array when popping from an empty set")

func test_empty_zset_operations():
	assert_true(gedis.zrange("myzset", 0, 100).is_empty(), "Range query on empty set should be empty")
	assert_true(gedis.zpopready("myzset", 100).is_empty(), "Pop on empty set should be empty")
	gedis.zrem("myzset", "non_existent") # Should not crash
	assert_true(gedis.zrange("myzset", 0, 100).is_empty(), "Removing from empty set should result in an empty set")

func test_multiple_sorted_sets_are_isolated():
	gedis.zadd("zset1", "a", 1)
	gedis.zadd("zset1", "b", 2)
	
	gedis.zadd("zset2", "x", 10)
	gedis.zadd("zset2", "y", 20)
	
	var zset1_members = gedis.zrange("zset1", 0, 100)
	assert_eq(zset1_members, ["a", "b"], "zset1 should have its own members")
	
	var zset2_members = gedis.zrange("zset2", 0, 100)
	assert_eq(zset2_members, ["x", "y"], "zset2 should have its own members")
	
	gedis.zrem("zset1", "a")
	zset1_members = gedis.zrange("zset1", 0, 100)
	assert_eq(zset1_members, ["b"], "Removing from zset1 should not affect zset2")
	
	zset2_members = gedis.zrange("zset2", 0, 100)
	assert_eq(zset2_members, ["x", "y"], "zset2 should remain unchanged")


func test_zrevrange_basic():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	gedis.zadd("myzset", "member4", 40)
	
	var result = gedis.zrevrange("myzset", 0, 100)
	assert_eq(result, ["member4", "member3", "member2", "member1"], "Should return members in reverse sorted order")

func test_zrevrange_with_scores():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	
	var result = gedis.zrevrange("myzset", 0, 100, true)
	assert_eq(result, [["member3", 30], ["member2", 20], ["member1", 10]], "Should return members and scores in reverse sorted order")

func test_zrevrange_subset():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	gedis.zadd("myzset", "member4", 40)
	
	var result = gedis.zrevrange("myzset", 15, 35)
	assert_eq(result, ["member3", "member2"], "Should return a subset of members in reverse sorted order")

func test_zrevrange_empty_set():
	var result = gedis.zrevrange("myzset", 0, 100)
	assert_true(result.is_empty(), "Should return an empty array for an empty set")

func test_zrevrange_out_of_bounds():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	
	var result = gedis.zrevrange("myzset", 100, 200)
	assert_true(result.is_empty(), "Should return an empty array for out-of-bounds indices")

func test_zrevrange_with_inf():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	gedis.zadd("myzset", "member4", 40)
	
	var result = gedis.zrevrange("myzset", 0, INF)
	assert_eq(result, ["member4", "member3", "member2", "member1"], "Should return all members in reverse sorted order when using INF")

func test_zrevrange_with_inf_and_scores():
	gedis.zadd("myzset", "member1", 10)
	gedis.zadd("myzset", "member2", 20)
	gedis.zadd("myzset", "member3", 30)
	
	var result = gedis.zrevrange("myzset", 0, INF, true)
	assert_eq(result, [["member3", 30], ["member2", 20], ["member1", 10]], "Should return all members and scores in reverse sorted order when using INF")
