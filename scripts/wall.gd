extends StaticBody2D


func _on_Area2D_body_entered(body:Node):
  # pass
  if body.is_in_group("agents"):
    body.queue_free()
