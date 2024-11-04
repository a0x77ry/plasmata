extends Node2D

var agent_left
var agent_right
var left_traced_lasers = []
var right_traced_lasers = []
#
#
func _physics_process(_delta):
  trace_lasers(1)


func trace_lasers(traced_number):
  var untraced_lasers = get_tree().get_nodes_in_group("untraced_lasers")
  for u_laser in untraced_lasers:
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
            u_laser.remove_from_group("untraced_lasers")
            slot_found = true
            break
        if !slot_found && left_traced_lasers.size() < traced_number:
          left_traced_lasers.append(u_laser)
          u_laser.remove_from_group("untraced_lasers")
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
            u_laser.remove_from_group("untraced_lasers")
            slot_found = true
            break
        if !slot_found && left_traced_lasers.size() < traced_number:
          right_traced_lasers.append(u_laser)
          u_laser.remove_from_group("untraced_lasers")

