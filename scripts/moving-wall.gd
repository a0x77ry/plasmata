extends KinematicBody2D


func _on_Area2D_body_entered(body:Node):
  # pass
  if body.is_in_group("agents"):
    var game = get_parent().get_parent()
    game.decrement_agent_population()
    body.queue_free()
