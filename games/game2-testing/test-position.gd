extends Position2D

onready var label = get_node("Label")
onready var fitness_timer = get_node("UpdateFitnessTimer")
onready var path = get_parent().get_node("Path2D")
onready var curve = path.curve

var current_fitness: float = 0.1
# var int_baked: Vector2 = Vector2(0, 0)


# func _draw():
#   draw_polyline(curve.get_baked_points(), Color.red, 5, true)


# func _process(_delta):
#   label.text = str(current_fitness)


func _input(event):
   if event is InputEventMouseButton:
    global_position = event.global_position

    var curve_local_pos = path.to_local(global_position)
    current_fitness = curve.get_closest_offset(curve_local_pos)

    var int_baked = curve.interpolate_baked(current_fitness)
    var dist_to_curve = int_baked.distance_to(curve_local_pos)

    var new_fitness = current_fitness - dist_to_curve

    # label.text = str(current_fitness)
    label.text = "OrigFit: %s, Dist: %s, NewFit: %s" % [current_fitness, dist_to_curve, new_fitness]


func _on_UpdateFitnessTimer_timeout():
  pass
  # var curve_local_pos = path.to_local(global_position)
  # current_fitness = curve.get_closest_offset(curve_local_pos)

