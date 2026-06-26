# Test unitario con gdUnit4 (GDScript), sintaxis fluida. extends GdUnitTestSuite.
# Correr: ./addons/gdUnit4/runtest.sh -a res://test --ignoreHeadlessMode --continue
extends GdUnitTestSuite

func test_take_damage() -> void:
	var p = auto_free(load("res://scripts/player.gd").new())
	p.health = 100
	p.take_damage(30)
	assert_int(p.health).is_equal(70)
	assert_int(p.health).is_between(0, 100)
