extends KinematicBody2D


func _on_Area2D_body_entered(body:Node):
  var agent = body as Node2D
  if agent.is_in_group("agents"):
    agent.kill_agent()
    if agent.game.is_loading_mode_enabled:
      agent.game.generate_from_save()
