# extends "res://scripts/nav-game.gd"
extends Node2D

onready var path = get_node("Path2D")
onready var curve_new = path.curve


# func _enter_tree():
#   input_names = [
#     "rotation",
#     # "inverse_rotation",
#     # "time_since_birth",
#     # "pos_x",
#     # "pos_y",
#     "ray_f_distance",
#     "ray_f_up_right_distance",
#     "ray_f_down_right_distance",
#     "ray_left_distance",
#     "ray_right_distance",
#     "fitness",
#     # "go_right_input",
#     # "go_forward_input"
#   ]
#   output_names = [
#     "go_right",
#     "go_forward"
#   ]

func _draw():
  draw_polyline(curve_new.get_baked_points(), Color.red, 5, true)
