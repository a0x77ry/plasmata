extends GraphEdit

func _ready():
  if !(connect_node("GraphNode", 0, "GraphNode2", 0) == OK):
    print("There has been an error with the connection") 
  if !(connect_node("GraphNode", 0, "GraphNode3", 0) == OK):
    print("There has been an error with the connection") 
  if !(connect_node("GraphNode4", 0, "GraphNode2", 0) == OK):
    print("There has been an error with the connection") 
