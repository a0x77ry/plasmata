extends Node2D

var agent_left
var agent_right
var left_traced_lasers = []
var right_traced_lasers = []
# var left_laser_1
# var left_laser_2
# var left_laser_3
# var right_laser_1
# var right_laser_2
# var right_laser_3
# var agent_left_pos: Vector2
# var agent_right_pos: Vector2
#
#
func _physics_process(_delta):
#   if is_instance_valid(agent_left) && agent_left.is_inside_tree():
#     agent_left_pos = agent_left.global_position
#   if is_instance_valid(agent_right) && agent_right.is_inside_tree():
#     agent_left_pos = agent_right.global_position
  assign_lasers_to_inputs()


func assign_lasers_to_inputs():
  var untraced_lasers = get_tree().get_nodes_in_group("untraced_lasers")
  for u_laser in untraced_lasers:
    u_laser.remove_from_group("untraced_lasers")
    assert(u_laser.side != null, "u_laser.side is null")

    if u_laser.side == Main.Side.LEFT:
      var is_already_in := false
      for lt_laser in left_traced_lasers:
        if is_instance_valid(lt_laser) && \
            lt_laser.get_instance_id() == u_laser.get_instance_id():
          is_already_in = true
          break
      if left_traced_lasers.empty() || !is_already_in:
        var slot_found := false
        for lt_laser in left_traced_lasers:
          if lt_laser == null:
            lt_laser = u_laser
            slot_found = true
            break
        if !slot_found:
          left_traced_lasers.append(u_laser)
    else:
      var is_already_in := false
      for rt_laser in right_traced_lasers:
        if is_instance_valid(rt_laser) && \
            rt_laser.get_instance_id() == u_laser.get_instance_id():
          is_already_in = true
          break
      if right_traced_lasers.empty() || !is_already_in:
        var slot_found := false
        for rt_laser in right_traced_lasers:
          if rt_laser == null:
            rt_laser = u_laser
            slot_found = true
            break
        if !slot_found:
          right_traced_lasers.append(u_laser)

  # for i in 2:
  #   if left_traced_lasers[i] == null:
  #     continue
  #   if left_laser_1 == null:
  #     left_laser_1 = left_traced_lasers[i]
  #   elif left_laser_2 == null:
  #     left_laser_2 = left_traced_lasers[i]
  #   elif left_laser_3 == null:
  #     left_laser_3 = left_traced_lasers[i]
  #
  # for i in 2:
  #   if right_traced_lasers[i] == null:
  #     continue
  #   if right_laser_1 == null:
  #     right_laser_1 = right_traced_lasers[i]
  #   elif right_laser_2 == null:
  #     right_laser_2 = right_traced_lasers[i]
  #   elif right_laser_3 == null:
  #     right_laser_3 = right_traced_lasers[i]
  #
