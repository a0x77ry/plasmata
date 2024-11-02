extends KinematicBody2D

signal agent_hit(agent_id)

export(float) var speed = 300.0

var velocity: Vector2 = Vector2.ZERO
var col: KinematicCollision2D
var side

func _ready():
  velocity = Vector2(speed, 0).rotated(get_rotation())
  var agents = get_tree().get_nodes_in_group("agents")
  for agent in agents:
    connect("agent_hit", agent, "_on_agent_hit")


func _physics_process(delta):
  col = move_and_collide(velocity * delta)
  if col:
    var hit_obj = col.get_collider()
    if hit_obj.is_in_group("agents"):
      emit_signal("agent_hit", hit_obj.get_instance_id())
    queue_free()
