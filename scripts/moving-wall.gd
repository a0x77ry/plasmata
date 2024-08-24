extends KinematicBody2D


func _on_Area2D_body_entered(body:Node):
  # pass
  var agent = body as Node2D
  if agent.is_in_group("agents"):
    agent.kill_agent()
  # if body.is_in_group("agents"):
  #   var game = get_parent().get_parent()
  #   game.decrement_agent_population()
  #   body.queue_free()
