extends Node2D

const TIME_TO_FITNESS_MULTIPLICATOR = 70

const Population = preload("res://scripts/population.gd")

var random = RandomNumberGenerator.new()
var level
var init_rot = rand_range(-PI, PI)


func _ready():
  random.randomize()
  get_level()


func get_level():
  level = get_tree().get_nodes_in_group("level")[0]
