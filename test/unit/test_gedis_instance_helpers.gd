extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushdb()

func after_all():
	gedis.free()

func before_each():
	gedis.flushdb()

func test_set_and_get_instance_name():
	gedis.set_instance_name("my_test_instance")
	assert_eq(gedis.get_instance_name(), "my_test_instance", "get_instance_name should return the name set by set_instance_name")

func test_get_all_instances():
	var instance1 = Gedis.new()
	instance1.set_instance_name("instance1")
	var instance2 = Gedis.new()
	instance2.set_instance_name("instance2")

	var instances = Gedis.get_all_instances()
	assert_eq(instances.size(), 3, "get_all_instances should return all created instances")

	var found1 = false
	var found2 = false
	var found_test = false
	for instance_info in instances:
		if instance_info["name"] == "instance1":
			found1 = true
		if instance_info["name"] == "instance2":
			found2 = true
		if instance_info["object"] == gedis:
			found_test = true
	
	assert_true(found1, "Instance 1 should be in the list of all instances")
	assert_true(found2, "Instance 2 should be in the list of all instances")
	assert_true(found_test, "The test's own gedis instance should be in the list")

	instance1.free()
	instance2.free()

	instances = Gedis.get_all_instances()
	assert_eq(instances.size(), 1, "get_all_instances should not return freed instances")