extends KinematicBody2D

signal agent_hit

export(float) var speed = 600.0

var velocity: Vector2 = Vector2.ZERO
var col: KinematicCollision2D
var side
var agent
var opponent_agent

func _ready():
  velocity = Vector2(speed, 0).rotated(get_rotation())
  var err = connect("agent_hit", opponent_agent, "_on_agent_hit")
  if err != OK:
    print("Laser could not connect agent_hit signal")


func _physics_process(delta):
  col = move_and_collide(velocity * delta)
  if col:
    var hit_obj = col.get_collider()
    if hit_obj == opponent_agent:
      emit_signal("agent_hit")
    queue_free()
