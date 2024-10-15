extends Node2D

# const TIME_SCALE = 4
const Population = preload("res://scripts/population.gd")
const AGENT_LIMIT = 100

var level
var init_rot = rand_range(-PI, PI)
var is_paused = false
var filename_to_load
var pause_on_completion: bool = false
var number_of_completions_to_pause: int = 1
var time_scale := 3


func _ready():
  Engine.time_scale = time_scale
  # get_level()


# func _process(_delta):
#   if Input.is_action_just_pressed("ui_accept"):
#     pause()


# func get_level():
#   level = get_tree().get_nodes_in_group("level")[0]


# func pause():
#   if is_paused:
#     Engine.time_scale = TIME_SCALE
#     is_paused = false
#     level.pause(false)
#   else:
#     Engine.time_scale = 0
#     is_paused = true
#     level.pause(true)


# func change_time_scale(ts):
#   Engine.time_scale = ts
