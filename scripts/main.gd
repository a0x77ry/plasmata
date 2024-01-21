extends Node2D

const Population = preload("res://scripts/population.gd")

var level
var init_rot = rand_range(-PI, PI)


func _ready():
  Engine.time_scale = 3
  get_level()


func get_level():
  level = get_tree().get_nodes_in_group("level")[0]
