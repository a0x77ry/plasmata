extends Node2D

const Population = preload("res://scripts/population.gd")

var random = RandomNumberGenerator.new()
var level
var init_rot = rand_range(-PI, PI)


func _ready():
  random.randomize()
  get_level()


func get_level():
  level = get_tree().get_nodes_in_group("level")[0]
