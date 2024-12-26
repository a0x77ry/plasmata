extends "res://games/combat-game/combat-game.gd"

# export(PackedScene) var BattleCage

# onready var battle_cages_node = get_node("BattleCages")


func _enter_tree():
  randomize()
  input_names = [
    "rotation",

    # "pos_x",
    # "pos_y",
    "ray_f_distance",
    "ray_f_up_right_distance",
    "ray_f_down_right_distance",
    "ray_left_distance",
    "ray_right_distance",

    "rf_col_normal_angle",
    "rl_col_normal_angle",
    "rr_col_normal_angle",
    "rfu_col_normal_angle",
    "rfd_col_normal_angle",

    "turn_right_input",
    "move_forward_input",
    "move_right_input",
    "shooting_input",

    "opponent_angle",
    "opponent_distance",
    "traced_laser_1_angle",
    "traced_laser_1_distance",
  ]

  output_names = [
    "turn_right",
    # "rotation_target",
    "move_forward",
    "move_right",
    "shooting"
  ]

  level_name = "simple_combat_level"


# func _ready():
#   var battle_cage = BattleCage.instance()
#   battle_cages_node.call_deferred("add_child", battle_cage)
