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
    # "go_right_input",
    # "go_forward_input"
  ]
  output_names = [
    "go_right",
    "go_forward"
  ]


# func _on_SpawnTimer_timeout():
# 	generate_agent_population()

