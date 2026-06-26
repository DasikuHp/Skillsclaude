# Test unitario con GUT (GDScript). extends GutTest.
# Correr: godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
#           -gdir=res://test -ginclude_subdirs -gexit
extends GutTest

func test_take_damage_reduces_health() -> void:
	var p = autofree(load("res://scripts/player.gd").new())  # autofree evita falsos leaks
	p.health = 100
	p.take_damage(30)
	assert_eq(p.health, 70, "health debe bajar a 70")

func test_inventory_starts_empty() -> void:
	var inv = autofree(load("res://scripts/inventory.gd").new())
	assert_true(inv.is_empty(), "inventario nuevo debe estar vacio")
	assert_eq(inv.size(), 0)
