extends Node2D

# signal battle_won(winner_genome, time_remaining_normalized, is_won_with_hit)
signal battle_won(winner_genome, is_won_with_hit)
signal battle_draw(genome_left, genome_right)
signal cage_cleared(cage)
# signal agent_queued(agent)
# signal genome_queued(genome)

onready var left_pos = get_node("StartingPos/LeftStartingPos")
onready var right_pos = get_node("StartingPos/RightStartingPos")
onready var death_timer = get_node("DeathTimer")

var agent_left
var agent_right
var genome_left_copy
var genome_right_copy
var left_traced_lasers = []
var right_traced_lasers = []
var left_rot = 0.0
var right_rot = PI
var has_active_battle := false
var has_winner := false # guards against both being winners
var game
var all_active_lasers = []


func _physics_process(_delta):
  trace_cage_lasers(1)


func trace_cage_lasers(_traced_number):
  for laser in all_active_lasers:
    if !is_instance_valid(laser):
      all_active_lasers.erase(laser)
      continue
    if laser.side == Main.Side.LEFT:
        # || (is_instance_valid(left_traced_lasers[0])\
      if left_traced_lasers.empty()\
          || (is_instance_valid(left_traced_lasers[0])\
            && (left_traced_lasers.size() == 1\
            && left_traced_lasers[0].get_instance_id() != laser.get_instance_id())):
        left_traced_lasers.clear()
        left_traced_lasers.append(laser)
    elif laser.side == Main.Side.RIGHT:
      if right_traced_lasers.empty()\
          || (is_instance_valid(right_traced_lasers[0])\
            && (right_traced_lasers.size() == 1\
            && right_traced_lasers[0].get_instance_id() != laser.get_instance_id())):
        right_traced_lasers.clear()
        right_traced_lasers.append(laser)



# func trace_lasers(traced_number):
#   var untraced_lasers = get_tree().get_nodes_in_group("untraced_lasers")
#   for u_laser in untraced_lasers:
#     assert(u_laser.side != null, "u_laser.side is null")
#
#     if u_laser.side == Main.Side.LEFT:
#       var is_already_in := false
#       for lt_laser in left_traced_lasers:
#         if is_instance_valid(lt_laser) && \
#             lt_laser.get_instance_id() == u_laser.get_instance_id():
#           is_already_in = true
#           break
#       if left_traced_lasers.empty() || !is_already_in:
#         var slot_found := false
#         for lt_laser in left_traced_lasers:
#           if lt_laser == null:
#             lt_laser = u_laser
#             u_laser.remove_from_group("untraced_lasers")
#             slot_found = true
#             break
#         if !slot_found && left_traced_lasers.size() < traced_number:
#           left_traced_lasers.append(u_laser)
#           u_laser.remove_from_group("untraced_lasers")
#     else:
#       var is_already_in := false
#       for rt_laser in right_traced_lasers:
#         if is_instance_valid(rt_laser) && \
#             rt_laser.get_instance_id() == u_laser.get_instance_id():
#           is_already_in = true
#           break
#       if right_traced_lasers.empty() || !is_already_in:
#         var slot_found := false
#         for rt_laser in right_traced_lasers:
#           if rt_laser == null:
#             rt_laser = u_laser
#             u_laser.remove_from_group("untraced_lasers")
#             slot_found = true
#             break
#         if !slot_found && left_traced_lasers.size() < traced_number:
#           right_traced_lasers.append(u_laser)
#           u_laser.remove_from_group("untraced_lasers")


func add_agent(agent):
  assert(agent.side != null)
  if agent.side == Main.Side.LEFT:
    agent_left = agent
    # genome_left_copy = Genome.new(agent.genome.population)
    # genome_left_copy.copy(agent.genome)
    genome_left_copy = game.genome_duplicate(agent.genome)
    if agent_right != null:
      has_active_battle = true
  elif agent.side == Main.Side.RIGHT:
    agent_right = agent
    # genome_right_copy = Genome.new(agent.genome.population)
    # genome_right_copy.copy(agent.genome)
    genome_right_copy = game.genome_duplicate(agent.genome)
    if agent_left != null:
      has_active_battle = true


func clean_cage():
  # var all_lasers =  get_tree().get_nodes_in_group("lasers")
  for laser in all_active_lasers:
    if is_instance_valid(laser):
      laser.queue_free()
    else:
      all_active_lasers.erase(laser)

  if is_instance_valid(agent_left):
    agent_left.dissolve_agent()
    agent_left.queue_free()
  if is_instance_valid(genome_left_copy):
    genome_left_copy.dissolve_genome()
  if is_instance_valid(agent_right):
    agent_right.dissolve_agent()
    agent_right.queue_free()
  if is_instance_valid(genome_right_copy):
    genome_right_copy.dissolve_genome()

  agent_left = null
  agent_right = null
  death_timer.stop()
  has_active_battle = false
  has_winner = false
  emit_signal("cage_cleared", self)


func emit_serially(sig: String, winner_genome = null, is_hit = false) -> void:
  if sig == "battle_won":
    emit_signal("battle_won", winner_genome, is_hit)
  elif sig == "battle_draw":
    emit_signal(sig, game.genome_duplicate(genome_left_copy), game.genome_duplicate(genome_right_copy))
  yield(get_tree(), "idle_frame") # returns a GDScriptFunctionState object


func _on_agent_death(side, is_hit):
  var winner_genome
  assert(side != null)
  if (!is_instance_valid(agent_left) && !is_instance_valid(agent_right)):
  # if (is_instance_valid(agent_left) && is_instance_valid(agent_right)):
    print("It's a draw")
    # emit_signal("battle_draw", game.genome_duplicate(genome_left_copy), game.genome_duplicate(genome_right_copy))
    yield(emit_serially("battle_draw"), "completed")
    clean_cage()
    return

  if has_winner:
    return

  if side == Main.Side.LEFT:
    winner_genome = game.genome_duplicate(genome_right_copy)
  else:
    winner_genome = game.genome_duplicate(genome_left_copy)
  # print("We have a winner")
  # var time_remain_norm = death_timer.time_left / death_timer.wait_time
  # emit_signal("battle_won", winner_genome, is_hit)
  has_winner = true
  yield(emit_serially("battle_won", winner_genome, is_hit), "completed")
  clean_cage()


func _on_DeathTimer_timeout():
  var left_alive = is_instance_valid(agent_left)
  var right_alive = is_instance_valid(agent_right)
  if left_alive && right_alive:# && genome_left_copy != null && genome_right_copy != null:
    # emit_signal("battle_draw", game.genome_duplicate(genome_left_copy), game.genome_duplicate(genome_right_copy))
    yield(emit_serially("battle_draw"), "completed")
  clean_cage()

