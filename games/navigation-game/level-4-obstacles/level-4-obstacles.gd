extends "res://scripts/nav-game.gd"

func _enter_tree():
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

    # "rf_col_normal_angle",
    # "rl_col_normal_angle",
    # "rr_col_normal_angle",
    # "rfu_col_normal_angle",
    # "rfd_col_normal_angle",

    "finish_distance",
    "finish_angle",

    "fitness",
    # "turn_right_input",
    # "move_forward_input"
  ]
  output_names = [
    "turn_right",
    "move_forward"
  ]

  level_name = "level_4_obstacles"


# func _on_SpawnTimer_timeout():
# 	generate_agent_population()

