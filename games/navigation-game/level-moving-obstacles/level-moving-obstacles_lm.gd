extends "res://scripts/nav-game.gd"


func _enter_tree():
  randomize()
  input_names = [
    "rotation",

    # "inverse_rotation",
    # "time_since_birth",

    # "pos_x",
    # "pos_y",

    "ray_f_distance",
    "ray_f_up_right_distance",
    "ray_f_down_right_distance",
    "ray_left_distance",
    "ray_right_distance",

    "ray_f_distance_mw",
    "ray_f_up_right_distance_mw",
    "ray_f_down_right_distance_mw",
    "ray_left_distance_mw",
    "ray_right_distance_mw",

    # "ray_f_distance_complement",
    # "ray_f_up_right_distance_complement",
    # "ray_f_down_right_distance_complement",
    # "ray_left_distance_complement",
    # "ray_right_distance_complement",
    #
    # "ray_f_distance_mw_complement",
    # "ray_f_up_right_distance_mw_complement",
    # "ray_f_down_right_distance_mw_complement",
    # "ray_left_distance_mw_complement",
    # "ray_right_distance_mw_complement",


    "rf_col_normal_angle",
    "rl_col_normal_angle",
    "rr_col_normal_angle",
    "rfu_col_normal_angle",
    "rfd_col_normal_angle",

    "finish_distance",
    "finish_angle",

    "fitness",
    "turn_right_input",
    "move_forward_input",
    "mwall_1_descent_completion",
    "mwall_1_ascent_completion",
    "mwall_2_descent_completion",
    "mwall_2_ascent_completion",

    "wall_animation_moving",
  ]
  output_names = [
    "turn_right",
    "move_forward"
  ]

  is_loading_mode_enabled = true
  level_name = "level_moving_obstacles"

